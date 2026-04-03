import SwiftUI
import MapKit

struct DayDetailScreen: View {
    @Binding var path: NavigationPath
    let date: String
    @State private var viewModel: DayDetailViewModel

    var shiftId: Int? = nil

    init(path: Binding<NavigationPath>, date: String, shiftId: Int? = nil) {
        self._path = path
        self.date = date
        self.shiftId = shiftId
        self._viewModel = State(initialValue: DayDetailViewModel(date: date, shiftId: shiftId))
    }

    var body: some View {
        mainContent
            .loadingOverlay(viewModel.isLoading)
            .navigationTitle(viewModel.pageTitle)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { viewModel.refreshData() }
            .alert("Delete Sub-Item", isPresented: Binding(
                get: { viewModel.activeDialog == .deleteSubItem },
                set: { if !$0 { viewModel.dismissDialog() } }
            )) {
                Button("Delete", role: .destructive) { viewModel.deleteSubItem() }
                Button("Cancel", role: .cancel) { viewModel.dismissDialog() }
            } message: {
                Text("Are you sure you want to delete '\(viewModel.deleteSubItemName)'?")
            }
            .sheet(isPresented: sheetBinding(.editor)) {
                EditorDialogView(
                    title: viewModel.editorTitle,
                    text: $viewModel.editorText,
                    onSave: { viewModel.saveEditorText(viewModel.editorText) },
                    onDismiss: { viewModel.dismissDialog() }
                )
            }
            .sheet(isPresented: sheetBinding(.dateTime)) {
                DateTimeDialogView(
                    date: $viewModel.editDate,
                    time: $viewModel.editTime,
                    onSave: { viewModel.saveDateTime(viewModel.editDate, viewModel.editTime) },
                    onDismiss: { viewModel.dismissDialog() }
                )
            }
            .sheet(isPresented: sheetBinding(.addressSearch)) {
                AddressSearchDialogView(
                    searchText: Binding(
                        get: { viewModel.addressSearchText },
                        set: { viewModel.onAddressSearchChange($0) }
                    ),
                    suggestions: viewModel.placeSuggestions,
                    onPlaceSelected: { viewModel.onPlaceSelected($0) },
                    onDismiss: { viewModel.dismissDialog() }
                )
            }
            .overlay { optionSheets }
            .alert("Error", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
    }

    @ViewBuilder
    private var optionSheets: some View {
        Color.clear
            .sheet(isPresented: sheetBinding(.contractType)) {
                OptionListDialogView(
                    title: "Select Contract Type",
                    items: viewModel.contractTypes.map { ($0.id, $0.name, $0.color) },
                    onSelect: { id in
                        if let item = viewModel.contractTypes.first(where: { $0.id == id }) {
                            viewModel.selectContractType(item)
                        }
                    },
                    onDismiss: { viewModel.dismissDialog() }
                )
            }
            .sheet(isPresented: sheetBinding(.clientSelect)) {
                OptionListDialogView(
                    title: "Select Client",
                    items: viewModel.clients.map { ($0.id, $0.name, Color(hex: "007AFF")) },
                    onSelect: { id in
                        if let client = viewModel.clients.first(where: { $0.id == id }) {
                            viewModel.selectClient(client)
                        }
                    },
                    onDismiss: { viewModel.dismissDialog() }
                )
            }
            .sheet(isPresented: sheetBinding(.invoiceStatus)) {
                OptionListDialogView(
                    title: "Select Invoice Status",
                    items: viewModel.invoiceStatuses.map { ($0.id, $0.name, $0.color) },
                    onSelect: { id in
                        if let item = viewModel.invoiceStatuses.first(where: { $0.id == id }) {
                            viewModel.selectInvoiceStatus(item)
                        }
                    },
                    onDismiss: { viewModel.dismissDialog() }
                )
            }
            .sheet(isPresented: sheetBinding(.hsFormStatus)) {
                OptionListDialogView(
                    title: "Select H&S Form Status",
                    items: viewModel.hsFormStatuses.map { ($0.id, $0.name, $0.color) },
                    onSelect: { id in
                        if let item = viewModel.hsFormStatuses.first(where: { $0.id == id }) {
                            viewModel.selectHSFormStatus(item)
                        }
                    },
                    onDismiss: { viewModel.dismissDialog() }
                )
            }
            .sheet(isPresented: sheetBinding(.subItemHS)) {
                OptionListDialogView(
                    title: "Select H&S Required",
                    items: viewModel.subItemHsOptions.map { ($0.id, $0.name, $0.color) },
                    onSelect: { id in
                        if let item = viewModel.subItemHsOptions.first(where: { $0.id == id }) {
                            viewModel.selectSubItemHS(item)
                        }
                    },
                    onDismiss: { viewModel.dismissDialog() }
                )
            }
            .sheet(isPresented: sheetBinding(.subItemStatus)) {
                OptionListDialogView(
                    title: "Select Sub-Item Status",
                    items: viewModel.subItemStatusOptions.map { ($0.id, $0.name, $0.color) },
                    onSelect: { id in
                        if let item = viewModel.subItemStatusOptions.first(where: { $0.id == id }) {
                            viewModel.selectSubItemStatus(item)
                        }
                    },
                    onDismiss: { viewModel.dismissDialog() }
                )
            }
            .sheet(isPresented: sheetBinding(.subItemDate)) {
                DateTimeDialogView(
                    date: $viewModel.editDate,
                    time: $viewModel.editTime,
                    onSave: { viewModel.saveSubItemDate(viewModel.editDate, viewModel.editTime) },
                    onDismiss: { viewModel.dismissDialog() }
                )
            }
    }

    private func sheetBinding(_ dialog: DayDetailDialog) -> Binding<Bool> {
        Binding(
            get: { viewModel.activeDialog == dialog },
            set: { if !$0 { viewModel.dismissDialog() } }
        )
    }

    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 0) {
            VStack(spacing: 5) {
                Text(viewModel.selectedDateString)
                    .font(.system(size: 24))
                    .fontWeight(.bold)
                    .foregroundColor(Color(hex: "333333"))
                    .multilineTextAlignment(.center)

                Text(viewModel.projectCountText)
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "666666"))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(15)
            .background(Color(hex: "F8F9FA"))

