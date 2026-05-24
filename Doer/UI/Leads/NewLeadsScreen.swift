import SwiftUI

private let headerBg = Color(hex: "#F3F4F6")
private let borderColor = Color.gray.opacity(0.5)
private let orangeAccent = Color(hex: "#FF9500")

// Column widths matching MAUI
private let colProjectDesc: CGFloat = 220
private let colOwner: CGFloat = 150
private let colStatus: CGFloat = 150
private let colCost: CGFloat = 150
private let colClient: CGFloat = 180
private let colLocation: CGFloat = 200
private let colContractType: CGFloat = 220
private let colCreatedDate: CGFloat = 150
private let colView: CGFloat = 180

struct NewLeadsScreen: View {
    let onOpenDrawer: () -> Void
    let onAddLead: () -> Void
    let onViewLead: (Int) -> Void

    @State private var viewModel = NewLeadsViewModel()
    @State private var showSnackbar = false
    @State private var snackbarMessage = ""
    // Observed so picker option lists and status labels refresh when admin renames dropdowns.
    @State private var boardConfigCache: BoardConfigCache = DIContainer.shared.boardConfigCache

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Content
                if viewModel.leads.isEmpty && !viewModel.isLoading {
                    Spacer()
                    Text("No new leads found")
                        .foregroundColor(.gray)
                        .font(.system(size: 16))
                    Spacer()
                } else {
                    // Table card with orange left stripe
                    HStack(spacing: 0) {
                        // Orange left stripe
                        Rectangle()
                            .fill(orangeAccent)
                            .frame(width: 5)

                        // Table content
                        ScrollView(.horizontal, showsIndicators: true) {
                            ScrollView(.vertical, showsIndicators: true) {
                                VStack(spacing: 0) {
                                    // Header
                                    HStack(spacing: 0) {
                                        SortableHeaderCell(title: "Project Description", width: colProjectDesc, column: "JobDescription", currentSortColumn: viewModel.sortColumn, sortAscending: viewModel.sortAscending) { viewModel.sortBy($0) }
                                        SortableHeaderCell(title: "Owner", width: colOwner, column: "OwnerName", currentSortColumn: viewModel.sortColumn, sortAscending: viewModel.sortAscending) { viewModel.sortBy($0) }
                                        SortableHeaderCell(title: "Status", width: colStatus, column: "StatusName", currentSortColumn: viewModel.sortColumn, sortAscending: viewModel.sortAscending) { viewModel.sortBy($0) }
                                        SortableHeaderCell(title: "Cost From Quote", width: colCost, column: "CostFromQuote", currentSortColumn: viewModel.sortColumn, sortAscending: viewModel.sortAscending) { viewModel.sortBy($0) }
                                        SortableHeaderCell(title: "Client", width: colClient, column: "ClientName", currentSortColumn: viewModel.sortColumn, sortAscending: viewModel.sortAscending) { viewModel.sortBy($0) }
                                        SortableHeaderCell(title: "Location", width: colLocation, column: "Location", currentSortColumn: viewModel.sortColumn, sortAscending: viewModel.sortAscending) { viewModel.sortBy($0) }
                                        SortableHeaderCell(title: "Contract Type", width: colContractType, column: "ContractTypeName", currentSortColumn: viewModel.sortColumn, sortAscending: viewModel.sortAscending) { viewModel.sortBy($0) }
                                        SortableHeaderCell(title: "Created Date", width: colCreatedDate, column: "CreatedDate", currentSortColumn: viewModel.sortColumn, sortAscending: viewModel.sortAscending) { viewModel.sortBy($0) }
                                        // Empty header for View column
                                        Text("")
                                            .frame(width: colView, height: 40)
                                            .overlay(Rectangle().stroke(Color.gray, lineWidth: 0.5))
                                    }
                                    .background(headerBg)

                                    // Data rows
                                    ForEach(viewModel.leads) { lead in
                                        HStack(spacing: 0) {
                                            EditableCellView(text: lead.jobDescription, width: colProjectDesc) {
                                                viewModel.startEdit(lead, .projectDescription)
                                            }
                                            EditableCellView(text: lead.ownerName, width: colOwner) {
                                                viewModel.startEdit(lead, .owner)
                                            }
                                            SolidColorCellView(text: viewModel.leadStatusName(lead.statusId, fallback: lead.statusName), width: colStatus, bgColor: viewModel.leadStatusColor(lead.statusId)) {
                                                viewModel.startEdit(lead, .status)
                                            }
                                            EditableCellView(text: lead.costFromQuote != nil ? "\(lead.costFromQuote!)" : "", width: colCost) {
                                                viewModel.startEdit(lead, .cost)
                                            }
                                            EditableCellView(text: lead.clientName, width: colClient) {
                                                viewModel.startEdit(lead, .client)
                                            }
                                            EditableCellView(text: lead.location, width: colLocation) {
                                                viewModel.startEdit(lead, .location)
                                            }
                                            SolidColorCellView(text: viewModel.contractTypeName(lead.contractType, fallback: lead.contractTypeName), width: colContractType, bgColor: viewModel.contractTypeColorDynamic(lead.contractType)) {
                                                viewModel.startEdit(lead, .contractType)
                                            }
                                            DataCellView(text: viewModel.formatDate(lead.createdDate), width: colCreatedDate)
                                            // View button
                                            ZStack {
                                                Rectangle().stroke(borderColor, lineWidth: 0.5)
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
                                            }
                                            .frame(width: colView, height: 50)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.leading, 5)
                    }
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)

                    // Bottom "Add Lead" button
                    Button(action: onAddLead) {
                        Text("Add Lead")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(width: 150, height: 40)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(10)
                }
            }
            .loadingOverlay(viewModel.isLoading)
            .navigationTitle("New Leads")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .onAppear { viewModel.refresh() }
            .onChange(of: boardConfigCache.version) { _, _ in
                // Cache changed (admin renamed dropdowns) — re-render picks up new
                // labels via viewModel.dynamicLeadStatuses/dynamicContractTypes/etc.
                viewModel.refresh()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: onOpenDrawer) {
                        Image(systemName: "line.3.horizontal")
                    }
                }
            }

            // Updating overlay
            if viewModel.isUpdating {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
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
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            showSnackbar = false
                        }
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
                    statuses: viewModel.dynamicLeadStatuses,
                    onSelect: { viewModel.selectLeadStatus($0) },
                    onDismiss: { viewModel.cancelEdit() },
                    colorProvider: { viewModel.leadStatusColor($0) }
                )
            case .contractType:
                ContractTypeBottomSheetView(
                    contractTypes: viewModel.dynamicContractTypes,
                    onSelect: { viewModel.selectContractType($0) },
                    onDismiss: { viewModel.cancelEdit() },
                    colorProvider: { viewModel.contractTypeColorDynamic($0) }
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

// MARK: - Shared Table Cell Components

struct SortableHeaderCell: View {
    let title: String
    let width: CGFloat
    let column: String
    let currentSortColumn: String
    let sortAscending: Bool
    let onSort: (String) -> Void

    var body: some View {
        Button(action: { onSort(column) }) {
            HStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.black)
                    .lineLimit(1)
                Spacer()
                if currentSortColumn == column {
                    Text(sortAscending ? "\u{25B2}" : "\u{25BC}")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.black)
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(width: width, height: 40)
        .clipped()
        .contentShape(Rectangle())
        .overlay(Rectangle().stroke(Color.gray, lineWidth: 0.5))
    }
}

struct DataCellView: View {
    let text: String
    let width: CGFloat

    var body: some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundColor(Color(hex: "#374151"))
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .frame(width: width, height: 50)
            .clipped()
            .overlay(Rectangle().stroke(Color.gray.opacity(0.5), lineWidth: 0.5))
    }
}

struct EditableCellView: View {
    let text: String
    let width: CGFloat
    let onClick: () -> Void

