import Foundation
import SwiftUI
import PhotosUI

@Observable
class ShiftFilesViewModel {
    var shiftTitle: String = ""
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
    private var hasLoaded = false

    static let allowedExtensions = ["pdf", "png", "jpg", "jpeg"]

    init(
        shiftId: String,
        shiftRepository: ShiftRepository = DIContainer.shared.shiftRepository
    ) {
        self.shiftId = shiftId
        self.shiftRepository = shiftRepository
    }

    func loadInitialData() {
        guard !hasLoaded else { return }
        hasLoaded = true
        loadShiftTitle()
        loadFiles()
    }

    private func loadShiftTitle() {
        Task { @MainActor in
            guard let id = Int(shiftId) else { return }
            let result = await shiftRepository.getShiftById(id: id)
            if case .success(let shift) = result {
                shiftTitle = shift.projectName
            }
        }
    }

    private func loadFiles() {
        Task { @MainActor in
            isLoading = true
            errorMessage = nil
            let result = await shiftRepository.getShiftFiles(shiftId: shiftId)
            switch result {
            case .success(let data):
                print("[DEBUG] Files loaded: \(data.count)")
                for f in data {
                    print("[DEBUG] File: name='\(f.fileName)' url='\(f.fileUrl)' isImage=\(f.isImage) thumbnail='\(f.thumbnailUrl)'")
                }
                files = data
                fileCountText = data.count
                isEmpty = data.isEmpty
                hasFiles = !data.isEmpty
                isLoading = false
            case .error(let message, _):
                isLoading = false
                isEmpty = true
                hasFiles = false
                errorMessage = message
            case .loading:
                break
            }
        }
    }

    func refresh() {
        loadFiles()
    }

    func showUploadDialog() {
        showUploadOptions = true
    }

    func dismissUploadDialog() {
        showUploadOptions = false
    }

    func uploadFiles(_ urls: [URL]) {
        let validUrls = urls.filter { url in
            let ext = url.pathExtension.lowercased()
            return Self.allowedExtensions.contains(ext)
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
            let result = await shiftRepository.uploadFile(shiftId: shiftId, subItemId: nil, files: files)
            switch result {
            case .success:
                uploadProgress = 0.75
                uploadProgress = 1.0
                isUploading = false
                isEnabled = true
                uploadStatusText = "Files uploaded successfully"
                successMessage = "Files uploaded successfully"
                loadFiles()
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

    func clearError() {
        errorMessage = nil
    }

    func clearSuccessMessage() {
        successMessage = nil
    }
}
