import SwiftUI

private let BgColor = Color(hex: "#F8F9FA")
private let LabelColor = Color(hex: "#667685")
private let BorderStrokeColor = Color(hex: "#667685")

struct SendQuoteScreen: View {
    var onBack: () -> Void

    @State private var viewModel: SendQuoteViewModel

    init(shiftId: Int, onBack: @escaping () -> Void) {
        self.onBack = onBack
        _viewModel = State(initialValue: SendQuoteViewModel(shiftId: shiftId))
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
                        // Quote Amount Section
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 5) {
                                Text("\u{1F4B5}").font(.system(size: 16))
                                Text("Quote Amount ($):")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(LabelColor)
                            }
                            VStack {
                                TextField("Enter the Quoted Amount ($)", text: $viewModel.quotedAmount)
                                    .keyboardType(.decimalPad)
                                    .font(.system(size: 16))
                                    .frame(height: 55)
                                    .padding(.horizontal, 15)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(BorderStrokeColor, lineWidth: 2)
                                    )
                            }
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(radius: 1)
                        }

                        // Notes Section
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 5) {
                                Text("\u{1F4DD}").font(.system(size: 16))
                                Text("Notes:")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(LabelColor)
                            }
                            VStack {
                                TextEditor(text: $viewModel.notes)
                                    .font(.system(size: 16))
                                    .frame(minHeight: 120)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(BorderStrokeColor, lineWidth: 2)
                                    )
                                    .cornerRadius(12)
                                    .overlay(alignment: .topLeading) {
                                        if viewModel.notes.isEmpty {
                                            Text("Enter the Notes")
                                                .font(.system(size: 16))
                                                .foregroundColor(.gray.opacity(0.5))
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 12)
                                                .allowsHitTesting(false)
                                        }
                                    }
                            }
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(radius: 1)
                        }

                        Spacer().frame(height: 20)

                        // Submit Button
                        Button(action: { viewModel.submitQuote() }) {
                            if viewModel.isSaving {
                                ProgressView().tint(.white)
                            } else {
                                Text("Submit Quote")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(width: 130, height: 40)
                        .background(Color.black)
                        .cornerRadius(20)
                        .disabled(viewModel.isSaving)

                        Spacer().frame(height: 30)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 30)
                }
                .scrollDismissesKeyboard(.interactively)
                .background(BgColor)
            }
        }
        .navigationTitle("Send Quote")
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
                onBack()
            }
        }
        .snackbar(message: Binding(
            get: { viewModel.errorMessage },
            set: { _ in viewModel.clearError() }
        ))
    }
}
