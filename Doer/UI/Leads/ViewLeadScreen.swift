import SwiftUI

private let bgColor = Color(hex: "#F8F9FA")
private let blueLabel = Color(hex: "#4D4BA3")
private let borderStrokeColor = Color(hex: "#667685")
private let locationBg = Color(hex: "#E0DEDE")

struct ViewLeadScreen: View {
    let onBack: () -> Void
    let leadId: Int

    @State private var viewModel: ViewLeadViewModel
    @State private var showSnackbar = false
    @State private var snackbarMessage = ""
    @State private var boardConfigCache: BoardConfigCache = DIContainer.shared.boardConfigCache

    init(leadId: Int, onBack: @escaping () -> Void) {
        self.leadId = leadId
        self.onBack = onBack
        _viewModel = State(initialValue: ViewLeadViewModel(leadId: leadId))
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if viewModel.lead == nil {
                Spacer()
                Text(viewModel.errorMessage ?? "Lead not found")
                    .foregroundColor(.gray)
                    .font(.system(size: 16))
                Spacer()
            } else {
                let lead = viewModel.lead!

                ScrollView {
                    VStack(alignment: .leading, spacing: 15) {
                        // Name Section
                        ViewLeadFieldLabel(emoji: "\u{1F4DD}", label: "Name:")
                        ReadOnlyEntryField(text: lead.name, placeholder: "Enter Project Name", height: 55)

                        // Job Description Section
                        ViewLeadFieldLabel(emoji: "\u{1F4DD}", label: "Job Description:")
                        ReadOnlyEntryField(text: lead.jobDescription, placeholder: "Enter the Job Description", height: 120)

                        // Owner Section
                        ViewLeadPickerField(label: "Owner", value: lead.ownerName.isEmpty ? "Select Owner" : lead.ownerName)

                        // Contract Type Section
                        ViewLeadPickerField(label: "Contract Type", value: viewModel.contractTypeName(lead.contractType, fallback: viewLeadContractTypeDisplayName(lead.contractType)))

                        // Location Section
                        ViewLeadFieldLabel(emoji: "\u{1F4CD}", label: "Location:")
                        ReadOnlyEntryField(text: lead.location, placeholder: "Enter Address", height: 55, backgroundColor: locationBg, textAlpha: 0.7)

                        // Cost From Quote Section
                        ViewLeadFieldLabel(emoji: "\u{1F4B5}", label: "Cost From Quote ($):")
                        ReadOnlyEntryField(text: lead.costFromQuote != nil ? "\(lead.costFromQuote!)" : "", placeholder: "Enter Quote Amount", height: 55)

                        // Client Name Section
                        ViewLeadFieldLabel(emoji: "\u{1F464}", label: "Client Name:")
                        ReadOnlyEntryField(text: lead.clientName, placeholder: "Enter Client Name", height: 55)

                        // Client Email Section
                        ViewLeadFieldLabel(emoji: "\u{1F4E7}", label: "Client Email:")
                        ReadOnlyEntryField(text: lead.clientEmail, placeholder: "Enter Client Email", height: 55)

                        // Status Section
                        ViewLeadFieldLabel(emoji: "\u{1F4CA}", label: "Status:")
                        ViewLeadStatusFrame(statusName: viewModel.leadStatusName(lead.statusId, fallback: lead.statusName), statusColor: viewModel.leadStatusColor(lead.statusId))

                        // NOTE: Action buttons are commented out in MAUI ViewLead.xaml
                    }
                    .padding(20)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .background(bgColor)
        .navigationTitle("Lead Detail")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .onAppear { viewModel.loadInitialData() }
        .onChange(of: boardConfigCache.version) { _, _ in
            // Re-render to pick up admin-renamed dropdown labels.
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                }
            }
        }
        .onChange(of: viewModel.toastMessage) { _, msg in
            if let msg = msg {
                snackbarMessage = msg
                showSnackbar = true
                viewModel.toastMessage = nil
            }
        }
        .onChange(of: viewModel.shouldNavigateBack) { _, shouldGoBack in
            if shouldGoBack {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    onBack()
                }
            }
        }
        .overlay(alignment: .bottom) {
            if showSnackbar {
                Text(snackbarMessage)
                    .padding()
                    .background(Color.black.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(.bottom, 20)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { showSnackbar = false }
                    }
            }
        }
    }
}

// MARK: - View Lead Components

private struct ViewLeadFieldLabel: View {
    let emoji: String
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            Text(emoji)
                .font(.system(size: 16))
            Text(label)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(blueLabel)
        }
    }
}

private struct ReadOnlyEntryField: View {
    let text: String
    let placeholder: String
    let height: CGFloat
    var backgroundColor: Color = .white
    var textAlpha: Double = 1.0

    var body: some View {
        ZStack(alignment: height > 60 ? .topLeading : .leading) {
            let displayText = text.isEmpty ? placeholder : text
            let textColor: Color = text.isEmpty ? .gray : .black
            Text(displayText)
                .font(.system(size: 16))
                .foregroundColor(textColor)
                .opacity(text.isEmpty ? 0.5 : textAlpha)
                .padding(.horizontal, 15)
                .padding(.vertical, height > 60 ? 10 : 0)
        }
        .frame(maxWidth: .infinity, minHeight: height, alignment: height > 60 ? .topLeading : .leading)
        .background(backgroundColor)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(borderStrokeColor, lineWidth: 2))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 2)
    }
}

private struct ViewLeadPickerField: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label.uppercased())
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(blueLabel)
                .padding(.top, 10)
            Spacer()
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(blueLabel)
                .multilineTextAlignment(.trailing)
        }
        .padding(5)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .shadow(radius: 2)
    }
}

private struct ViewLeadStatusFrame: View {
    let statusName: String
    let statusColor: Color

    var body: some View {
        Text(statusName)
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(statusColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(radius: 2)
    }
}

private func viewLeadContractTypeDisplayName(_ contractType: Int?) -> String {
    switch contractType {
    case 1: return "ToBeConfirmed"
    case 2: return "FullContract"
    case 3: return "SupplyPlaceAndFinish"
    case 4: return "PlaceAndFinish"
    case 5: return "LabourSupply"
    case 6: return "BoxPlaceAndFinish"
    case 7: return "Remedial"
    case 8: return "SupplyPlaceFinishAndCut"
    case 9: return "PlaceFinishAndCut"
    case 10: return "OtherServices"
    case 11: return "Meetings"
    default: return "Select Contract Type"
    }
}