            FilterSectionView(viewModel: viewModel)

            if viewModel.isLoading {
                Spacer()
            }

            if viewModel.shiftRows.isEmpty && !viewModel.isLoading {
                Spacer()
                Text("No projects for this day")
                    .foregroundColor(.gray)
                    .font(.system(size: 16))
                Spacer()
            } else if !viewModel.shiftRows.isEmpty {
                ScrollView(.horizontal, showsIndicators: true) {
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 0) {
                            DataGridHeaderRow(
                                isOwner: viewModel.isOwner,
                                onSort: viewModel.sortBy,
                                getSortIcon: viewModel.getSortIcon
                            )
                            ForEach(viewModel.shiftRows) { row in
                                DataGridShiftRow(
                                    row: row,
                                    isOwner: viewModel.isOwner,
                                    isCaregiver: viewModel.isCaregiver,
                                    viewModel: viewModel,
                                    path: $path
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 15)
            }
        }
    }
}

// MARK: - Column Widths
private enum ColW {
    static let expand: CGFloat = 40
    static let projectName: CGFloat = 180
    static let clientName: CGFloat = 180
    static let address: CGFloat = 225
    static let durationFrom: CGFloat = 180
    static let durationTo: CGFloat = 180
    static let contractType: CGFloat = 180
    static let invoiceStatus: CGFloat = 180
    static let hsForm: CGFloat = 180
    static let finalMeasure: CGFloat = 180
    static let jobDescription: CGFloat = 200
    static let quote: CGFloat = 180
    static let contractorQuote: CGFloat = 180
    static let status: CGFloat = 180
    static let files: CGFloat = 100
    static let actions: CGFloat = 225
    static let subItem: CGFloat = 200
    static let subHs: CGFloat = 140
    static let subStatus: CGFloat = 120
    static let subDateStarted: CGFloat = 140
    static let subDateCompleted: CGFloat = 140
    static let subFiles: CGFloat = 80
    static let subDelete: CGFloat = 80
}

