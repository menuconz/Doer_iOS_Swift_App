import SwiftUI

private let headerBg = Color(hex: "#F3F4F6")
private let borderColor = Color.gray.opacity(0.5)

// Section accent colors matching MAUI
private let blueAccent = Color(hex: "#0285C4")    // Quote Not Yet Accepted
private let greenAccent = Color(hex: "#00C874")   // Closed Deal
private let grayAccent = Color(hex: "#808080")    // Quote Expired
private let purpleAccent = Color(hex: "#800080")  // Drafted

// Column widths matching MAUI QualifiedLeads.xaml
private let colProjectDesc: CGFloat = 220
private let colOwner: CGFloat = 150
private let colStatus: CGFloat = 150
private let colCost: CGFloat = 150
private let colClient: CGFloat = 180
private let colLocation: CGFloat = 220
private let colContractType: CGFloat = 180
private let colCreatedDate: CGFloat = 150
private let colActions: CGFloat = 220

struct QuotedLeadsScreen: View {
    let onOpenDrawer: () -> Void
    let onViewLead: (Int) -> Void

    @State private var viewModel = QuotedLeadsViewModel()
    @State private var showSnackbar = false
    @State private var snackbarMessage = ""

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(spacing: 10) {
                            // Quote Not Yet Accepted section
                            QuotedSectionView(
                                title: "Quote Not Yet Accepted",
                                accentColor: blueAccent,
                                sectionState: viewModel.quoteNotAccepted,
                                onToggle: { viewModel.toggleSection(.quoteNotAccepted) },
                                onSort: { viewModel.sortSection(.quoteNotAccepted, $0) },
                                onViewLead: onViewLead,
                                onEditLead: { lead, field in viewModel.startEdit(lead, field) },
                                viewModel: viewModel,
                                showFollowUp: true,
                                onFollowUp: { viewModel.sendFollowUp($0) }
                            )

                            // Closed Deal section
                            QuotedSectionView(
                                title: "Closed Deal",
                                accentColor: greenAccent,
                                sectionState: viewModel.closedDeal,
                                onToggle: { viewModel.toggleSection(.closedDeal) },
                                onSort: { viewModel.sortSection(.closedDeal, $0) },
                                onViewLead: onViewLead,
                                onEditLead: { lead, field in viewModel.startEdit(lead, field) },
                                viewModel: viewModel,
                                showFollowUp: false
                            )

                            // Quote Expired section
                            QuotedSectionView(
                                title: "Quote Expired",
                                accentColor: grayAccent,
                                sectionState: viewModel.quoteExpired,
                                onToggle: { viewModel.toggleSection(.quoteExpired) },
                                onSort: { viewModel.sortSection(.quoteExpired, $0) },
                                onViewLead: onViewLead,
                                onEditLead: { lead, field in viewModel.startEdit(lead, field) },
                                viewModel: viewModel,
                                showFollowUp: false
                            )

                            // Drafted section
                            QuotedSectionView(
                                title: "Drafted",
                                accentColor: purpleAccent,
                                sectionState: viewModel.drafted,
                                onToggle: { viewModel.toggleSection(.drafted) },
                                onSort: { viewModel.sortSection(.drafted, $0) },
                                onViewLead: onViewLead,
                                onEditLead: { lead, field in viewModel.startEdit(lead, field) },
                                viewModel: viewModel,
                                showFollowUp: false
                            )

                            Spacer().frame(height: 32)
                        }
                    }
            }
            .loadingOverlay(viewModel.isLoading)
            .navigationTitle("Qualified Leads")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .onAppear { viewModel.loadInitialData() }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: onOpenDrawer) {
                        Image(systemName: "line.3.horizontal")
                    }
                }
            }

            if viewModel.isUpdating {
                Color.black.opacity(0.2).ignoresSafeArea()
                ProgressView()
            }
        }
        .onChange(of: viewModel.errorMessage) { _, msg in
            if let msg = msg {
                snackbarMessage = msg
                showSnackbar = true
                viewModel.clearError()
            }
        }
        .onChange(of: viewModel.successMessage) { _, msg in
            if let msg = msg {
                snackbarMessage = msg
                showSnackbar = true
                viewModel.clearSuccess()
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
        .sheet(isPresented: Binding(
            get: { viewModel.editingLead != nil && viewModel.editField != nil },
            set: { if !$0 { viewModel.cancelEdit() } }
        )) {
            editSheet
        }
    }

    @ViewBuilder
    private var editSheet: some View {
        if let field = viewModel.editField {
            switch field {
            case .projectDescription, .cost:
                EditorBottomSheetView(
                    title: field == .projectDescription ? "Project Description" : "Cost From Quote",
                    value: $viewModel.editValue,
                    isCost: field == .cost,
                    onSave: { viewModel.saveEditorField() },
                    onDismiss: { viewModel.cancelEdit() }
                )
            case .status:
                StatusBottomSheetView(
                    statuses: QuotedLeadsViewModel.quotedLeadStatuses,
                    onSelect: { viewModel.selectLeadStatus($0) },
                    onDismiss: { viewModel.cancelEdit() }
                )
            case .contractType:
                ContractTypeBottomSheetView(
                    onSelect: { viewModel.selectContractType($0) },
                    onDismiss: { viewModel.cancelEdit() }
                )
            case .client:
                ClientBottomSheetView(
                    clients: viewModel.clients,
                    onSelect: { viewModel.selectClient($0) },
                    onDismiss: { viewModel.cancelEdit() }
                )
            case .owner:
                OwnerBottomSheetView(
                    owners: viewModel.owners,
                    onSelect: { viewModel.selectOwner($0) },
                    onDismiss: { viewModel.cancelEdit() }
                )
            case .location:
                LocationBottomSheetView(
                    searchAddress: $viewModel.searchAddress,
                    placeList: viewModel.placeList,
                    showPlaceList: viewModel.showPlaceList,
                    onSearchChange: { viewModel.onSearchAddressChange($0) },
                    onClearSearch: { viewModel.clearSearchAddress() },
                    onSelectPlace: { viewModel.selectPlace($0) },
                    onDismiss: { viewModel.cancelEdit() }
                )
            }
        }
    }
}

