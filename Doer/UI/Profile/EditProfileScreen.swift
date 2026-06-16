import SwiftUI
import UniformTypeIdentifiers

private let BgColor = Color(hex: "#F8F9FA")
private let BlueLabel = Color(hex: "#4D4BA3")
private let BorderStrokeColor = Color(hex: "#667685")
private let DeletePinkBg = Color(hex: "#FFE6E6")
private let NoDocBg = Color(hex: "#FFF3E0")
private let DocItemBg = Color(hex: "#FAFAFA")
private let PROFILE_DOCS_SERVER_URL = "https://doerapi.doer.nz"

struct EditProfileScreen: View {
    var onBack: () -> Void
    var onSuccess: (String) -> Void

    @State private var viewModel = EditProfileViewModel()
    @State private var showDatePicker = false
    @State private var selectedDate = Date()
    @State private var showDeleteDocDialog: FileModelDto? = nil
    @State private var showFilePicker = false
    @State private var showSuccessAlert = false

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 25) {
                        // Name Field (always visible)
                        EditProfileFieldLabel("\u{1F464}", "Name")
                        EditProfileBorderedEntryField(value: $viewModel.name, placeholder: "Enter Name")
                            .onChange(of: viewModel.name) { _, _ in viewModel.nameError = nil }
                        FieldError(viewModel.nameError)

                        // Address Field (Customer only, with Google Places)
                        if viewModel.isCustomer {
                            EditProfileFieldLabel("\u{1F3E0}", "Address")
                            EditProfileBorderedEntryField(
                                value: Binding(
                                    get: { viewModel.searchAddress },
                                    set: { viewModel.onSearchAddressChange($0) }
                                ),
                                placeholder: "Enter Address"
                            )
                            if viewModel.showPlaceList && !viewModel.placeList.isEmpty {
                                VStack(spacing: 0) {
                                    ForEach(viewModel.placeList, id: \.placeId) { place in
                                        Text(place.description)
                                            .font(.system(size: 14))
                                            .foregroundColor(BlueLabel)
                                            .padding(10)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(BgColor)
                                            .cornerRadius(6)
                                            .onTapGesture { viewModel.selectPlace(place) }
                                    }
                                }
                                .padding(10)
                                .background(Color.white)
                                .cornerRadius(8)
                                .shadow(radius: 1)
                            }
                        }

                        // Date of Birth (non-customer only)
                        if !viewModel.isCustomer {
                            EditProfileFieldLabel("\u{1F4C5}", "Date Of Birth")
                            Button(action: { showDatePicker = true }) {
                                Text(viewModel.dateOfBirth.isEmpty ? "Select DateofBirth" : viewModel.dateOfBirth)
                                    .font(.system(size: 16))
                                    .foregroundColor(viewModel.dateOfBirth.isEmpty ? .gray : .black)
                                    .frame(maxWidth: .infinity, minHeight: 55, alignment: .leading)
                                    .padding(.horizontal, 15)
                                    .background(Color.white)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(BorderStrokeColor, lineWidth: 2))
                                    .cornerRadius(12)
                            }
                            .shadow(radius: 1)
                            FieldError(viewModel.dobError)
                        }

                        // Email Field (always visible)
                        EditProfileFieldLabel("\u{1F4E7}", "Email")
                        EditProfileBorderedEntryField(value: $viewModel.email, placeholder: "Enter Email")
                            .onChange(of: viewModel.email) { _, _ in viewModel.emailError = nil }
                        FieldError(viewModel.emailError)

                        // Phone Number Field (always visible)
                        EditProfileFieldLabel("\u{1F4F1}", "Phone Number")
                        EditProfileBorderedEntryField(value: $viewModel.phone, placeholder: "Enter Phone Number")
                            .onChange(of: viewModel.phone) { _, _ in viewModel.phoneError = nil }
                        FieldError(viewModel.phoneError)

                        // Caregiver-only fields
                        if viewModel.isCaregiver {
                            // Address with Google Places
                            EditProfileFieldLabel("\u{1F4CD}", "Address")
                            VStack(spacing: 0) {
                                EditProfileBorderedEntryField(
                                    value: Binding(
                                        get: { viewModel.searchAddress },
                                        set: { viewModel.onSearchAddressChange($0) }
                                    ),
                                    placeholder: "Enter Address"
                                )
                                if viewModel.showPlaceList && !viewModel.placeList.isEmpty {
                                    VStack(spacing: 0) {
                                        ForEach(viewModel.placeList, id: \.placeId) { place in
                                            Text(place.description)
                                                .font(.system(size: 14))
                                                .foregroundColor(BlueLabel)
                                                .padding(10)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .background(Color.white)
                                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(hex: "#E0E0E0"), lineWidth: 1))
                                                .cornerRadius(6)
                                                .onTapGesture { viewModel.selectPlace(place) }
                                        }
                                    }
                                    .padding(10)
                                    .background(BgColor)
                                    .cornerRadius(8)
                                }
                            }

                            // Work Experience
                            EditProfileFieldLabel("\u{1F4BC}", "Work Experience")
                            EditProfileBorderedEntryField(value: $viewModel.workExperience, placeholder: "Enter Work Experience")

                            // Skills
                            EditProfileFieldLabel("\u{2B50}", "Skills")
                            EditProfileBorderedEntryField(value: $viewModel.skills, placeholder: "Enter Skills")

                            // Your Documents Section
                            HStack(spacing: 5) {
                                Text("\u{1F4CB}").font(.system(size: 16))
                                Text("Your Documents")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(BlueLabel)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            // No documents message
                            if viewModel.isNoDocument {
                                HStack(spacing: 10) {
                                    Text("\u{1F4DD}").font(.system(size: 16))
                                    Text("No Documents found.").font(.system(size: 16)).foregroundColor(.gray)
                                }
                                .padding(15)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(NoDocBg)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray, lineWidth: 1))
                                .cornerRadius(10)
                            }

                            // Existing documents list
                            if viewModel.hasDocument && !viewModel.existingDocuments.isEmpty {
                                VStack(spacing: 0) {
                                    ForEach(viewModel.existingDocuments, id: \.id) { doc in
                                        HStack(spacing: 8) {
                                            Text("\u{1F4C4}").font(.system(size: 16)).foregroundColor(Color(hex: "#FF9500"))
                                            Text(doc.name).font(.system(size: 16)).foregroundColor(.gray).frame(maxWidth: .infinity, alignment: .leading)
                                            Button(action: { showDeleteDocDialog = doc }) {
                                                Image(systemName: "trash")
                                                    .foregroundColor(.red)
                                                    .frame(width: 36, height: 36)
                                                    .background(DeletePinkBg)
                                                    .cornerRadius(15)
                                            }
                                        }
                                        .padding(12)
                                        .background(DocItemBg)
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#E0E0E0"), lineWidth: 1))
                                        .cornerRadius(8)
                                        .padding(.vertical, 3)
                                    }
                                }
                                .padding(10)
                                .background(Color.white)
                                .cornerRadius(12)
                                .shadow(radius: 1)
                            }

                            // New documents (pending upload)
                            if !viewModel.newDocuments.isEmpty {
                                ForEach(Array(viewModel.newDocuments.enumerated()), id: \.offset) { index, doc in
                                    HStack(spacing: 8) {
                                        Text("\u{1F4C4}").font(.system(size: 16))
                                        VStack(alignment: .leading) {
                                            Text(doc.fileName)
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(.blue)
                                            Text("Tap to view").font(.system(size: 12)).foregroundColor(.gray)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        Button(action: { viewModel.removeNewDocument(at: index) }) {
                                            Image(systemName: "trash")
                                                .foregroundColor(.red)
                                                .frame(width: 36, height: 36)
                                                .background(DeletePinkBg)
                                                .cornerRadius(15)
                                        }
                                    }
                                    .padding(10)
                                    .background(BgColor)
                                    .cornerRadius(8)
                                }
                            }

                            // Add Documents Button
                            Button(action: { showFilePicker = true }) {
                                Text("Add Documents")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .frame(width: 140, height: 40)
                            .background(Color.black)
                            .cornerRadius(20)
                            .shadow(radius: 1)

                            Text("\u{2139}\u{FE0F} Accepts only PDF, PNG, JPG and JPEG file types")
                                .font(.system(size: 13))
                                .foregroundColor(.red)
                        }

                        // Update Profile Button
                        Spacer().frame(height: 20)
                        Button(action: { viewModel.saveProfile() }) {
                            if viewModel.isSaving {
                                ProgressView().tint(.white)
                            } else {
                                Text("Update Profile")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(width: 140, height: 40)
                        .background(Color.black)
                        .cornerRadius(20)
                        .shadow(radius: 1)
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
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .onAppear { viewModel.loadInitialData() }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: onBack) { Image(systemName: "chevron.left") }
            }
        }
        .sheet(isPresented: $showDatePicker) {
            VStack {
                DatePicker("Date of Birth", selection: $selectedDate, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()
                HStack {
                    Button("Cancel") { showDatePicker = false }
                    Spacer()
                    Button("OK") {
                        viewModel.updateDateOfBirthFromPicker(selectedDate)
                        showDatePicker = false
                    }
                }
                .padding()
            }
        }
        .alert("Confirmation", isPresented: Binding(
            get: { showDeleteDocDialog != nil },
            set: { if !$0 { showDeleteDocDialog = nil } }
        )) {
            Button("Yes", role: .destructive) {
                if let doc = showDeleteDocDialog {
                    viewModel.deleteExistingDocument(doc)
                    showDeleteDocDialog = nil
                }
            }
            Button("No", role: .cancel) { showDeleteDocDialog = nil }
        } message: {
            Text("Are you sure you want to delete this document?")
        }
        .alert("Success", isPresented: $showSuccessAlert) {
            Button("OK") {
                let msg = viewModel.successMessage ?? ""
                viewModel.clearSuccess()
                onSuccess(msg)
            }
        } message: {
            Text(viewModel.successMessage ?? "")
        }
        .onChange(of: viewModel.successMessage) { _, msg in
            if msg != nil { showSuccessAlert = true }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.pdf, .png, .jpeg],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                for url in urls {
                    guard url.startAccessingSecurityScopedResource() else { continue }
                    defer { url.stopAccessingSecurityScopedResource() }
                    if let data = try? Data(contentsOf: url) {
                        let fileName = url.lastPathComponent
                        viewModel.addDocument(data: data, fileName: fileName)
                    }
                }
            case .failure:
                break
            }
        }
        .snackbar(message: Binding(
            get: { viewModel.errorMessage },
            set: { _ in viewModel.clearError() }
        ))
    }
}

// MARK: - Inline Field Error
/// Shows a red validation message under a field, or nothing when `message` is nil.
private struct FieldError: View {
    let message: String?
    init(_ message: String?) { self.message = message }

    var body: some View {
        if let message {
            Text(message)
                .font(.caption)
                .foregroundColor(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Field Label
private struct EditProfileFieldLabel: View {
    let emoji: String
    let label: String

    init(_ emoji: String, _ label: String) {
        self.emoji = emoji
        self.label = label
    }

    var body: some View {
        HStack(spacing: 5) {
            Text(emoji).font(.system(size: 16))
            Text(label)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(hex: "#4D4BA3"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Bordered Entry Field
private struct EditProfileBorderedEntryField: View {
    @Binding var value: String
    let placeholder: String

    var body: some View {
        TextField(placeholder, text: $value)
            .font(.system(size: 16))
            .frame(height: 55)
            .padding(.horizontal, 15)
            .background(Color.white)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#667685"), lineWidth: 2))
            .cornerRadius(12)
            .shadow(radius: 1)
    }
}