// MARK: - Filter Section
private struct FilterSectionView: View {
    let viewModel: DayDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("Advanced Filters")
                        .font(.system(size: 16))
                        .fontWeight(.bold)
                        .foregroundColor(Color(hex: "333333"))
                    Spacer()
                    Text(viewModel.filterStatusText)
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "666666"))
                }

                HStack {
                    Spacer()
                    if viewModel.pendingFilters.contains(where: { $0.isComplete }) {
                        Button("Apply Filters") { viewModel.applyFilters() }
                            .font(.system(size: 13)).fontWeight(.bold)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Color(hex: "34C759"))
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .padding(.trailing, 10)
                    }
                    if !viewModel.activeFilters.isEmpty {
                        Button("Clear All") { viewModel.clearAllFilters() }
                            .font(.system(size: 13)).fontWeight(.bold)
                            .foregroundColor(Color(hex: "FF3B30"))
                    }
                    Button("+ Add Filter") { viewModel.addFilter() }
                        .font(.system(size: 13)).fontWeight(.bold)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color(hex: "007AFF"))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                ForEach(viewModel.pendingFilters, id: \.id) { filter in
                    PendingFilterRowView(filter: filter, columns: viewModel.filterColumns, viewModel: viewModel)
                }

                if !viewModel.activeFilters.isEmpty {
                    Text("Currently Applied Filters:")
                        .font(.system(size: 12)).fontWeight(.bold)
                        .foregroundColor(Color(hex: "28A745"))
                    ForEach(viewModel.activeFilters, id: \.id) { filter in
                        ActiveFilterChipView(filter: filter, onRemove: { viewModel.removeFilter(filter.id) })
                    }
                }

                if viewModel.pendingFilters.isEmpty && viewModel.activeFilters.isEmpty {
                    Text("No filters applied - showing all projects")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "9CA3AF"))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(hex: "F8F9FA"))

            Divider()
        }
    }
}

private struct PendingFilterRowView: View {
    let filter: FilterRow
    let columns: [FilterColumnOption]
    let viewModel: DayDetailViewModel

    var body: some View {
        HStack(spacing: 8) {
            Text("Where")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "333333"))

            Menu {
                ForEach(columns) { col in
                    Button(col.displayName) {
                        viewModel.updatePendingFilterColumn(filter.id, col)
                    }
                }
            } label: {
                Text(filter.selectedColumn?.displayName ?? "Column")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "333333"))
                    .lineLimit(1)
                    .frame(width: 100, alignment: .leading)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray, lineWidth: 1))
            }

            Menu {
                ForEach(filter.availableConditions, id: \.self) { cond in
                    Button(cond) {
                        viewModel.updatePendingFilterCondition(filter.id, cond)
                    }
                }
            } label: {
                Text(filter.selectedCondition.isEmpty ? "Condition" : filter.selectedCondition)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "333333"))
                    .lineLimit(1)
                    .frame(width: 90, alignment: .leading)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray, lineWidth: 1))
            }

            TextField("Value", text: Binding(
                get: { filter.value },
                set: { viewModel.updatePendingFilterValue(filter.id, $0) }
            ))
            .font(.system(size: 12))
            .foregroundColor(Color(hex: "333333"))
            .frame(width: 80)
            .textFieldStyle(.roundedBorder)

            Button(action: { viewModel.removeFilter(filter.id) }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(Color.white)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "FFA500"), lineWidth: 2))
        .padding(.vertical, 4)
    }
}

private struct ActiveFilterChipView: View {
    let filter: FilterRow
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text("\(filter.selectedColumn?.displayName ?? "") \(filter.selectedCondition) \(filter.value)")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "155724"))
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "DC3545"))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Color(hex: "D4EDDA"))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "28A745"), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.vertical, 2)
    }
}