    var body: some View {
        Button(action: onClick) {
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#374151"))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
        }
        .frame(width: width, height: 50)
        .clipped()
        .overlay(Rectangle().stroke(Color.gray.opacity(0.5), lineWidth: 0.5))
    }
}

struct SolidColorCellView: View {
    let text: String
    let width: CGFloat
    let bgColor: Color
    let onClick: () -> Void

    var body: some View {
        Button(action: onClick) {
            Text(text)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
        }
        .frame(width: width, height: 50)
        .background(bgColor)
        .clipped()
        .overlay(Rectangle().stroke(Color.gray.opacity(0.5), lineWidth: 0.5))
    }
}

// MARK: - Bottom Sheet Dialogs

struct EditorBottomSheetView: View {
    let title: String
    @Binding var value: String
    let isCost: Bool
    let onSave: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            HStack {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 20))
                        .foregroundColor(.black)
                        .frame(width: 30, height: 30)
                }
                Spacer()
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Button(action: onSave) {
                    Text("Save")
                        .foregroundColor(.white)
                        .font(.system(size: 14))
                }
                .frame(width: 100, height: 40)
                .background(Color(hex: "#007AFF"))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .padding(16)

            // Divider
            Rectangle()
                .fill(Color(hex: "#667685"))
                .frame(height: 1)

            // Editor
            if isCost {
                HStack {
                    Text("$")
                    TextField("Enter Value...", text: $value)
                        .keyboardType(.decimalPad)
                }
                .padding()
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray))
                .padding(16)
            } else {
                TextEditor(text: $value)
                    .frame(height: 150)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray))
                    .padding(16)
            }

            Spacer()
        }
        .presentationDetents([.large])
    }
}

