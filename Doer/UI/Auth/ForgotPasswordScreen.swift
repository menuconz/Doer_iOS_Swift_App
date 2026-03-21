import SwiftUI

struct ForgotPasswordScreen: View {
    var onBack: () -> Void
    var onResetSuccess: () -> Void

    @State private var viewModel = ForgotPasswordViewModel()
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case email, otp, newPassword, confirmPassword
    }

    var body: some View {
        VStack(spacing: 0) {
            // Navigation Bar
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundColor(.primary)
                }
                Text("Forgot Password")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            ScrollView {
                VStack(spacing: 0) {
                    if !viewModel.otpSent {
                        // Step 1: Enter email to generate OTP
                        Text("Enter your email address and we'll send you an OTP to reset your password.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)

                        Spacer().frame(height: 24)

                        VStack(alignment: .leading, spacing: 4) {
                            TextField("Email", text: Binding(
                                get: { viewModel.email },
                                set: { viewModel.onEmailChange($0) }
                            ))
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .focused($focusedField, equals: .email)
                            .submitLabel(.done)
                            .onSubmit {
                                focusedField = nil
                                viewModel.generateOtp()
                            }
                            .textFieldStyle(.roundedBorder)

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

                        Button(action: { viewModel.generateOtp() }) {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                            } else {
                                Text("Send OTP")
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(DoerTheme.primary)
                        .disabled(viewModel.isLoading)

                    } else {
                        // Step 2: Enter OTP and new password
                        Text("An OTP has been sent to \(viewModel.email). Enter the OTP and your new password below.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)

                        Spacer().frame(height: 24)

                        // OTP Field
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("OTP", text: Binding(
                                get: { viewModel.otp },
                                set: { viewModel.onOtpChange($0) }
                            ))
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .otp)
                            .textFieldStyle(.roundedBorder)

                            if let error = viewModel.otpError {
                                Text(error).font(.caption).foregroundColor(.red)
                            }
                        }

                        Spacer().frame(height: 8)

                        // New Password
                        VStack(alignment: .leading, spacing: 4) {
                            SecureField("New Password", text: Binding(
                                get: { viewModel.newPassword },
                                set: { viewModel.onNewPasswordChange($0) }
                            ))
                            .textContentType(.newPassword)
                            .focused($focusedField, equals: .newPassword)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .confirmPassword }
                            .textFieldStyle(.roundedBorder)

                            if let error = viewModel.passwordError {
                                Text(error).font(.caption).foregroundColor(.red)
                            }
                        }

                        Spacer().frame(height: 8)

                        // Confirm Password
                        VStack(alignment: .leading, spacing: 4) {
                            SecureField("Confirm Password", text: Binding(
                                get: { viewModel.confirmPassword },
                                set: { viewModel.onConfirmPasswordChange($0) }
                            ))
                            .textContentType(.newPassword)
                            .focused($focusedField, equals: .confirmPassword)
                            .submitLabel(.done)
                            .onSubmit {
                                focusedField = nil
                                viewModel.resetPassword()
                            }
                            .textFieldStyle(.roundedBorder)

                            if let error = viewModel.confirmPasswordError {
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

                        Button(action: { viewModel.resetPassword() }) {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                            } else {
                                Text("Reset Password")
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(DoerTheme.primary)
                        .disabled(viewModel.isLoading)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
        }
        .navigationBarHidden(true)
        .onChange(of: viewModel.resetSuccess) { _, success in
            if success { onResetSuccess() }
        }
    }
}