// MARK: - Data Grid Header
private struct DataGridHeaderRow: View {
    let isOwner: Bool
    let onSort: (String) -> Void
    let getSortIcon: (String) -> String

    var body: some View {
        HStack(spacing: 0) {
            HeaderCell(text: "", width: ColW.expand)
            DayDetailHeaderCell(text: "Project Name", width: ColW.projectName, sortKey: "ProjectName", onSort: onSort, getSortIcon: getSortIcon)
            DayDetailHeaderCell(text: "Client Name", width: ColW.clientName, sortKey: "ClientName", onSort: onSort, getSortIcon: getSortIcon)
            DayDetailHeaderCell(text: "Address", width: ColW.address, sortKey: "Address", onSort: onSort, getSortIcon: getSortIcon)
            DayDetailHeaderCell(text: "Duration From", width: ColW.durationFrom, sortKey: "DurationFromString", onSort: onSort, getSortIcon: getSortIcon)
            DayDetailHeaderCell(text: "Duration To", width: ColW.durationTo, sortKey: "DurationToString", onSort: onSort, getSortIcon: getSortIcon)
            DayDetailHeaderCell(text: "Contract Type", width: ColW.contractType, sortKey: "ContractType", onSort: onSort, getSortIcon: getSortIcon)
            DayDetailHeaderCell(text: "Invoice Status", width: ColW.invoiceStatus, sortKey: "InvoiceStatus", onSort: onSort, getSortIcon: getSortIcon)
            DayDetailHeaderCell(text: "H&S Status", width: ColW.hsForm, sortKey: "HSForm", onSort: onSort, getSortIcon: getSortIcon)
            DayDetailHeaderCell(text: "Final Measure", width: ColW.finalMeasure, sortKey: "FinalMeasure", onSort: onSort, getSortIcon: getSortIcon)
            DayDetailHeaderCell(text: "Job Description", width: ColW.jobDescription, sortKey: "Instructions", onSort: onSort, getSortIcon: getSortIcon)
            if isOwner {
                DayDetailHeaderCell(text: "Quote (Sent to Client)", width: ColW.quote, sortKey: "Amount", onSort: onSort, getSortIcon: getSortIcon)
            }
            DayDetailHeaderCell(text: "Contractor Quote", width: ColW.contractorQuote, sortKey: "AcceptedQuoteAmount", onSort: onSort, getSortIcon: getSortIcon)
            DayDetailHeaderCell(text: "Status", width: ColW.status, sortKey: "StatusMessage", onSort: onSort, getSortIcon: getSortIcon)
            HeaderCell(text: "Files", width: ColW.files)
            HeaderCell(text: "Actions", width: ColW.actions)
        }
        .frame(height: 40)
        .background(Color(hex: "EEEEEE"))
    }
}

private struct HeaderCell: View {
    let text: String
    let width: CGFloat
    var body: some View {
        Text(text)
            .fontWeight(.bold).font(.system(size: 14)).lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .frame(width: width, height: 40)
            .clipped()
            .overlay(Rectangle().stroke(Color.gray, lineWidth: 0.5))
    }
}

private struct DayDetailHeaderCell: View {
    let text: String
    let width: CGFloat
    let sortKey: String
    let onSort: (String) -> Void
    let getSortIcon: (String) -> String

    var body: some View {
        HStack(spacing: 2) {
            Text(text).fontWeight(.bold).font(.system(size: 14)).lineLimit(1)
            Spacer()
            let icon = getSortIcon(sortKey)
            if !icon.isEmpty { Text(icon).fontWeight(.bold).font(.system(size: 14)) }
        }
        .padding(.horizontal, 8)
        .frame(width: width, height: 40)
        .clipped()
        .overlay(Rectangle().stroke(Color.gray, lineWidth: 0.5))
        .contentShape(Rectangle())
        .onTapGesture { onSort(sortKey) }
    }
}

