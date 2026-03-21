import Foundation

@Observable
class ViewDocumentViewModel {
    var fileUrl: String = ""
    var isImage: Bool = false
    var documentName: String = ""

    init(fileUrl: String, isImage: Bool) {
        let decodedUrl = fileUrl.removingPercentEncoding ?? fileUrl
        self.fileUrl = decodedUrl
        self.isImage = isImage
        self.documentName = (decodedUrl as NSString).lastPathComponent.components(separatedBy: "?").first ?? ""
    }
}
