import SwiftUI

// MARK: - Snackbar Modifier
struct SnackbarModifier: ViewModifier {
    @Binding var message: String?

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let msg = message {
                Text(msg)
                    .padding()
                    .background(Color.black.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            message = nil
                        }
                    }
            }
        }
    }
}

// MARK: - Loading Overlay Modifier
struct LoadingOverlayModifier: ViewModifier {
    let isLoading: Bool

    func body(content: Content) -> some View {
        content.overlay {
            if isLoading {
                ZStack {
                    Color.black.opacity(0.15)
                        .ignoresSafeArea()
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.gray)
                }
            }
        }
    }
}

extension View {
    func snackbar(message: Binding<String?>) -> some View {
        modifier(SnackbarModifier(message: message))
    }

    func loadingOverlay(_ isLoading: Bool) -> some View {
        modifier(LoadingOverlayModifier(isLoading: isLoading))
    }
}