// MARK: - Data Row
private struct DataGridShiftRow: View {
    let row: ShiftDisplayRow
    let isOwner: Bool
    let isCaregiver: Bool
    let viewModel: DayDetailViewModel
    @Binding var path: NavigationPath

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                // Expand
                Text(row.isExpanded ? "\u{25BC}" : "\u{25B6}")
                    .font(.system(size: 16)).foregroundColor(Color(hex: "666666"))
                    .frame(width: ColW.expand, height: 55)
                    .overlay(Rectangle().stroke(Color.gray.opacity(0.5), lineWidth: 0.5))
                    .contentShape(Rectangle())
                    .onTapGesture { viewModel.toggleExpand(row.shift.id) }

                // Project Name
                HStack {
                    Text(row.shift.projectName.isEmpty ? "\u{2014}" : row.shift.projectName)
                        .font(.system(size: 14)).foregroundColor(Color(hex: "374151")).lineLimit(2)
                    Spacer()
                    Button(action: { path.append(Route.emailMessages(shiftId: row.shift.id)) }) {
                        Text("\u{1F4AC}").font(.system(size: 14))
                    }
                }
                .padding(.horizontal, 8)
                .frame(width: ColW.projectName, height: 55)
                .clipped()
                .overlay(Rectangle().stroke(Color.gray.opacity(0.5), lineWidth: 0.5))
                .contentShape(Rectangle())
                .onTapGesture { viewModel.editProjectName(row.shift.id) }

                // Client Name
                DataCellClickable(text: row.shift.clientName ?? "\u{2014}", width: ColW.clientName) {
                    viewModel.openClientSelect(row.shift.id)
                }

                // Address
                HStack {
                    Text(row.shift.address.isEmpty ? "\u{2014}" : row.shift.address)
                        .font(.system(size: 14)).foregroundColor(Color(hex: "374151")).lineLimit(2)
                    Spacer()
                    if row.shift.latitude != nil && row.shift.longitude != nil {
                        Button(action: { openMap(row.shift) }) {
                            Text("\u{1F4CD}").font(.system(size: 16))
                        }
                    }
                }
                .padding(.horizontal, 8)
                .frame(width: ColW.address, height: 55)
                .clipped()
                .overlay(Rectangle().stroke(Color.gray.opacity(0.5), lineWidth: 0.5))
                .contentShape(Rectangle())
                .onTapGesture { viewModel.editAddress(row.shift.id) }

                DataCellClickable(text: row.durationFromFormatted, width: ColW.durationFrom) { viewModel.editDurationFrom(row.shift.id) }
                DataCellClickable(text: row.durationToFormatted, width: ColW.durationTo) { viewModel.editDurationTo(row.shift.id) }

                ColoredCellClickable(text: row.contractTypeText, bgColor: row.contractTypeColor, width: ColW.contractType) { viewModel.openContractType(row.shift.id) }
                ColoredCellClickable(text: row.invoiceStatusText, bgColor: row.invoiceStatusColor, width: ColW.invoiceStatus) { viewModel.openInvoiceStatus(row.shift.id) }
                ColoredCellClickable(text: row.hsFormText, bgColor: row.hsFormColor, width: ColW.hsForm) { viewModel.openHSFormStatus(row.shift.id) }

                DataCellClickable(text: row.shift.finalMeasure.isEmpty ? "\u{2014}" : row.shift.finalMeasure, width: ColW.finalMeasure) { viewModel.editFinalMeasure(row.shift.id) }
                DataCellClickable(text: row.shift.instructions.isEmpty ? "\u{2014}" : row.shift.instructions, width: ColW.jobDescription) { viewModel.editJobDescription(row.shift.id) }

                if isOwner {
                    DataCell(text: row.shift.amount != nil ? "$\(String(format: "%.2f", row.shift.amount!))" : "", width: ColW.quote)
                }

                DataCell(text: row.shift.acceptedQuoteAmount != nil ? "$\(String(format: "%.2f", row.shift.acceptedQuoteAmount!))" : "", width: ColW.contractorQuote)
                ColoredCell(text: row.statusMessage, bgColor: row.statusColor, width: ColW.status)

