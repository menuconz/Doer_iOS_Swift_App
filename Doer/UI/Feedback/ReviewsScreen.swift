import SwiftUI

private let BgColor = Color(hex: "#F8F9FA")
private let Blue = Color(hex: "#4D4BA3")
private let BorderStrokeColor = Color(hex: "#667685")

struct ReviewsScreen: View {
    var onBack: () -> Void
    var onSuccess: () -> Void

    @State private var viewModel: ReviewsViewModel

    init(shiftId: Int, onBack: @escaping () -> Void, onSuccess: @escaping () -> Void) {
        self.onBack = onBack
        self.onSuccess = onSuccess
        _viewModel = State(initialValue: ReviewsViewModel(shiftId: shiftId))
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 25) {
                        // Manager Feedback Section
                        if viewModel.hasManagerFeedback {
                            VStack(alignment: .leading, spacing: 15) {
                                HStack(spacing: 8) {
                                    Text("\u{1F454}").font(.system(size: 18))
                                    Text("Manager Feedback:")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(Blue)
                                }
                                TextEditor(text: .constant(viewModel.managerFeedback))
                                    .font(.system(size: 16))
                                    .frame(minHeight: 100)
                                    .disabled(true)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(BorderStrokeColor, lineWidth: 2)
                                    )
                                    .cornerRadius(12)
                            }
                            .padding(20)
                            .background(Color.white)
                            .cornerRadius(15)
                            .shadow(radius: 1)
                        }

                        // Your Reply Section
                        VStack(alignment: .leading, spacing: 15) {
                            HStack(spacing: 8) {
                                Text("\u{1F4AC}").font(.system(size: 18))
                                Text("Your Reply:")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(Blue)
                            }
                            TextEditor(text: Binding(
                                get: { viewModel.replyText },
                                set: { viewModel.updateReplyText($0) }
                            ))
                            .font(.system(size: 16))
                            .frame(minHeight: 100)
                            .disabled(viewModel.hasExistingReply)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(BorderStrokeColor, lineWidth: 2)
                            )
                            .cornerRadius(12)
                            .overlay(alignment: .topLeading) {
                                if viewModel.replyText.isEmpty {
                                    Text("Enter Your Reply")
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

                        // Submit Button - visible when no existing reply
                        if !viewModel.hasExistingReply {
                            Button(action: { viewModel.submitReply() }) {
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
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 30)
                }
                .background(BgColor)
            }
        }
        .navigationTitle("Reviews")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .onAppear { viewModel.loadInitialData() }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: onBack) { Image(systemName: "chevron.left") }
            }
        }
        .onChange(of: viewModel.successMessage) { _, msg in
            if msg != nil {
                viewModel.clearSuccess()
                onSuccess()
            }
        }
        .snackbar(message: Binding(
            get: { viewModel.errorMessage },
            set: { _ in viewModel.clearError() }
        ))
    }
}
