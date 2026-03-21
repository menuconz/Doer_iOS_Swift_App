import SwiftUI

struct LoadingScreen: View {
    var onLoggedIn: () -> Void
    var onNotLoggedIn: () -> Void

    private let secureStorageManager = SecureStorageManager.shared

    var body: some View {
        VStack(spacing: 24) {
            Image("doer_logo")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)

            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: DoerTheme.primary))
                .scaleTransform(1.2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if secureStorageManager.isLoggedIn {
                onLoggedIn()
            } else {
                onNotLoggedIn()
            }
        }
    }
}

// MARK: - Helper for scaling ProgressView
private extension View {
    func scaleTransform(_ scale: CGFloat) -> some View {
        self.scaleEffect(scale)
    }
}