                // Files
                Button(action: { path.append(Route.shiftFiles(shiftId: row.shift.id)) }) {
                    Image(systemName: "folder")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(hex: "007AFF"))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .frame(width: ColW.files, height: 55)
                .overlay(Rectangle().stroke(Color.gray.opacity(0.5), lineWidth: 0.5))

                // Actions
                HStack(spacing: 5) {
                    Button(action: { path.append(Route.shiftDetails(shiftId: row.shift.id)) }) {
                        Image(systemName: "eye")
                            .font(.system(size: 13))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(hex: "007AFF"))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)

                    if row.hasQuotations {
                        Button(action: { path.append(Route.viewQuotations(shiftId: row.shift.id)) }) {
                            Text("View Quotations").font(.system(size: 11)).fontWeight(.bold).foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(DoerTheme.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(width: ColW.actions, height: 55)
                .overlay(Rectangle().stroke(Color.gray.opacity(0.5), lineWidth: 0.5))
            }
            .frame(height: 55)

            // Sub-items section
            if row.isExpanded {
                SubItemsSection(row: row, isOwner: isOwner, viewModel: viewModel, path: $path)
            }
        }
    }

    private func openMap(_ shift: ShiftDto) {
        guard let lat = shift.latitude, let lng = shift.longitude else { return }
        if let url = URL(string: "maps://?saddr=&daddr=\(lat),\(lng)") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Sub-Items Section
private struct SubItemsSection: View {
    let row: ShiftDisplayRow
    let isOwner: Bool
    let viewModel: DayDetailViewModel
    @Binding var path: NavigationPath

    var body: some View {
        VStack(spacing: 0) {
            // Sub-items header
            HStack(spacing: 0) {
                SubHeaderCell(text: "\u{1F527} Sub Item", width: ColW.subItem)
                SubHeaderCell(text: "\u{1F6E1}\u{FE0F} H&S Status", width: ColW.subHs)
                SubHeaderCell(text: "\u{1F4CA} Status", width: ColW.subStatus)
                SubHeaderCell(text: "\u{1F680} Date Started", width: ColW.subDateStarted)
                SubHeaderCell(text: "\u{2705} Completed", width: ColW.subDateCompleted)
                SubHeaderCell(text: "\u{1F4C1} Files", width: ColW.subFiles)
                if isOwner {
                    SubHeaderCell(text: "\u{1F5D1}\u{FE0F} Delete", width: ColW.subDelete)
                }
            }
            .frame(height: 45)
            .background(Color(hex: "EEEEEE"))

            ForEach(row.subItems) { subItem in
                SubItemRowView(subItem: subItem, shiftId: row.shift.id, isOwner: isOwner, viewModel: viewModel, path: $path)
            }

            if isOwner {
                AddSubItemRowView(shiftId: row.shift.id, newName: row.newSubItemName, viewModel: viewModel)
            }
        }
        .padding(.leading, ColW.expand)
    }
}

private struct SubHeaderCell: View {
    let text: String
    let width: CGFloat
    var body: some View {
        Text(text).font(.system(size: 12)).fontWeight(.bold).lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .frame(width: width, height: 45)
            .clipped()
            .overlay(Rectangle().stroke(Color.gray, lineWidth: 0.5))
    }
}

private struct SubItemRowView: View {
    let subItem: ShiftSubItemDto
    let shiftId: Int
    let isOwner: Bool
    let viewModel: DayDetailViewModel
    @Binding var path: NavigationPath

    var body: some View {
        HStack(spacing: 0) {
            // Name + message
            HStack {
                Text(subItem.subitem).font(.system(size: 15)).foregroundColor(Color(hex: "374151")).lineLimit(2)
                Spacer()
                Button(action: { path.append(Route.subItemMessages(shiftId: shiftId, subItemId: subItem.id)) }) {
                    Text("\u{1F4AC}").font(.system(size: 14))
                }
            }
            .padding(.horizontal, 8)
            .frame(width: ColW.subItem, height: 65)
            .clipped()
            .overlay(Rectangle().stroke(Color.gray.opacity(0.5), lineWidth: 0.5))

            // H&S
            Text(DayDetailViewModel.getSubItemHSText(subItem.hsRequired))
                .font(.system(size: 12)).fontWeight(.bold).foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 8)
                .frame(width: ColW.subHs, height: 65)
                .background(DayDetailViewModel.getSubItemHSColor(subItem.hsRequired))
                .clipped()
                .overlay(Rectangle().stroke(Color.gray.opacity(0.5), lineWidth: 0.5))
                .contentShape(Rectangle())
                .onTapGesture { viewModel.openSubItemHS(shiftId, subItem.id) }

            // Status
            Text(DayDetailViewModel.getSubItemStatusText(subItem.status))
                .font(.system(size: 12)).fontWeight(.bold).foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 8)
                .frame(width: ColW.subStatus, height: 65)
                .background(DayDetailViewModel.getSubItemStatusColor(subItem.status))
                .clipped()
                .overlay(Rectangle().stroke(Color.gray.opacity(0.5), lineWidth: 0.5))
                .contentShape(Rectangle())
                .onTapGesture { viewModel.openSubItemStatus(shiftId, subItem.id) }

            // Date Started
            Text(subItem.dateStartedString.isEmpty ? "Not Started" : subItem.dateStartedString)
                .font(.system(size: 12)).fontWeight(.bold).foregroundColor(Color(hex: "374151"))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .frame(width: ColW.subDateStarted, height: 65)
                .clipped()
                .overlay(Rectangle().stroke(Color(hex: "E5E7EB"), lineWidth: 0.5))
                .contentShape(Rectangle())
                .onTapGesture { viewModel.openSubItemDateStarted(shiftId, subItem.id) }

            // Date Completed
            Text(subItem.dateCompletedString.isEmpty ? "Not Completed" : subItem.dateCompletedString)
                .font(.system(size: 12)).fontWeight(.bold).foregroundColor(Color(hex: "374151"))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .frame(width: ColW.subDateCompleted, height: 65)
                .clipped()
                .overlay(Rectangle().stroke(Color(hex: "E5E7EB"), lineWidth: 0.5))

            // Files
            Button(action: { path.append(Route.subItemFiles(shiftId: shiftId, subItemId: subItem.id)) }) {
                Image(systemName: "folder")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(hex: "007AFF"))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .frame(width: ColW.subFiles, height: 65)
            .overlay(Rectangle().stroke(Color(hex: "E5E7EB"), lineWidth: 0.5))

            if isOwner {
                Button(action: { viewModel.confirmDeleteSubItem(shiftId, subItem.id) }) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(hex: "FF3B30"))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .frame(width: ColW.subDelete, height: 65)
                .overlay(Rectangle().stroke(Color(hex: "E5E7EB"), lineWidth: 0.5))
            }
        }
        .frame(height: 65)
    }
}

