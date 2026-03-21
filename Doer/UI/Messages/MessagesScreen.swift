import SwiftUI
import PhotosUI

private let BlueAvatar = Color(hex: "#007AFF")
private let GreenAvatar = Color(hex: "#34C759")
private let BgColor = Color(hex: "#FAFAFA")
private let PrimaryText = Color(hex: "#1C1C1E")
private let SecondaryText = Color(hex: "#8E8E93")
private let BorderColor = Color(hex: "#E8E8E8")
private let BluePrimary = Color(hex: "#007AFF")

struct MessagesScreen: View {
    var onBack: () -> Void
    var onViewAttachment: (String) -> Void

    @State private var viewModel: MessagesViewModel
    @State private var showImagePicker = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var selectedImageData: Data? = nil

    init(shiftId: Int, onBack: @escaping () -> Void, onViewAttachment: @escaping (String) -> Void) {
        self.onBack = onBack
        self.onViewAttachment = onViewAttachment
        _viewModel = State(initialValue: MessagesViewModel(shiftId: shiftId))
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading {
                Spacer()
                ProgressView().tint(BluePrimary)
                Spacer()
            } else {
                // Threads list
                if viewModel.threads.isEmpty {
                    ScrollView {
                        VStack(spacing: 16) {
                            Spacer().frame(height: 80)
                            Image(systemName: "envelope")
                                .font(.system(size: 64))
                                .foregroundColor(.gray.opacity(0.5))
                            Text("No messages yet")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(SecondaryText)
                            Text("Pull down to refresh")
                                .font(.system(size: 14))
                                .foregroundColor(.gray.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .refreshable { viewModel.refresh() }
                } else {
                    List {
                        ForEach(viewModel.threads, id: \.rootEmail?.id) { thread in
                            let rootEmailId = thread.rootEmail?.id ?? 0
                            let mentionState = viewModel.replyMentionStates[rootEmailId]
                            ThreadCard(
                                thread: thread,
                                replyText: Binding(
                                    get: { viewModel.replyTexts[rootEmailId] ?? "" },
                                    set: { viewModel.onReplyTextChanged(rootEmailId, $0) }
                                ),
                                isSending: viewModel.isSending,
                                replyMentionSuggestions: mentionState?.suggestions ?? [],
                                showReplyMentionSuggestions: mentionState?.showSuggestions ?? false,
                                onReplyMentionSelected: { viewModel.onReplyMentionSelected(rootEmailId, $0) },
                                onSendReply: { viewModel.sendReply(rootEmailId) },
                                onViewAttachment: onViewAttachment,
                                formatTimestamp: viewModel.formatTimestamp
                            )
                            .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                            .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                    .refreshable { viewModel.refresh() }
                }

                // Bottom composer
                BottomComposer(
                    newMessageText: Binding(
                        get: { viewModel.newMessageText },
                        set: { viewModel.onNewMessageTextChanged($0) }
                    ),
                    isSending: viewModel.isSending,
                    mentionSuggestions: viewModel.mentionSuggestions,
                    showMentionSuggestions: viewModel.showMentionSuggestions,
                    selectedFiles: viewModel.selectedFiles,
                    onMentionSelected: viewModel.onMentionSelected,
                    onSend: viewModel.sendNewMessage,
                    onRemoveFile: viewModel.removeSelectedFile,
                    onAddFile: viewModel.addSelectedFile
                )
            }
        }
        .background(BgColor)
        .navigationTitle("Updates")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .onAppear { viewModel.loadInitialData() }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: onBack) { Image(systemName: "chevron.left") }
            }
        }
        .snackbar(message: Binding(
            get: { viewModel.errorMessage ?? viewModel.successMessage },
            set: { _ in viewModel.clearError(); viewModel.clearSuccess() }
        ))
    }
}

// MARK: - Thread Card
private struct ThreadCard: View {
    let thread: EmailThreadDto
    @Binding var replyText: String
    let isSending: Bool
    let replyMentionSuggestions: [MentionSuggestion]
    let showReplyMentionSuggestions: Bool
    let onReplyMentionSelected: (MentionSuggestion) -> Void
    let onSendReply: () -> Void
    let onViewAttachment: (String) -> Void
    let formatTimestamp: (String) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let rootEmail = thread.rootEmail {
                RootEmailSection(
                    email: rootEmail,
                    formatTimestamp: formatTimestamp,
                    onViewAttachment: onViewAttachment
                )
            }

