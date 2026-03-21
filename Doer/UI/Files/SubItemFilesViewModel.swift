import Foundation

@Observable
class SubItemFilesViewModel {
    var subItemTitle: String = ""
    var files: [FileUploadModelDto] = []
    var fileCountText: Int = 0
    var isEmpty: Bool = false
    var hasFiles: Bool = false
    var isLoading: Bool = true
    var isUploading: Bool = false
    var isEnabled: Bool = true
    var uploadProgress: Double = 0.0
    var uploadStatusText: String = ""
    var showUploadOptions: Bool = false
    var errorMessage: String? = nil
    var successMessage: String? = nil

    private let shiftRepository: ShiftRepository
    private let shiftId: String
    private let subItemId: String
    private var hasLoaded = false

    init(
        shiftId: String,
        subItemId: String,
        shiftRepository: ShiftRepository = DIContainer.shared.shiftRepository
    ) {
        self.shiftId = shiftId
        self.subItemId = subItemId
        self.shiftRepository = shiftRepository
    }

    func loadInitialData() {
        guard !hasLoaded else { return }
        hasLoaded = true
        loadFiles()
    }

    func refresh() { loadFiles() }

    private func loadFiles() {
        Task { @MainActor in
            if !isUploading { isLoading = true; errorMessage = nil }
            let result = await shiftRepository.getSubItemFiles(shiftId: shiftId, subItemId: subItemId)
            switch result {
            case .success(let data):
                files = data
                fileCountText = data.count
                isEmpty = data.isEmpty
                hasFiles = !data.isEmpty
                isLoading = false
            case .error(let message, _):
                isLoading = false
                isEmpty = true
                hasFiles = false
                fileCountText = 0
                errorMessage = message
            case .loading:
                break
            }
        }
    }

    func showUploadDialog() { showUploadOptions = true }
    func dismissUploadDialog() { showUploadOptions = false }

    func uploadFiles(_ urls: [URL]) {
        let validUrls = urls.filter { url in
            let ext = url.pathExtension.lowercased()
            return ShiftFilesViewModel.allowedExtensions.contains(ext)
        }
        guard !validUrls.isEmpty else {
            errorMessage = "Accepts only PDF, PNG, JPG and JPEG file types"
            return
        }
        Task { @MainActor in
            isUploading = true
            isEnabled = false
            uploadStatusText = "Uploading files..."
            uploadProgress = 0.0
            uploadProgress = 0.25
            uploadProgress = 0.50

            let files = validUrls.compactMap { url -> (data: Data, fileName: String)? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return (data: data, fileName: url.lastPathComponent)
            }
            let result = await shiftRepository.uploadFile(shiftId: shiftId, subItemId: subItemId, files: files)
            switch result {
            case .success:
                uploadProgress = 0.75
                uploadProgress = 1.0
                uploadStatusText = "Files uploaded successfully"
                successMessage = "Files uploaded successfully"
                loadFiles()
                isUploading = false
                isEnabled = true
            case .error(let message, _):
                isUploading = false
                isEnabled = true
                uploadStatusText = "Failed to upload files"
                errorMessage = message ?? "Failed to upload files"
            case .loading:
                break
            }
        }
    }

    func clearError() { errorMessage = nil }
    func clearSuccessMessage() { successMessage = nil }
}