// MARK: - Section View

private struct QuotedSectionView: View {
    let title: String
    let accentColor: Color
    let sectionState: SectionState
    let onToggle: () -> Void
    let onSort: (String) -> Void
    let onViewLead: (Int) -> Void
    let onEditLead: (LeadsDto, EditField) -> Void
    let viewModel: QuotedLeadsViewModel
    let showFollowUp: Bool
    var onFollowUp: ((Int) -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Section header with toggle
            Button(action: onToggle) {
                HStack {
                    Text(sectionState.isExpanded ? "\u{25BC}" : "\u{25B6}")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(accentColor)
                    Text(" \(title)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(accentColor)
                    Spacer()
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 10)
            }

            if sectionState.isExpanded {
                if sectionState.leads.isEmpty {
                    Text("No leads in this section")
                        .foregroundColor(.gray)
                        .font(.system(size: 14))
                        .padding(16)
                } else {
                    // Card with accent stripe
                    HStack(spacing: 0) {
                        // Left accent stripe
                        Rectangle()
                            .fill(accentColor)
                            .frame(width: 5)

                        ScrollView(.horizontal, showsIndicators: true) {
                            VStack(spacing: 0) {
                                // Header
                                HStack(spacing: 0) {
                                    SortableHeaderCell(title: "Project Description", width: colProjectDesc, column: "JobDescription", currentSortColumn: sectionState.sortColumn, sortAscending: sectionState.sortAscending, onSort: onSort)
                                    SortableHeaderCell(title: "Owner", width: colOwner, column: "OwnerName", currentSortColumn: sectionState.sortColumn, sortAscending: sectionState.sortAscending, onSort: onSort)
                                    SortableHeaderCell(title: "Status", width: colStatus, column: "StatusName", currentSortColumn: sectionState.sortColumn, sortAscending: sectionState.sortAscending, onSort: onSort)
                                    SortableHeaderCell(title: "Cost From Quote", width: colCost, column: "CostFromQuote", currentSortColumn: sectionState.sortColumn, sortAscending: sectionState.sortAscending, onSort: onSort)
                                    SortableHeaderCell(title: "Client", width: colClient, column: "ClientName", currentSortColumn: sectionState.sortColumn, sortAscending: sectionState.sortAscending, onSort: onSort)
                                    SortableHeaderCell(title: "Location", width: colLocation, column: "Location", currentSortColumn: sectionState.sortColumn, sortAscending: sectionState.sortAscending, onSort: onSort)
                                    SortableHeaderCell(title: "Contract Type", width: colContractType, column: "ContractTypeName", currentSortColumn: sectionState.sortColumn, sortAscending: sectionState.sortAscending, onSort: onSort)
                                    SortableHeaderCell(title: "Created Date", width: colCreatedDate, column: "CreatedDate", currentSortColumn: sectionState.sortColumn, sortAscending: sectionState.sortAscending, onSort: onSort)
                                    // Actions header
                                    Text("")
                                        .frame(width: colActions, height: 40)
                                        .overlay(Rectangle().stroke(Color.gray, lineWidth: 0.5))
                                }
                                .background(Color(hex: "#F3F4F6"))

                                // Data rows
                                ForEach(sectionState.leads) { lead in
                                    HStack(spacing: 0) {
                                        EditableCellView(text: lead.jobDescription, width: colProjectDesc) {
                                            onEditLead(lead, .projectDescription)
                                        }
                                        EditableCellView(text: lead.ownerName, width: colOwner) {
                                            onEditLead(lead, .owner)
                                        }
                                        SolidColorCellView(text: lead.statusName, width: colStatus, bgColor: NewLeadsViewModel.getLeadStatusColor(lead.statusId)) {
                                            onEditLead(lead, .status)
                                        }
                                        EditableCellView(text: lead.costFromQuote != nil ? "\(lead.costFromQuote!)" : "", width: colCost) {
                                            onEditLead(lead, .cost)
                                        }
                                        EditableCellView(text: lead.clientName, width: colClient) {
                                            onEditLead(lead, .client)
                                        }
                                        EditableCellView(text: lead.location, width: colLocation) {
                                            onEditLead(lead, .location)
                                        }
                                        SolidColorCellView(text: lead.contractTypeName, width: colContractType, bgColor: NewLeadsViewModel.getContractTypeColor(lead.contractType)) {
                                            onEditLead(lead, .contractType)
                                        }
                                        DataCellView(text: viewModel.formatDate(lead.createdDate), width: colCreatedDate)

                                        // View + Follow-up buttons
                                        ZStack {
                                            Rectangle().stroke(borderColor, lineWidth: 0.5)
                                            HStack(spacing: 5) {
                                                Button(action: { onViewLead(lead.id) }) {
                                                    Text("View")
                                                        .font(.system(size: 13, weight: .bold))
                                                        .foregroundColor(.white)
                                                        .padding(.horizontal, 16)
                                                        .padding(.vertical, 6)
                                                        .background(Color(hex: "007AFF"))
                                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                                }
                                                .buttonStyle(.plain)

                                                if showFollowUp {
                                                    Button(action: { onFollowUp?(lead.id) }) {
                                                        Text("Follow up quote")
                                                            .font(.system(size: 12, weight: .bold))
                                                            .foregroundColor(.white)
                                                    }
                                                    .frame(height: 35)
                                                    .padding(.horizontal, 10)
                                                    .background(Color(hex: "#0285C4"))
                                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black, lineWidth: 1))
                                                }
                                            }
                                        }
                                        .frame(width: colActions, height: 50)
                                    }
                                }
                            }
                        }
                        .padding(.leading, 5)
                    }
                    .background(Color.white)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                }
            }
        }
    }
}
