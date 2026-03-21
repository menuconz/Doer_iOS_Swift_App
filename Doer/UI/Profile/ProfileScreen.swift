import SwiftUI

private let BgColor = Color(hex: "#F8F9FA")
private let BlueLabel = Color(hex: "#4D4BA3")
private let DocNameColor = Color(hex: "#337AB7")
private let NoDocBg = Color(hex: "#FFF3E0")
private let BorderStrokeColor = Color(hex: "#667685")
private let DocItemBg = Color(hex: "#FAFAFA")
private let PROFILE_DOCS_SERVER_URL = "https://doerapi.doer.nz"

struct ProfileScreen: View {
    var onOpenDrawer: () -> Void
    var onEditProfile: () -> Void
    var onDeletedAccount: () -> Void
    var onViewDocument: (String, Bool) -> Void
    var successMessage: String? = nil
    var onSuccessMessageShown: () -> Void = {}

    @State private var viewModel = ProfileViewModel()
    @State private var showDeleteDialog = false
    @State private var shownSuccessMessage: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            if let user = viewModel.user {
                ScrollView {
                    VStack(spacing: 20) {
                        ProfileInfoCard(emoji: "\u{1F464}", label: "Name", value: user.displayName)

                        if viewModel.isCustomer {
                            ProfileInfoCard(emoji: "\u{1F3E0}", label: "Address", value: user.address)
                        }

                        if !viewModel.isCustomer {
                            ProfileInfoCard(emoji: "\u{1F4C5}", label: "Date of Birth", value: formatDob(user.dateOfBirth))
                        }

                        ProfileInfoCard(emoji: "\u{1F4E7}", label: "Email", value: user.email)
                        ProfileInfoCard(emoji: "\u{1F4F1}", label: "Phone Number", value: user.phoneNumber)

                        if viewModel.isCaregiver {
                            ProfileInfoCard(emoji: "\u{1F4CD}", label: "Address", value: user.address)
                            ProfileInfoCard(emoji: "\u{1F4BC}", label: "Work Experience", value: user.workExperience)
                            ProfileInfoCard(emoji: "\u{2B50}", label: "Skills", value: user.skills)

                            // Documents Section
                            VStack(alignment: .leading, spacing: 0) {
                                HStack(spacing: 8) {
                                    Text("\u{1F4C4}").font(.system(size: 18))
                                    Text("Documents").font(.system(size: 16)).foregroundColor(BlueLabel)
                                }
                                .padding(.bottom, 12)

                                if user.documents?.isEmpty ?? true {
                                    HStack(spacing: 10) {
                                        Text("\u{1F4DD}").font(.system(size: 16))
                                        Text("No Documents found.").font(.system(size: 16)).foregroundColor(BlueLabel)
                                    }
                                    .padding(15)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(NoDocBg)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(BorderStrokeColor, lineWidth: 1))
                                    .cornerRadius(10)
                                } else {
                                    ForEach(user.documents ?? [], id: \.id) { doc in
                                        Button(action: {
                                            let isImage = doc.type.localizedCaseInsensitiveContains("image") ||
                                                doc.name.hasSuffix(".jpg") || doc.name.hasSuffix(".jpeg") || doc.name.hasSuffix(".png")
                                            let fullUrl = PROFILE_DOCS_SERVER_URL + doc.fileUrl
                                            onViewDocument(fullUrl, isImage)
                                        }) {
                                            HStack(spacing: 10) {
                                                Text("\u{1F4CB}").font(.system(size: 16)).foregroundColor(BlueLabel)
                                                Text(doc.name)
                                                    .font(.system(size: 16, weight: .bold))
                                                    .foregroundColor(DocNameColor)
                                                    .underline()
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                Text("\u{1F441}\u{FE0F}").font(.system(size: 16)).foregroundColor(DocNameColor)
                                            }
                                            .padding(15)
                                        }
                                        .background(DocItemBg)
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(BorderStrokeColor, lineWidth: 1))
                                        .cornerRadius(10)
                                        .padding(.vertical, 5)
                                    }
                                }
                            }
                            .padding(20)
                            .background(Color.white)
                            .cornerRadius(15)
                            .shadow(radius: 1)
                        }

                        // Action Buttons
                        Spacer().frame(height: 20)

                        Button(action: onEditProfile) {
                            Text("\u{270F}\u{FE0F} Edit Profile")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .frame(width: 180, height: 40)
                        .background(Color.black)
                        .cornerRadius(20)
                        .shadow(radius: 1)

                        Button(action: { showDeleteDialog = true }) {
                            Text("\u{1F5D1}\u{FE0F} Delete Account")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .frame(width: 180, height: 40)
                        .background(Color.black)
                        .cornerRadius(20)
                        .shadow(radius: 1)

                        Spacer().frame(height: 30)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 30)
                }
                .background(BgColor)
            }
        }
        .loadingOverlay(viewModel.isLoading || viewModel.isDeleting)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .onAppear { viewModel.loadInitialData() }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: onOpenDrawer) { Image(systemName: "line.3.horizontal") }
            }
        }
        .alert("Confirmation", isPresented: $showDeleteDialog) {
            Button("Yes", role: .destructive) { viewModel.deleteAccount() }
            Button("No", role: .cancel) {}
        } message: {
            Text("Are you sure you want to permanently delete your account?")
        }
        .alert("Account Deleted", isPresented: Binding(
            get: { viewModel.deleteSuccessMessage != nil },
            set: { if !$0 { viewModel.onDeleteSuccessDismissed() } }
        )) {
            Button("OK") { viewModel.onDeleteSuccessDismissed() }
        } message: {
            Text(viewModel.deleteSuccessMessage ?? "")
        }
        .onChange(of: viewModel.isDeleted) { _, deleted in
            if deleted { onDeletedAccount() }
        }
        .snackbar(message: Binding(
            get: { shownSuccessMessage ?? viewModel.errorMessage },
            set: { _ in shownSuccessMessage = nil; viewModel.clearError() }
        ))
        .onChange(of: successMessage) { _, msg in
            if let msg = msg {
                onSuccessMessageShown()
                shownSuccessMessage = msg
            }
        }
    }

    private func formatDob(_ dob: String?) -> String {
        guard let dob = dob, !dob.isEmpty else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let cleaned = dob.components(separatedBy: "T").first ?? dob
        if let date = formatter.date(from: cleaned) {
            formatter.dateFormat = "dd/MM/yyyy"
            return formatter.string(from: date)
        }
        return dob
    }
}

// MARK: - Profile Info Card
private struct ProfileInfoCard: View {
    let emoji: String
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(emoji).font(.system(size: 18))
                Text(label).font(.system(size: 16)).foregroundColor(Color(hex: "#4D4BA3"))
            }
            Text(value.isEmpty ? "" : value)
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "#4D4BA3"))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(15)
        .shadow(radius: 1)
    }
}
