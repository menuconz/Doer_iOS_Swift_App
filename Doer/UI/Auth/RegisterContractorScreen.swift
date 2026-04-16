import SwiftUI
import UniformTypeIdentifiers

struct RegisterContractorScreen: View {
    var onBack: () -> Void
    var onSuccess: () -> Void

    @State private var viewModel = RegisterContractorViewModel()
    @State private var showDocumentPicker = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case fullName, email, phone, address, password, confirmPassword
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
                Text("Register as Contractor")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            ScrollView {
                VStack(spacing: 8) {
                    // Full Name
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Full Name *", text: Binding(
                            get: { viewModel.fullName },
                            set: { viewModel.onNameChange($0) }
                        ))
                        .focused($focusedField, equals: .fullName)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .email }
                        .textFieldStyle(.roundedBorder)

                        if let error = viewModel.nameError {
                            Text(error).font(.caption).foregroundColor(.red)
                        }
                    }

                    // Email
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Email Address *", text: Binding(
                            get: { viewModel.email },
                            set: { viewModel.onEmailChange($0) }
                        ))
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .focused($focusedField, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .phone }
                        .textFieldStyle(.roundedBorder)

                        if let error = viewModel.emailError {
                            Text(error).font(.caption).foregroundColor(.red)
                        }
                    }

                    // Date of Birth
                    VStack(alignment: .leading, spacing: 4) {
                        Button(action: { viewModel.showDatePicker.toggle() }) {
                            HStack {
                                Text(viewModel.dateOfBirth.isEmpty ? "Date of Birth" : viewModel.dateOfBirth)
                                    .foregroundColor(viewModel.dateOfBirth.isEmpty ? .gray : .primary)
                                Spacer()
                                Image(systemName: "calendar")
                                    .foregroundColor(.gray)
                            }
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                        }

                        if viewModel.showDatePicker {
                            DatePicker(
                                "Date of Birth",
                                selection: $viewModel.selectedDate,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.graphical)
                            .onChange(of: viewModel.selectedDate) { _, newValue in
                                viewModel.onDateSelected(newValue)
                            }
                        }
                    }

                    // Phone Number
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Phone Number", text: Binding(
                            get: { viewModel.phone },
                            set: { viewModel.onPhoneChange($0) }
                        ))
                        .keyboardType(.phonePad)
                        .focused($focusedField, equals: .phone)
                        .textFieldStyle(.roundedBorder)

                        Text("Optional but required to get contacted for jobs")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    // Address
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Address", text: Binding(
                            get: { viewModel.searchAddress },
                            set: { viewModel.onSearchAddressChange($0) }
                        ))
                        .focused($focusedField, equals: .address)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }
                        .textFieldStyle(.roundedBorder)

                        Text("Optional but check your availability in your area")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    // Place suggestions
                    if viewModel.showSuggestions {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(viewModel.placeSuggestions, id: \.placeId) { prediction in
                                Button(action: {
                                    viewModel.onPlaceSelected(prediction)
                                    focusedField = nil
                                }) {
                                    Text(prediction.description)
                                        .font(.subheadline)
                                        .foregroundColor(DoerTheme.primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 4)
                                }
                            }
                        }
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }

                    // Password
                    VStack(alignment: .leading, spacing: 4) {
                        SecureField("Password *", text: Binding(
                            get: { viewModel.password },
                            set: { viewModel.onPasswordChange($0) }
                        ))
                        .textContentType(.newPassword)
                        .focused($focusedField, equals: .password)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .confirmPassword }
                        .textFieldStyle(.roundedBorder)

                        if let error = viewModel.passwordError {
                            Text(error).font(.caption).foregroundColor(.red)
                        }
                    }

                    // Confirm Password
                    VStack(alignment: .leading, spacing: 4) {
                        SecureField("Confirm Password *", text: Binding(
                            get: { viewModel.confirmPassword },
                            set: { viewModel.onConfirmPasswordChange($0) }
                        ))
                        .textContentType(.newPassword)
                        .focused($focusedField, equals: .confirmPassword)
                        .submitLabel(.done)
                        .onSubmit { focusedField = nil }
                        .textFieldStyle(.roundedBorder)

                        if let error = viewModel.confirmPasswordError {
                            Text(error).font(.caption).foregroundColor(.red)
                        }
                    }

                    Spacer().frame(height: 8)

                    // Documents section
                    Text("Documents")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(DoerTheme.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer().frame(height: 4)

                    ForEach(Array(viewModel.documents.enumerated()), id: \.offset) { index, doc in
                        HStack {
                            Image(systemName: "doc.fill")
                                .frame(width: 20, height: 20)
                            Text(doc.fileName)
                                .font(.caption)
                                .lineLimit(1)
                            Spacer()
                            Button(action: { viewModel.removeDocument(at: index) }) {
                                Image(systemName: "xmark")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }

                    Spacer().frame(height: 4)

                    Button(action: { showDocumentPicker = true }) {
                        Text("Upload Your Documents")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(DoerTheme.primary)

                    Text("Accepts only PDF, PNG, JPG and JPEG file types")
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)

                    Spacer().frame(height: 8)

                    // Error Message
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)

                        Spacer().frame(height: 8)
                    }

                    // Register Button
                    Button(action: { viewModel.register() }) {
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                        } else {
                            Text("Register")
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(DoerTheme.primary)
                    .disabled(viewModel.isLoading)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationBarHidden(true)
        .fileImporter(
            isPresented: $showDocumentPicker,
            allowedContentTypes: [.pdf, .png, .jpeg],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                guard url.startAccessingSecurityScopedResource() else { return }
                defer { url.stopAccessingSecurityScopedResource() }
                if let data = try? Data(contentsOf: url) {
                    let fileName = url.lastPathComponent
                    viewModel.addDocument(data: data, fileName: fileName)
                }
            case .failure:
                break
            }
        }
        .alert(
            "Registration Successful",
            isPresented: Binding(
                get: { viewModel.successMessage != nil },
                set: { if !$0 { viewModel.successMessage = nil } }
            )
        ) {
            Button("OK") { onSuccess() }
        } message: {
            Text(viewModel.successMessage ?? "")
        }
    }
}
