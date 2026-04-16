import SwiftUI

struct LoginScreen: View {
    var onLoginSuccess: () -> Void
    var onForgotPassword: () -> Void
    var onRegisterContractor: () -> Void
    var onRegisterManager: () -> Void

    @State private var viewModel = LoginViewModel()
    @FocusState private var focusedField: Field?

    private enum Field {
        case email, password
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: 32)

                // Logo
                Image("doer_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)

//                Spacer().frame(height: 1)

                // Title
                Text("Welcome to Doer")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(DoerTheme.primary)

                Spacer().frame(height: 24)

                // Email Field
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
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }
                    .textFieldStyle(.roundedBorder)

                    if let error = viewModel.emailError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                Spacer().frame(height: 8)

                // Password Field
                VStack(alignment: .leading, spacing: 4) {
                    SecureField("Password", text: Binding(
                        get: { viewModel.password },
                        set: { viewModel.onPasswordChange($0) }
                    ))
                    .textContentType(.password)
                    .focused($focusedField, equals: .password)
                    .submitLabel(.done)
                    .onSubmit {
                        focusedField = nil
                        viewModel.login()
                    }
                    .textFieldStyle(.roundedBorder)

                    if let error = viewModel.passwordError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                Spacer().frame(height: 4)

                // Forgot Password
                HStack {
                    Spacer()
                    Button("Forgot Password?") {
                        onForgotPassword()
                    }
                    .font(.subheadline)
                    .foregroundColor(DoerTheme.primary)
                    .padding(4)
                }

                Spacer().frame(height: 16)

                // Error Message
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    Spacer().frame(height: 8)
                }

                // Login Button
                Button(action: { viewModel.login() }) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                    } else {
                        Text("Login")
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(DoerTheme.primary)
                .disabled(viewModel.isLoading)

                Spacer().frame(height: 24)

                // Register Section
                Text("Don't have an account?")
                    .font(.subheadline)

                Spacer().frame(height: 8)

                Button(action: onRegisterContractor) {
                    Text("Register as Contractor")
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                }
                .buttonStyle(.bordered)
                .tint(DoerTheme.primary)

                Spacer().frame(height: 8)

                Button(action: onRegisterManager) {
                    Text("Register as Manager")
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                }
                .buttonStyle(.bordered)
                .tint(DoerTheme.primary)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(.systemBackground))
        .onChange(of: viewModel.loginSuccess) { _, success in
            if success { onLoginSuccess() }
        }
    }
}
