import SwiftUI
import UniformTypeIdentifiers
import PhotosUI

private let BluePrimary = Color(hex: "#3B82F6")
private let DarkText = Color(hex: "#1F2937")
private let SubText = Color(hex: "#374151")
private let Gray500 = Color(hex: "#6B7280")
private let Gray400 = Color(hex: "#9CA3AF")
private let BorderColor = Color(hex: "#E5E7EB")
private let BgColor = Color(hex: "#F8F9FA")
private let SHIFT_DOCS_SERVER_URL = "https://doerapi.doer.nz/userDocuments/"

struct ShiftFilesScreen: View {
    var onBack: () -> Void
    var onViewDocument: (String, Bool) -> Void

    @State private var viewModel: ShiftFilesViewModel
    @State private var showingFilePicker = false
    @State private var showingImagePicker = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil

    init(shiftId: String, onBack: @escaping () -> Void, onViewDocument: @escaping (String, Bool) -> Void) {
        self.onBack = onBack
        self.onViewDocument = onViewDocument
        _viewModel = State(initialValue: ShiftFilesViewModel(shiftId: shiftId))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 0) {
                if !viewModel.shiftTitle.isEmpty {
                    Text(viewModel.shiftTitle)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(DarkText)
                    Spacer().frame(height: 16)
                }
                HStack(spacing: 10) {
                    Text("\u{1F4CE}")
                        .font(.system(size: 16))
                    Text("\(viewModel.fileCountText)")
                        .font(.system(size: 16))
                        .foregroundColor(SubText)
                }
            }
            .padding(.bottom, 20)

            // Files List
            if viewModel.isLoading {
                Spacer()
                ProgressView().tint(BluePrimary)
                Spacer()
            } else if viewModel.isEmpty {
                Spacer()
                VStack(spacing: 20) {
                    Text("\u{1F4C1}")
                        .font(.system(size: 48))
                        .foregroundColor(Gray400)
                    Text("No files attached yet")
                        .font(.system(size: 16))
                        .foregroundColor(Gray500)
                    Text("Tap the upload button below to add files")
                        .font(.system(size: 14))
                        .foregroundColor(Gray400)
                }
                Spacer()
            } else {
                List {
                    ForEach(Array(viewModel.files.enumerated()), id: \.offset) { index, file in
                        ShiftFileCard(file: file) {
                            let fullUrl = SHIFT_DOCS_SERVER_URL + file.fileUrl
                            let ext = (file.fileUrl as NSString).pathExtension.lowercased()
                            let isImg = ["jpg", "jpeg", "png", "gif", "bmp", "webp"].contains(ext)
                            onViewDocument(fullUrl, isImg)
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
            }

            // Upload Section
            VStack(spacing: 8) {
                if viewModel.isUploading {
                    ProgressView(value: viewModel.uploadProgress)
                        .tint(BluePrimary)
                    Text(viewModel.uploadStatusText)
                        .font(.system(size: 14))
                        .foregroundColor(Gray500)
                }

                Button(action: { viewModel.showUploadOptions = true }) {
                    Text("\u{1F4CE} Upload Files")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(viewModel.isEnabled ? BluePrimary : BluePrimary.opacity(0.5))
                        .cornerRadius(8)
                }
                .disabled(!viewModel.isEnabled)
            }
            .padding(.top, 20)
        }
        .padding(16)
        .background(BgColor)
        .navigationTitle("Job Files")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .onAppear { viewModel.loadInitialData() }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                }
            }
        }
        .confirmationDialog("Select Upload Option", isPresented: $viewModel.showUploadOptions) {
            Button("Upload from Gallery") {
                showingImagePicker = true
            }
            Button("Upload from Files") {
                showingFilePicker = true
            }
            Button("Cancel", role: .cancel) {}
        }
        .fileImporter(isPresented: $showingFilePicker, allowedContentTypes: [.pdf, .png, .jpeg], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result {
                viewModel.uploadFiles(urls)
            }
        }
        .photosPicker(isPresented: $showingImagePicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { _, item in
            guard let item = item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
                    let timestamp = dateFormatter.string(from: Date())
                    let fileName = "IMG_\(timestamp).jpg"
                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                    try? data.write(to: tempURL)
                    viewModel.uploadFiles([tempURL])
                }
                selectedPhotoItem = nil
            }
        }
        .snackbar(message: Binding(get: { viewModel.errorMessage ?? viewModel.successMessage }, set: { _ in viewModel.clearError(); viewModel.clearSuccessMessage() }))
    }
}

private struct ShiftFileCard: View {
    let file: FileUploadModelDto
    let onTap: () -> Void

    private var isImageFile: Bool {
        let ext = (file.fileUrl as NSString).pathExtension.lowercased()
        return ["jpg", "jpeg", "png", "gif", "bmp", "webp"].contains(ext)
    }

    var body: some View {
        HStack(spacing: 12) {
            if isImageFile {
                AsyncImage(url: URL(string: "https://doerapi.doer.nz/userDocuments/" + file.fileUrl)) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray.opacity(0.2)
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(file.fileName)
                    .font(.system(size: 16, weight: .bold))
                    .underline()
                    .foregroundColor(Color(hex: "#1F2937"))
                    .lineLimit(2)
                Text(file.createdByName)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#6B7280"))
                Text(formatFileDate(file.createdDate))
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#6B7280"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onTap) {
                Text("\u{1F441}\u{FE0F}")
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: "#3B82F6"))
            }
        }
        .padding(16)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "#E5E7EB"), lineWidth: 1)
        )
        .cornerRadius(12)
        .onTapGesture(perform: onTap)
    }
}

private func formatFileDate(_ dateStr: String) -> String {
    guard !dateStr.isEmpty else { return "" }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    let formats = [
        "yyyy-MM-dd'T'HH:mm:ss.SSSSSSS",
        "yyyy-MM-dd'T'HH:mm:ss.SSS",
        "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd'T'HH:mm",
        "yyyy-MM-dd HH:mm:ss",
        "yyyy-MM-dd HH:mm"
    ]
    for fmt in formats {
        formatter.dateFormat = fmt
        if let date = formatter.date(from: dateStr.trimmingCharacters(in: .whitespaces)) {
            formatter.dateFormat = "dd/MM/yyyy"
            return formatter.string(from: date)
        }
    }
    return dateStr
}