private struct AddSubItemRowView: View {
    let shiftId: Int
    let newName: String
    let viewModel: DayDetailViewModel

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 5) {
                TextField("Enter sub item name...", text: Binding(
                    get: { newName },
                    set: { viewModel.updateNewSubItemName(shiftId, $0) }
                ))
                .font(.system(size: 13))
                .textFieldStyle(.roundedBorder)

                Button("Add") { viewModel.addSubItem(shiftId) }
                    .font(.system(size: 11)).fontWeight(.bold).foregroundColor(.white)
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(Color(hex: "28A745"))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .padding(.horizontal, 8)
            .frame(width: ColW.subItem, height: 50)
            .clipped()
            .border(Color(hex: "28A745"), width: 2)
            .background(Color(hex: "F0F8FF"))

            ForEach(Array([ColW.subHs, ColW.subStatus, ColW.subDateStarted, ColW.subDateCompleted, ColW.subFiles, ColW.subDelete].enumerated()), id: \.offset) { _, w in
                Rectangle().fill(Color(hex: "F0F8FF"))
                    .frame(width: w, height: 50)
                    .border(Color(hex: "28A745"), width: 2)
            }
        }
        .frame(height: 50)
    }
}

// MARK: - Reusable Cells
private struct DataCell: View {
    let text: String; let width: CGFloat
    var body: some View {
        Text(text).font(.system(size: 14)).foregroundColor(Color(hex: "374151")).lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .frame(width: width, height: 55)
            .clipped()
            .overlay(Rectangle().stroke(Color.gray.opacity(0.5), lineWidth: 0.5))
    }
}