struct StatusBottomSheetView: View {
    let statuses: [(Int, String)]
    let onSelect: (Int) -> Void
    let onDismiss: () -> Void
    var colorProvider: (Int) -> Color = { NewLeadsViewModel.getLeadStatusColor($0) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 20))
                        .foregroundColor(.black)
                        .frame(width: 30, height: 30)
                }
                Text("Status")
                    .font(.system(size: 18, weight: .bold))
            }
            .padding(16)

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(statuses, id: \.0) { id, name in
                        Button(action: { onSelect(id) }) {
                            Text(name)
                                .foregroundColor(.white)
                                .font(.system(size: 14, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(10)
                        }
                        .background(colorProvider(id))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 16)
            }

            Spacer()
        }
        .presentationDetents([.large])
    }
}

struct ContractTypeBottomSheetView: View {
    let contractTypes: [(Int, String)]
    let onSelect: (Int) -> Void
    let onDismiss: () -> Void
    var colorProvider: (Int) -> Color = { NewLeadsViewModel.getContractTypeColor($0) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 20))
                        .foregroundColor(.black)
                        .frame(width: 30, height: 30)
                }
                Text("Contract Type")
                    .font(.system(size: 18, weight: .bold))
            }
            .padding(16)

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(contractTypes, id: \.0) { id, name in
                        Button(action: { onSelect(id) }) {
                            Text(name)
                                .foregroundColor(.white)
                                .font(.system(size: 14, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(10)
                        }
                        .background(colorProvider(id))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 16)
            }

            Spacer()
        }
        .presentationDetents([.large])
    }
}

struct ClientBottomSheetView: View {
    let clients: [ClientDto]
    let onSelect: (ClientDto) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 20))
                        .foregroundColor(.black)
                        .frame(width: 30, height: 30)
                }
                Text("Client")
                    .font(.system(size: 18, weight: .bold))
            }
            .padding(16)

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(clients) { client in
                        Button(action: { onSelect(client) }) {
                            Text(client.name)
                                .foregroundColor(Color(hex: "#007AFF"))
                                .font(.system(size: 14, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(10)
                        }
                        .background(Color.white)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.5), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 16)
            }

            Spacer()
        }
        .presentationDetents([.large])
    }
}

struct OwnerBottomSheetView: View {
    let owners: [UserDto]
    let onSelect: (UserDto) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 20))
                        .foregroundColor(.black)
                        .frame(width: 30, height: 30)
                }
                Text("Owner")
                    .font(.system(size: 18, weight: .bold))
            }
            .padding(16)

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(owners, id: \.id) { owner in
                        Button(action: { onSelect(owner) }) {
                            Text(owner.displayName)
                                .foregroundColor(Color(hex: "#007AFF"))
                                .font(.system(size: 14, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(10)
                        }
                        .background(Color.white)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.5), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 16)
            }

            Spacer()
        }
        .presentationDetents([.large])
    }
}

struct LocationBottomSheetView: View {
    @Binding var searchAddress: String
    let placeList: [PlacePrediction]
    let showPlaceList: Bool
    let onSearchChange: (String) -> Void
    let onClearSearch: () -> Void
    let onSelectPlace: (PlacePrediction) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 20))
                        .foregroundColor(.black)
                        .frame(width: 30, height: 30)
                }
                Text("Location")
                    .font(.system(size: 18, weight: .bold))
            }
            .padding(16)

            // Location label
            HStack {
                Text("\u{1F4CD}")
                    .font(.system(size: 16))
                Text("Location:")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(hex: "#007AFF"))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            // Search field with clear button
            HStack {
                TextField("Enter Address", text: Binding(
                    get: { searchAddress },
                    set: { onSearchChange($0) }
                ))
                if !searchAddress.isEmpty {
                    Button(action: onClearSearch) {
                        Text("X")
                            .foregroundColor(.black)
                            .font(.system(size: 16))
                    }
                }
            }
            .padding()
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray))
            .padding(.horizontal, 16)

            if !showPlaceList && searchAddress.trimmingCharacters(in: .whitespaces).isEmpty {
                VStack {
                    Text("\u{1F4DD}")
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: "#9CA3AF"))
                    Text("Start typing to search")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#6B7280"))
                }
                .frame(maxWidth: .infinity)
                .padding(20)
            }

            // Place suggestions
            if showPlaceList {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(placeList, id: \.placeId) { prediction in
                            Button(action: { onSelectPlace(prediction) }) {
                                Text(prediction.description)
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(hex: "#007AFF"))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(10)
                            }
                            .background(Color.white)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(hex: "#E0E0E0"), lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                    .padding(10)
                    .background(Color(hex: "#F8F9FA"))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }

            Spacer()
        }
        .presentationDetents([.large])
    }
}
