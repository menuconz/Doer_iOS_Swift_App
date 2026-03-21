import SwiftUI
import PhotosUI

struct SubItemMessagesScreen: View {
    var onBack: () -> Void
    var onViewAttachment: (String) -> Void

    @State private var viewModel: SubItemMessagesViewModel
    @State private var selectedPhotoItem: PhotosPickerItem? = nil

    init(shiftId: Int, subItemId: Int, onBack: @escaping () -> Void, onViewAttachment: @escaping (String) -> Void) {
        self.onBack = onBack
        self.onViewAttachment = onViewAttachment
        _viewModel = State(initialValue: SubItemMessagesViewModel(shiftId: shiftId, subItemId: subItemId))
    }

    private let BluePrimary = Color(hex: "#007AFF")
    private let BgColor = Color(hex: "#FAFAFA")
    private let SecondaryText = Color(hex: "#8E8E93")
    private let BorderColor = Color(hex: "#E8E8E8")

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading {
                Spacer()
                ProgressView().tint(BluePrimary)
                Spacer()
            } else {
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
                            // Reuse the same ThreadCard-like structure
                            SubItemThreadCardView(
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

                // Bottom composer - same structure as MessagesScreen
                SubItemBottomComposerView(
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
                    onPickImage: { item in
                        if let item = item {
                            Task {
                                if let data = try? await item.loadTransferable(type: Data.self) {
                                    let fileName = "image_\(UUID().uuidString).jpg"
                                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                                    try? data.write(to: tempURL)
                                    viewModel.addSelectedFile(tempURL, fileName: fileName, filePath: tempURL.path)
                                }
                            }
                        }
                    }
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

// MARK: - SubItem Thread Card (mirrors MessagesScreen ThreadCard)
private struct SubItemThreadCardView: View {
    let thread: EmailThreadDto
    @Binding var replyText: String
    let isSending: Bool
    let replyMentionSuggestions: [MentionSuggestion]
    let showReplyMentionSuggestions: Bool
    let onReplyMentionSelected: (MentionSuggestion) -> Void
    let onSendReply: () -> Void
    let onViewAttachment: (String) -> Void
    let formatTimestamp: (String) -> String

    private let BlueAvatar = Color(hex: "#007AFF")
    private let GreenAvatar = Color(hex: "#34C759")
    private let PrimaryText = Color(hex: "#1C1C1E")
    private let SecondaryText = Color(hex: "#8E8E93")
    private let BorderColor = Color(hex: "#E8E8E8")
    private let BluePrimary = Color(hex: "#007AFF")

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Root email
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Circle().fill(BlueAvatar).frame(width: 40, height: 40)
                        .overlay(Text(String((thread.rootEmail?.fromEmail ?? "").prefix(1)).uppercased()).foregroundColor(.white).font(.system(size: 16, weight: .bold)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(thread.rootEmail?.fromEmail ?? "").font(.system(size: 16, weight: .bold)).foregroundColor(PrimaryText).lineLimit(1)
                        Text(formatTimestamp(thread.rootEmail?.sentAt ?? "")).font(.system(size: 12)).foregroundColor(SecondaryText)
                    }
                }
                if !(thread.rootEmail?.subject ?? "").isEmpty {
                    Text(thread.rootEmail?.subject ?? "").font(.system(size: 15, weight: .bold)).foregroundColor(PrimaryText)
                }
                if !(thread.rootEmail?.body ?? "").isEmpty {
                    Text(thread.rootEmail?.body ?? "").font(.system(size: 15)).foregroundColor(PrimaryText).lineSpacing(4)
                }
            }

            if !thread.replies.isEmpty {
                Divider().background(BorderColor)
                ForEach(thread.replies, id: \.id) { reply in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Circle().fill(GreenAvatar).frame(width: 36, height: 36)
                                .overlay(Text(String(reply.fromEmail.prefix(1)).uppercased()).foregroundColor(.white).font(.system(size: 14, weight: .bold)))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(reply.fromEmail).font(.system(size: 15, weight: .bold)).foregroundColor(PrimaryText).lineLimit(1)
                                Text(formatTimestamp(reply.sentAt)).font(.system(size: 12)).foregroundColor(SecondaryText)
                            }
                        }
                        Text(reply.plainTextBody ?? reply.body).font(.system(size: 15)).foregroundColor(PrimaryText).lineSpacing(4).padding(.leading, 48)
                    }
                    .padding(.bottom, 16)
                }
            }

