import Foundation

@Observable
class ViewEmailDocumentViewModel {
    var fileUrl: String = ""
    var fileName: String = ""

    init(fileUrl: String) {
        let decodedUrl = fileUrl.removingPercentEncoding ?? fileUrl
        self.fileUrl = decodedUrl
        self.fileName = (decodedUrl as NSString).lastPathComponent.components(separatedBy: "?").first ?? ""
    }
}
