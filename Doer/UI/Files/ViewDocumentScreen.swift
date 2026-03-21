import SwiftUI
import WebKit

struct ViewDocumentScreen: View {
    var onBack: () -> Void

    @State private var viewModel: ViewDocumentViewModel

    init(fileUrl: String, isImage: Bool, onBack: @escaping () -> Void) {
        self.onBack = onBack
        _viewModel = State(initialValue: ViewDocumentViewModel(fileUrl: fileUrl, isImage: isImage))
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.fileUrl.isEmpty {
                Spacer()
                Text("No document to display").foregroundColor(.gray)
                Spacer()
            } else if viewModel.isImage {
                ZoomableImageView(imageUrl: viewModel.fileUrl)
            } else {
                PdfWebView(url: viewModel.fileUrl)
            }
        }
        .background(Color.white)
        .navigationTitle(viewModel.documentName.isEmpty ? "Document" : viewModel.documentName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: onBack) { Image(systemName: "chevron.left") }
            }
        }
    }
}

// MARK: - Zoomable Image
private struct ZoomableImageView: View {
    let imageUrl: String
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero

    var body: some View {
        GeometryReader { _ in
            AsyncImage(url: URL(string: imageUrl)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = min(max(value, 1.0), 5.0)
                                }
                                .onEnded { _ in
                                    if scale <= 1.0 { offset = .zero }
                                }
                                .simultaneously(with: DragGesture()
                                    .onChanged { value in
                                        if scale > 1.0 {
                                            offset = value.translation
                                        }
                                    }
                                )
                        )
                case .failure:
                    Text("Failed to load image").foregroundColor(.gray)
                case .empty:
                    ProgressView()
                @unknown default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - PDF WebView
private struct PdfWebView: UIViewRepresentable {
    let url: String

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.configuration.preferences.javaScriptEnabled = true
        if let encoded = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let viewerUrl = URL(string: "https://docs.google.com/gview?embedded=true&url=\(encoded)") {
            webView.load(URLRequest(url: viewerUrl))
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