            if !thread.replies.isEmpty {
                Divider().background(BorderColor)
                ForEach(thread.replies, id: \.id) { reply in
                    ReplySection(email: reply, formatTimestamp: formatTimestamp)
                }
            }

            ReplyBox(
                replyText: $replyText,
                isSending: isSending,
                mentionSuggestions: replyMentionSuggestions,
                showMentionSuggestions: showReplyMentionSuggestions,
                onMentionSelected: onReplyMentionSelected,
                onSendReply: onSendReply
            )
        }
        .padding(16)
        .background(Color.white)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(BorderColor, lineWidth: 1))
        .cornerRadius(12)
    }
}

// MARK: - Root Email Section
private struct RootEmailSection: View {
    let email: EmailMessageDto
    let formatTimestamp: (String) -> String
    let onViewAttachment: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Circle()
                    .fill(BlueAvatar)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(email.fromEmail.prefix(1)).uppercased())
                            .foregroundColor(.white)
                            .font(.system(size: 16, weight: .bold))
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(email.fromEmail)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(PrimaryText)
                        .lineLimit(1)
                    Text(formatTimestamp(email.sentAt))
                        .font(.system(size: 12))
                        .foregroundColor(SecondaryText)
                }
            }

            if !email.subject.isEmpty {
                Text(email.subject)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(PrimaryText)
            }

            if !email.body.isEmpty {
                Text(stripHtml(email.body))
                    .font(.system(size: 15))
                    .foregroundColor(PrimaryText)
                    .lineSpacing(4)
            }

            if !email.attachments.isEmpty {
                let attachments = email.attachments
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(attachments, id: \.fileUrl) { attachment in
                            AsyncImage(url: URL(string: attachment.fileUrl)) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Color.gray.opacity(0.2)
                            }
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .onTapGesture { onViewAttachment(attachment.fileUrl) }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Reply Section
private struct ReplySection: View {
    let email: EmailMessageDto
    let formatTimestamp: (String) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Circle()
                    .fill(GreenAvatar)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(String(email.fromEmail.prefix(1)).uppercased())
                            .foregroundColor(.white)
                            .font(.system(size: 14, weight: .bold))
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(email.fromEmail)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(PrimaryText)
                        .lineLimit(1)
                    Text(formatTimestamp(email.sentAt))
                        .font(.system(size: 12))
                        .foregroundColor(SecondaryText)
                }
            }
            Text(email.plainTextBody ?? email.body)
                .font(.system(size: 15))
                .foregroundColor(PrimaryText)
                .lineSpacing(4)
                .padding(.leading, 48)
        }
        .padding(.bottom, 16)
    }
}

// MARK: - Reply Box
private struct ReplyBox: View {
    @Binding var replyText: String
    let isSending: Bool
    let mentionSuggestions: [MentionSuggestion]
    let showMentionSuggestions: Bool
    let onMentionSelected: (MentionSuggestion) -> Void
    let onSendReply: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            if showMentionSuggestions && !mentionSuggestions.isEmpty {
                MentionSuggestionsList(suggestions: mentionSuggestions, onSelect: onMentionSelected)
            }

            TextEditor(text: $replyText)
                .frame(height: 100)
                .font(.system(size: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(BorderColor, lineWidth: 1)
                )
                .cornerRadius(8)
                .overlay(alignment: .topLeading) {
                    if replyText.isEmpty {
                        Text("Write a reply and mention with @...")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 12)
                            .allowsHitTesting(false)
                    }
                }

            Button(action: onSendReply) {
                if isSending {
                    ProgressView().tint(.white)
                } else {
                    Text("Reply").font(.system(size: 14)).foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(replyText.trimmingCharacters(in: .whitespaces).isEmpty || isSending ? BluePrimary.opacity(0.5) : BluePrimary)
            .cornerRadius(6)
            .disabled(replyText.trimmingCharacters(in: .whitespaces).isEmpty || isSending)
        }
    }
}

