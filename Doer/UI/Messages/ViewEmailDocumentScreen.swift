import SwiftUI

struct ViewEmailDocumentScreen: View {
    var onBack: () -> Void

    @State private var viewModel: ViewEmailDocumentViewModel
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero

    init(fileUrl: String, onBack: @escaping () -> Void) {
        self.onBack = onBack
        _viewModel = State(initialValue: ViewEmailDocumentViewModel(fileUrl: fileUrl))
    }

    var body: some View {
        GeometryReader { _ in
            ZStack {
                Color.black.ignoresSafeArea()

                AsyncImage(url: URL(string: viewModel.fileUrl)) { phase in
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
                                        scale = min(max(value, 0.5), 5.0)
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
                        ProgressView().tint(.white)
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(viewModel.fileName.isEmpty ? "Attachment" : viewModel.fileName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: onBack) { Image(systemName: "chevron.left").foregroundColor(.white) }
            }
        }
    }
}
