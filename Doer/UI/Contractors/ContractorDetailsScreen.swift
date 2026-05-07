import SwiftUI

private let BgColor = Color(hex: "#F8F9FA")
private let BlueLabel = Color(hex: "#4D4BA3")
private let Gray500 = Color(hex: "#6B7280")
private let DocNameColor = Color(hex: "#337AB7")
private let NoDocBg = Color(hex: "#FFF3E0")
private let BorderStrokeColor = Color(hex: "#667685")
private let DocBorderColor = Color(hex: "#E0E0E0")
private let DocItemBg = Color(hex: "#FAFAFA")
private let PROFILE_DOCS_SERVER_URL = "https://doerapi.doer.nz"

struct ContractorDetailsScreen: View {
    var onBack: () -> Void
    var onViewDocument: (String, Bool) -> Void

    @State private var viewModel: ContractorDetailsViewModel

    init(contractorId: String, onBack: @escaping () -> Void, onViewDocument: @escaping (String, Bool) -> Void) {
        self.onBack = onBack
        self.onViewDocument = onViewDocument
        _viewModel = State(initialValue: ContractorDetailsViewModel(contractorId: contractorId))
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if let contractor = viewModel.contractor {
                ScrollView {
                    VStack(spacing: 20) {
                        DetailCard(emoji: "\u{1F464}", label: "Contractor Name", value: contractor.displayName)
                        DetailCard(emoji: "\u{1F4C5}", label: "Date of Birth", value: viewModel.formatDateOfBirth(contractor.dateOfBirth))
                        DetailCard(emoji: "\u{1F4E7}", label: "Email", value: contractor.email)
                        DetailCard(emoji: "\u{1F4F1}", label: "Phone Number", value: contractor.phoneNumber)
                        DetailCard(emoji: "\u{1F4BC}", label: "Work Experience", value: contractor.workExperience)
                        DetailCard(emoji: "\u{2B50}", label: "Skills", value: contractor.skills)
                        DocumentsSection(
                            documents: contractor.documents,
                            onViewDocument: onViewDocument,
                            isImageFile: viewModel.isImageFile
                        )

                        if viewModel.isCallerAdmin {
                            EmployeeToggleCard(
                                isEmployee: contractor.isEmployee,
                                onToggle: { viewModel.toggleEmployeeFlag($0) }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 30)
                }
                .background(BgColor)
            } else {
                Spacer()
                Text("Contractor not found")
                    .foregroundColor(.gray)
                    .font(.system(size: 16))
                Spacer()
            }
        }
        .navigationTitle("Contractor Detail")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .onAppear { viewModel.loadInitialData() }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                }
            }
        }
        .snackbar(message: Binding(get: { viewModel.errorMessage }, set: { viewModel.errorMessage = $0 }))
    }
}

// MARK: - Employee Toggle Card (Admin/Manager only)
private struct EmployeeToggleCard: View {
    let isEmployee: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("\u{1F465}")
                    .font(.system(size: 18))
                    .foregroundColor(BlueLabel)
                Text("Mark as Employee")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(BlueLabel)
                Spacer()
                Toggle(
                    "",
                    isOn: Binding(
                        get: { isEmployee },
                        set: { onToggle($0) }
                    )
                )
                .labelsHidden()
            }
            Text(isEmployee
                 ? "This contractor is currently an Employee."
                 : "Toggle on to grant this contractor Employee permissions.")
                .font(.system(size: 13))
                .foregroundColor(Gray500)
                .padding(.leading, 26)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(radius: 2)
    }
}

// MARK: - Detail Card
private struct DetailCard: View {
    let emoji: String
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(emoji)
                    .font(.system(size: 18))
                    .foregroundColor(BlueLabel)
                Text(label)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(BlueLabel)
            }
            Text(value.isEmpty ? "" : value)
                .font(.system(size: 16))
                .foregroundColor(Gray500)
                .padding(.leading, 26)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(radius: 2)
    }
}

// MARK: - Documents Section
private struct DocumentsSection: View {
    let documents: [FileModelDto]?
    let onViewDocument: (String, Bool) -> Void
    let isImageFile: (FileModelDto) -> Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("\u{1F4C4}")
                    .font(.system(size: 18))
                    .foregroundColor(BlueLabel)
                Text("Documents")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(BlueLabel)
            }

            if let docs = documents, !docs.isEmpty {
                VStack(spacing: 0) {
                    ForEach(docs, id: \.id) { doc in
                        HStack(spacing: 10) {
                            Text("\u{1F4CB}")
                                .font(.system(size: 16))
                                .foregroundColor(BlueLabel)
                            Text(doc.name)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(DocNameColor)
                                .underline()
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("\u{1F441}\u{FE0F}")
                                .font(.system(size: 16))
                                .foregroundColor(DocNameColor)
                        }
                        .padding(15)
                        .background(DocItemBg)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(DocBorderColor, lineWidth: 1)
                        )
                        .cornerRadius(10)
                        .padding(.vertical, 5)
                        .onTapGesture {
                            let fullUrl = PROFILE_DOCS_SERVER_URL + doc.fileUrl
                            onViewDocument(fullUrl, isImageFile(doc))
                        }
                    }
                }
                .padding(.leading, 26)
            } else {
                HStack(spacing: 10) {
                    Text("\u{1F4DD}")
                        .font(.system(size: 16))
                    Text("No Documents found.")
                        .font(.system(size: 16))
                        .foregroundColor(Gray500)
                }
                .padding(15)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(NoDocBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(BorderStrokeColor, lineWidth: 1)
                )
                .cornerRadius(10)
                .padding(.leading, 26)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(radius: 2)
    }
}