            // Reply box
            VStack(spacing: 8) {
                if showReplyMentionSuggestions && !replyMentionSuggestions.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(replyMentionSuggestions) { s in
                            Button(action: { onReplyMentionSelected(s) }) {
                                HStack(spacing: 8) {
                                    Circle().fill(Color(hex: "#E0E0E0")).frame(width: 32, height: 32).overlay(Text("\u{1F464}").font(.system(size: 12)))
                                    Text(s.displayName).font(.system(size: 14, weight: .bold)).foregroundColor(.black)
                                    Spacer()
                                }.padding(.horizontal, 12).padding(.vertical, 8)
                            }
                        }
                    }
                    .background(Color.white)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#E0E0E0"), lineWidth: 1))
                    .cornerRadius(8)
                }

                TextEditor(text: $replyText)
                    .frame(height: 100)
                    .font(.system(size: 14))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(BorderColor, lineWidth: 1))
                    .cornerRadius(8)
                    .overlay(alignment: .topLeading) {
                        if replyText.isEmpty {
                            Text("Write a reply and mention with @...")
                                .font(.system(size: 14)).foregroundColor(.gray)
                                .padding(.horizontal, 8).padding(.vertical, 12)
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
        .padding(16)
        .background(Color.white)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(BorderColor, lineWidth: 1))
        .cornerRadius(12)
    }
}

// MARK: - SubItem Bottom Composer
private struct SubItemBottomComposerView: View {
    @Binding var newMessageText: String
    let isSending: Bool
    let mentionSuggestions: [MentionSuggestion]
    let showMentionSuggestions: Bool
    let selectedFiles: [SelectedFileItem]
    let onMentionSelected: (MentionSuggestion) -> Void
    let onSend: () -> Void
    let onRemoveFile: (String) -> Void
    let onPickImage: (PhotosPickerItem?) -> Void

    @State private var selectedPhotoItem: PhotosPickerItem? = nil

    private let BluePrimary = Color(hex: "#007AFF")
    private let BorderColor = Color(hex: "#E8E8E8")

    var body: some View {
        VStack(spacing: 8) {
            if showMentionSuggestions && !mentionSuggestions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(mentionSuggestions) { s in
                        Button(action: { onMentionSelected(s) }) {
                            HStack(spacing: 8) {
                                Circle().fill(Color(hex: "#E0E0E0")).frame(width: 32, height: 32).overlay(Text("\u{1F464}").font(.system(size: 12)))
                                Text(s.displayName).font(.system(size: 14, weight: .bold)).foregroundColor(.black)
                                Spacer()
                            }.padding(.horizontal, 12).padding(.vertical, 8)
                        }
                    }
                }
                .background(Color.white)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#E0E0E0"), lineWidth: 1))
                .cornerRadius(8)
            }

            TextEditor(text: $newMessageText)
                .frame(height: 120)
                .font(.system(size: 14))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(BorderColor, lineWidth: 1))
                .cornerRadius(8)
                .overlay(alignment: .topLeading) {
                    if newMessageText.isEmpty {
                        Text("Write an Update and mention with @")
                            .font(.system(size: 14)).foregroundColor(.gray)
                            .padding(.horizontal, 8).padding(.vertical, 12)
                            .allowsHitTesting(false)
                    }
                }

            // Selected files preview (matching Android)
            if !selectedFiles.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(selectedFiles) { file in
                            ZStack(alignment: .topTrailing) {
                                AsyncImage(url: file.url) { image in
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Color.gray.opacity(0.2)
                                }
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                                Button(action: { onRemoveFile(file.filePath) }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 10))
                                        .foregroundColor(.white)
                                        .frame(width: 20, height: 20)
                                        .background(Color.red)
                                        .clipShape(Circle())
                                }
                                .offset(x: 4, y: -4)
                            }
                            .frame(width: 68, height: 68)
                        }
                    }
                }
            }

            HStack {
                PhotosPicker(selection: Binding(
                    get: { selectedPhotoItem },
                    set: { item in
                        selectedPhotoItem = item
                        onPickImage(item)
                        selectedPhotoItem = nil
                    }
                ), matching: .images) {
                    Text("Image").font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .frame(height: 36)

                Spacer()

                Button(action: onSend) {
                    if isSending { ProgressView().tint(.white) }
                    else { Text("Update").font(.system(size: 12)).foregroundColor(.white) }
                }
                .frame(height: 36)
                .padding(.horizontal, 16)
                .background((newMessageText.trimmingCharacters(in: .whitespaces).isEmpty && selectedFiles.isEmpty) || isSending ? BluePrimary.opacity(0.5) : BluePrimary)
                .cornerRadius(6)
                .disabled((newMessageText.trimmingCharacters(in: .whitespaces).isEmpty && selectedFiles.isEmpty) || isSending)
            }
        }
        .padding(12)
        .background(Color.white)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#D0D0D0"), lineWidth: 1))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
