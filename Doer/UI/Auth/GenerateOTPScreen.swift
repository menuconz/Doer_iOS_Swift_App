import SwiftUI

struct GenerateOTPScreen: View {
    var onBack: () -> Void
    var onSuccess: (String) -> Void

    @State private var viewModel = GenerateOTPViewModel()
    @FocusState private var emailFocused: Bool

    private let bgColor = Color(hex: "#F8F9FA")

    var body: some View {
        VStack(spacing: 0) {
            // Navigation Bar
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundColor(.primary)
                }
                Text("Generate OTP")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            ScrollView {
                VStack(spacing: 0) {
                    Text("Enter your email address and we'll send you a one-time password.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)

                    Spacer().frame(height: 24)

                    // Email Field with leading icon
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "envelope")
                                .foregroundColor(.gray)
                            TextField("", text: Binding(
                                get: { viewModel.email },
                                set: { viewModel.onEmailChange($0) }
                            ), prompt: Text("Email ") + Text("*").foregroundColor(.red))
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .focused($emailFocused)
                            .submitLabel(.done)
                            .onSubmit {
                                emailFocused = false
                                viewModel.generateOtp()
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(viewModel.emailError != nil ? Color.red : Color(.systemGray4), lineWidth: 1)
                        )

                        if let error = viewModel.emailError {
                            Text(error).font(.caption).foregroundColor(.red)
                        }
                    }

                    Spacer().frame(height: 16)

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)

                        Spacer().frame(height: 8)
                    }

                    // Generate OTP Button
                    Button(action: { viewModel.generateOtp() }) {
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                        } else {
                            Text("Generate OTP")
                                .fontWeight(.bold)
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                        }
                    }
                    .background(Color.black)
                    .cornerRadius(20)
                    .disabled(viewModel.isLoading)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .background(bgColor)
        }
        .navigationBarHidden(true)
        .onChange(of: viewModel.otpGenerated) { _, generated in
            if generated {
                onSuccess(viewModel.email.trimmingCharacters(in: .whitespaces))
            }
        }
    }
}
