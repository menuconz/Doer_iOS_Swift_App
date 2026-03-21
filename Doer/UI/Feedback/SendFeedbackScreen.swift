import SwiftUI

private let BgColor = Color(hex: "#F8F9FA")
private let Blue = Color(hex: "#4D4BA3")
private let BorderStrokeColor = Color(hex: "#667685")

struct SendFeedbackScreen: View {
    var onBack: () -> Void
    var onSuccess: () -> Void

    @State private var viewModel: SendFeedbackViewModel
    @State private var showSuccessAlert = false

    init(shiftId: Int, onBack: @escaping () -> Void, onSuccess: @escaping () -> Void) {
        self.onBack = onBack
        self.onSuccess = onSuccess
        _viewModel = State(initialValue: SendFeedbackViewModel(shiftId: shiftId))
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 30) {
                        // Feedback Card
                        VStack(alignment: .leading, spacing: 15) {
                            HStack(spacing: 5) {
                                Text("\u{1F4AD}").font(.system(size: 16))
                                Text("Share Your Experience")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(Blue)
                            }

                            TextEditor(text: Binding(
                                get: { viewModel.feedbackText },
                                set: { viewModel.updateFeedback($0) }
                            ))
                            .font(.system(size: 16))
                            .frame(minHeight: 100)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(BorderStrokeColor, lineWidth: 2)
                            )
                            .cornerRadius(12)
                            .overlay(alignment: .topLeading) {
                                if viewModel.feedbackText.isEmpty {
                                    Text("Enter Feedback")
                                        .font(.system(size: 16))
                                        .foregroundColor(.gray.opacity(0.5))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 12)
                                        .allowsHitTesting(false)
                                }
                            }
                        }
                        .padding(20)
                        .background(Color.white)
                        .cornerRadius(15)
                        .shadow(radius: 1)

                        // Submit Button
                        Button(action: { viewModel.submitFeedback() }) {
                            if viewModel.isSaving {
                                ProgressView().tint(.white)
                            } else {
                                Text("Submit")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(width: 130, height: 40)
                        .background(Color.black)
                        .cornerRadius(20)
                        .disabled(viewModel.isSaving)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 40)
                    .padding(.bottom, 50)
                }
                .background(BgColor)
            }
        }
        .navigationTitle("Your Feedback")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .onAppear { viewModel.loadInitialData() }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: onBack) { Image(systemName: "chevron.left") }
            }
        }
        .alert("Success", isPresented: $showSuccessAlert) {
            Button("OK") {
                viewModel.clearSuccess()
                onSuccess()
            }
        } message: {
            Text(viewModel.successMessage ?? "")
        }
        .onChange(of: viewModel.successMessage) { _, msg in
            if msg != nil { showSuccessAlert = true }
        }
        .snackbar(message: Binding(
            get: { viewModel.errorMessage },
            set: { _ in viewModel.clearError() }
        ))
    }
}