// MARK: - Bottom Composer
private struct BottomComposer: View {
    @Binding var newMessageText: String
    let isSending: Bool
    let mentionSuggestions: [MentionSuggestion]
    let showMentionSuggestions: Bool
    let selectedFiles: [SelectedFileItem]
    let onMentionSelected: (MentionSuggestion) -> Void
    let onSend: () -> Void
    let onRemoveFile: (String) -> Void
    let onAddFile: (URL, String, String) -> Void
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var previewImage: UIImage? = nil

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                if showMentionSuggestions && !mentionSuggestions.isEmpty {
                    MentionSuggestionsList(suggestions: mentionSuggestions, onSelect: onMentionSelected)
                }

                TextEditor(text: $newMessageText)
                    .frame(height: 120)
                    .font(.system(size: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(BorderColor, lineWidth: 1)
                    )
                    .cornerRadius(8)
                    .overlay(alignment: .topLeading) {
                        if newMessageText.isEmpty {
                            Text("Write an Update and mention with @")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 12)
                                .allowsHitTesting(false)
                        }
                    }

                if !selectedFiles.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(selectedFiles) { file in
                                ZStack(alignment: .topTrailing) {
                                    if let uiImage = UIImage(contentsOfFile: file.url.path) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 60, height: 60)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                            .onTapGesture { previewImage = uiImage }
                                    } else {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(width: 60, height: 60)
                                            .overlay(
                                                Image(systemName: "doc")
                                                    .foregroundColor(.gray)
                                            )
                                    }

                                    Button(action: { onRemoveFile(file.filePath) }) {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 10))
                                            .foregroundColor(.white)
                                            .frame(width: 20, height: 20)
                                            .background(Color.red)
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(.plain)
                                    .offset(x: 4, y: -4)
                                }
                                .frame(width: 68, height: 68)
                            }
                        }
                    }
                }

                HStack {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        HStack(spacing: 4) {
                            Image(systemName: "photo")
                                .font(.system(size: 12))
                            Text("Image").font(.system(size: 12))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(hex: "007AFF"))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .frame(height: 36)
                    .onChange(of: selectedPhotoItem) { _, item in
                        guard let item = item else { return }
                        Task {
                            if let data = try? await item.loadTransferable(type: Data.self) {
                                let fileName = "image_\(UUID().uuidString).jpg"
                                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                                try? data.write(to: tempURL)
                                onAddFile(tempURL, fileName, tempURL.path)
                            }
                            selectedPhotoItem = nil
                        }
                    }

                    Spacer()

                    Button(action: onSend) {
                        if isSending {
                            ProgressView().tint(.white)
                        } else {
                            Text("Update").font(.system(size: 12)).foregroundColor(.white)
                        }
                    }
                    .frame(height: 36)
                    .padding(.horizontal, 16)
                    .background(
                        (newMessageText.trimmingCharacters(in: .whitespaces).isEmpty && selectedFiles.isEmpty) || isSending
                            ? BluePrimary.opacity(0.5) : BluePrimary
                    )
                    .cornerRadius(6)
                    .disabled((newMessageText.trimmingCharacters(in: .whitespaces).isEmpty && selectedFiles.isEmpty) || isSending)
                }
            }
            .padding(12)
        }
        .background(Color.white)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#D0D0D0"), lineWidth: 1))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .fullScreenCover(isPresented: Binding(
            get: { previewImage != nil },
            set: { if !$0 { previewImage = nil } }
        )) {
            if let image = previewImage {
                ZStack {
                    Color.black.ignoresSafeArea()
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .ignoresSafeArea()
                }
                .overlay(alignment: .topTrailing) {
                    Button(action: { previewImage = nil }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                    }
                    .padding(20)
                }
            }
        }
    }
}

// MARK: - Mention Suggestions List
private struct MentionSuggestionsList: View {
    let suggestions: [MentionSuggestion]
    let onSelect: (MentionSuggestion) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(suggestions) { suggestion in
                Button(action: { onSelect(suggestion) }) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color(hex: "#E0E0E0"))
                            .frame(width: 32, height: 32)
                            .overlay(Text("\u{1F464}").font(.system(size: 12)))
                        Text(suggestion.displayName)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.black)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }
        }
        .background(Color.white)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#E0E0E0"), lineWidth: 1))
        .cornerRadius(8)
    }
}

// MARK: - Helper
private func stripHtml(_ html: String) -> String {
    guard let data = html.data(using: .utf8) else { return html }
    if let attr = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue], documentAttributes: nil) {
        return attr.string.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    return html
}