private struct DataCellClickable: View {
    let text: String; let width: CGFloat; let onClick: () -> Void
    var body: some View {
        Text(text).font(.system(size: 14)).foregroundColor(Color(hex: "374151")).lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .frame(width: width, height: 55)
            .clipped()
            .overlay(Rectangle().stroke(Color.gray.opacity(0.5), lineWidth: 0.5))
            .contentShape(Rectangle())
            .onTapGesture { onClick() }
    }
}

private struct ColoredCell: View {
    let text: String; let bgColor: Color; let width: CGFloat
    var body: some View {
        Text(text).font(.system(size: 14)).fontWeight(.bold).foregroundColor(.white).lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .frame(width: width, height: 55)
            .background(bgColor)
            .clipped()
            .overlay(Rectangle().stroke(Color.gray.opacity(0.5), lineWidth: 0.5))
    }
}

private struct ColoredCellClickable: View {
    let text: String; let bgColor: Color; let width: CGFloat; let onClick: () -> Void
    var body: some View {
        Text(text).font(.system(size: 14)).fontWeight(.bold).foregroundColor(.white).lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .frame(width: width, height: 55)
            .background(bgColor)
            .clipped()
            .overlay(Rectangle().stroke(Color.gray.opacity(0.5), lineWidth: 0.5))
            .contentShape(Rectangle())
            .onTapGesture { onClick() }
    }
}

// MARK: - Dialogs
private struct EditorDialogView: View {
    let title: String
    @Binding var text: String
    let onSave: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationView {
            VStack {
                TextEditor(text: $text)
                    .frame(minHeight: 100)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                    .padding()
                Spacer()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.white, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onDismiss)
                        .foregroundColor(Color(hex: "333333"))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: onSave) {
                        Text("Save")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(Color(hex: "007AFF"))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct DateTimeDialogView: View {
    @Binding var date: Date
    @Binding var time: Date
    let onSave: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                DatePicker("Date", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                Spacer()
            }
            .padding()
            .tint(Color(hex: "007AFF"))
            .navigationTitle("Select Date & Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.white, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onDismiss)
                        .foregroundColor(Color(hex: "333333"))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: onSave) {
                        Text("Save")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(Color(hex: "007AFF"))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct AddressSearchDialogView: View {
    @Binding var searchText: String
    let suggestions: [PlacePrediction]
    let onPlaceSelected: (PlacePrediction) -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                TextField("Type to search...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding()

                List(suggestions, id: \.placeId) { prediction in
                    Text(prediction.description)
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "333333"))
                        .onTapGesture { onPlaceSelected(prediction) }
                }
            }
            .navigationTitle("Search Address")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.white, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onDismiss)
                        .foregroundColor(Color(hex: "333333"))
                }
            }
        }
    }
}

private struct OptionListDialogView: View {
    let title: String
    let items: [(Int, String, Color)]
    let onSelect: (Int) -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationView {
            List {
                ForEach(items, id: \.0) { (id, name, color) in
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(color)
                            .frame(width: 20, height: 20)
                        Text(name)
                            .font(.system(size: 15))
                            .foregroundColor(Color(hex: "333333"))
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { onSelect(id) }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.white, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onDismiss)
                        .foregroundColor(Color(hex: "333333"))
                }
            }
        }
    }
}
