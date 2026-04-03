import SwiftUI

// MARK: - Colors matching MAUI

private let bgColor = Color(hex: "#F8F9FA")
private let headerBg = Color(hex: "#EEEEEE")
private let borderColor = Color.gray.opacity(0.5)
private let textPrimary = Color(hex: "#374151")
private let bluePrimary = Color(hex: "#007AFF")
private let greenPrimary = Color(hex: "#28A745")
private let redPrimary = Color(hex: "#FF3B30")
private let addSubItemBg = Color(hex: "#F0F8FF")

// MARK: - Column widths matching MAUI Grid definitions

private let colExpand: CGFloat = 40
private let colProjectName: CGFloat = 180
private let colClientName: CGFloat = 180
private let colAddress: CGFloat = 225
private let colDurationFrom: CGFloat = 180
private let colDurationTo: CGFloat = 180
private let colContractType: CGFloat = 180
private let colInvoiceStatus: CGFloat = 180
private let colHSForm: CGFloat = 180
private let colFinalMeasure: CGFloat = 180
private let colInstructions: CGFloat = 200
private let colQuote: CGFloat = 180
private let colContractorQuote: CGFloat = 180
private let colStatus: CGFloat = 180
private let colFiles: CGFloat = 100
private let colActions: CGFloat = 225

// Sub-item column widths
private let subColName: CGFloat = 200
private let subColHS: CGFloat = 140
private let subColStatus: CGFloat = 120
private let subColStarted: CGFloat = 140
private let subColCompleted: CGFloat = 140
private let subColFiles: CGFloat = 80
private let subColDelete: CGFloat = 80

// MARK: - Main Screen

struct MainLeadsJobsScreen: View {
    let onOpenDrawer: () -> Void
    let onShiftDetails: (Int) -> Void
    let onViewQuotations: (Int) -> Void
    let onViewMessages: (Int) -> Void
    let onViewFiles: (Int) -> Void
    let onViewSubItemMessages: (Int, Int) -> Void
    let onViewSubItemFiles: (Int, Int) -> Void

    @State private var viewModel = MainLeadsJobsViewModel()
    @State private var showSnackbar = false
    @State private var snackbarMessage = ""

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Month Navigation
                monthNavigation

                // Filter Section
                filterSection

                // View Mode Picker
                viewModePicker

                // Content
                if viewModel.jobs.isEmpty && !viewModel.isLoading {
                    Spacer()
                    Text("No jobs found for this month")
                        .foregroundColor(.gray)
                        .font(.system(size: 16))
                    Spacer()
                } else if viewModel.isListView {
                    // Table View
                    ScrollView(.horizontal, showsIndicators: true) {
                        VStack(spacing: 0) {
                            // Header Row
                            tableHeader

                            // Data Rows
                            ScrollView(.vertical, showsIndicators: true) {
                                LazyVStack(spacing: 0) {
                                    ForEach(viewModel.jobs) { row in
                                        tableDataRow(row: row)
                                    }
                                    if viewModel.isLoadingMore {
                                        HStack {
                                            Spacer()
                                            ProgressView()
                                                .padding(16)
                                            Spacer()
                                        }
                                    }
                                }
                            }
                        }
                    }
                } else {
                    // Kanban View
                    kanbanView
                }
            }
            .background(bgColor)
            .loadingOverlay(viewModel.isLoading)
            .navigationTitle("NZ MAHI \(viewModel.currentYear)")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: onOpenDrawer) {
                        Image(systemName: "line.3.horizontal")
                    }
                }
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
            get: { viewModel.editDialog.type != .none },
            set: { if !$0 { viewModel.dismissEditDialog() } }
        )) {
            editDialogSheet
        }
        .onAppear {
            viewModel.refreshData()
        }
    }

    // MARK: - Month Navigation

    private var monthNavigation: some View {
        HStack {
            Button(action: { viewModel.previousMonth() }) {
                Text("\u{2039}")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(bluePrimary)
            }
            Spacer()
            Text(viewModel.monthDisplayText)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color(hex: "#333333"))
            Spacer()
            Button(action: { viewModel.nextMonth() }) {
                Text("\u{203A}")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(bluePrimary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(bgColor)
    }

    // MARK: - Filter Section

    private var filterSection: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack {
                    HStack(spacing: 8) {
                        Text("\u{1F50D}").font(.system(size: 16))
                        Text("Advanced Filters")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(hex: "#333333"))
                    }
                    Spacer()
                    Text(viewModel.filterStatusText)
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#666666"))
                }

                // Action Buttons
                HStack {
                    Spacer()
                    if viewModel.hasFiltersToApply {
                        Button(action: { viewModel.applyFilters() }) {
                            Text("Apply Filters")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(hex: "#34C759"))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    if viewModel.hasActiveFilters {
                        Button(action: { viewModel.clearAllFilters() }) {
                            Text("Clear All")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(redPrimary)
                        }
                    }
                    Button(action: { viewModel.addFilter() }) {
                        Text("+ Add Filter")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(bluePrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                // Pending Filters
                if viewModel.hasPendingFilters {
                    ForEach(viewModel.pendingFilters, id: \.id) { filter in
                        pendingMLFilterRow(filter: filter)
                    }
                    Text("\u{1F4A1} Configure filters above, then click 'Apply Filters'")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#6C757D"))
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                // Active Filters
                if viewModel.hasActiveFilters {
                    Text("\u{2705} Currently Applied Filters:")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(greenPrimary)
                    ForEach(viewModel.activeFilters, id: \.id) { filter in
                        activeFilterChip(filter: filter)
                    }
                }

                if viewModel.showEmptyState {
                    Text("\u{1F4CB} No filters applied - showing all projects")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#9CA3AF"))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                }
            }
            .padding(10)
        }
        .background(bgColor)
        .padding(.vertical, 5)
    }

    private func pendingMLFilterRow(filter: MLFilterRow) -> some View {
        let filterableColumns = viewModel.filterColumns.filter { !$0.propertyName.isEmpty }

        return VStack(spacing: 4) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Text("Where")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#333333"))

                    // Column picker
                    Menu {
                        ForEach(filterableColumns, id: \.id) { col in
                            Button(col.displayName) {
                                viewModel.updatePendingFilterColumn(filterId: filter.id, column: col)
                            }
                        }
                    } label: {
                        Text(filter.selectedColumn?.displayName ?? "Column")
                            .font(.system(size: 11))
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color.white)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray, lineWidth: 1))
                    }
                    .frame(width: 120)

                    // Condition picker
                    Menu {
                        ForEach(filter.selectedColumn?.availableConditions ?? [], id: \.self) { condition in
                            Button(condition) {
                                viewModel.updatePendingFilterCondition(filterId: filter.id, condition: condition)
                            }
                        }
                    } label: {
                        Text(filter.selectedCondition.isEmpty ? "Condition" : filter.selectedCondition)
                            .font(.system(size: 11))
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color.white)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray, lineWidth: 1))
                    }
                    .frame(width: 100)

                    // Value entry
                    TextField("Value", text: Binding(
                        get: { filter.value },
                        set: { viewModel.updatePendingFilterValue(filterId: filter.id, value: $0) }
                    ))
                    .font(.system(size: 12))
                    .frame(width: 80)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                    // Remove button
                    Button(action: { viewModel.removePendingFilter(filterId: filter.id) }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                    }
                    .frame(width: 24, height: 24)
                }
            }

            Text("\u{26A0}\u{FE0F} Pending - Click Apply to activate")
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "#856404"))
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(10)
        .background(Color.white)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#FFA500"), lineWidth: 2))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.vertical, 3)
    }

    private func activeFilterChip(filter: MLFilterRow) -> some View {
        HStack {
            Text("\(filter.selectedColumn?.displayName ?? "") \(filter.selectedCondition) \(filter.value)")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#155724"))
            Spacer()
            Button(action: { viewModel.removePendingFilter(filterId: filter.id) }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "#DC3545"))
            }
            .frame(width: 20, height: 20)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(hex: "#D4EDDA"))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(greenPrimary, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.vertical, 2)
    }

    // MARK: - View Mode Picker

    private var viewModePicker: some View {
        HStack {
            Menu {
                Button("Main Table") { viewModel.setViewMode("Main Table") }
                Button("Kanban") { viewModel.setViewMode("Kanban") }
            } label: {
                HStack {
                    Text(viewModel.selectedViewMode)
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#111827"))
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                .padding(8)
            }
        }
        .padding(8)
        .background(Color(hex: "#F9FAFB"))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#E5E7EB"), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 15)
        .padding(.vertical, 4)
    }

    // MARK: - Table Header

    private var tableHeader: some View {
        HStack(spacing: 0) {
            // Expand column (no sort)
            mlHeaderCell("", colExpand, sortable: false)
            mlSortableHeader("Project Name", colProjectName, "ProjectName")
            mlSortableHeader("Client Name", colClientName, "ClientName")
            mlSortableHeader("Address", colAddress, "Address")
            mlSortableHeader("Duration From", colDurationFrom, "DurationFromString")
            mlSortableHeader("Duration To", colDurationTo, "DurationToString")
            mlSortableHeader("Contract Type", colContractType, "ContractType")
            mlSortableHeader("Invoice Status", colInvoiceStatus, "InvoiceStatus")
            mlSortableHeader("H&S Status", colHSForm, "HSForm")
            mlSortableHeader("Final Measure", colFinalMeasure, "FinalMeasure")
            mlSortableHeader("Job Description", colInstructions, "Instructions")
            if viewModel.isOwner {
                mlSortableHeader("Quote (Sent to Client)", colQuote, "Amount")
            }
            mlSortableHeader("Contractor Quote", colContractorQuote, "AcceptedQuoteAmount")
            mlSortableHeader("Status", colStatus, "StatusMessage")
            mlHeaderCell("Files", colFiles, sortable: false)
            mlHeaderCell("Actions", colActions, sortable: false)
        }
        .background(headerBg)
    }

    private func mlHeaderCell(_ title: String, _ width: CGFloat, sortable: Bool) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(.black)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .frame(width: width, height: 40)
            .clipped()
            .overlay(Rectangle().stroke(Color.gray, lineWidth: 0.5))
    }

    private func mlSortableHeader(_ title: String, _ width: CGFloat, _ column: String) -> some View {
        let sortIcon = viewModel.sortColumn == column ? (viewModel.sortAscending ? "\u{25B2}" : "\u{25BC}") : ""
        return Button(action: { viewModel.sortBy(column) }) {
            HStack {
                Text("\(title)\(sortIcon.isEmpty ? "" : " \(sortIcon)")")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.black)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 8)
        }
        .frame(width: width, height: 40)
        .clipped()
        .overlay(Rectangle().stroke(Color.gray, lineWidth: 0.5))
    }

    // MARK: - Table Data Row

    private func tableDataRow(row: JobRowItem) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                // Expand/Collapse
                Button(action: { viewModel.toggleExpanded(row.shift.id) }) {
                    Text(row.isExpanded ? "\u{25BC}" : "\u{25B6}")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "#666666"))
                }
                .frame(width: colExpand, height: 55)
                .overlay(Rectangle().stroke(borderColor, lineWidth: 0.5))

                // Project Name + Message icon
                Button(action: { viewModel.editProjectName(row.shift.id) }) {
                    HStack(spacing: 3) {
                        Text(row.shift.projectName)
                            .font(.system(size: 14))
                            .foregroundColor(textPrimary)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 5)
                        Button(action: { onViewMessages(row.shift.id) }) {
                            Text("\u{1F4AC}")
                                .font(.system(size: 16))
                        }
                        .padding(.horizontal, 4)
                    }
                }
                .frame(width: colProjectName, height: 55)
                .overlay(Rectangle().stroke(borderColor, lineWidth: 0.5))

                // Client Name
                mlCellLabel(row.shift.clientName ?? "", colClientName) { viewModel.editClient(row.shift.id) }

                // Address
                mlCellLabel(row.shift.address, colAddress) { viewModel.editAddress(row.shift.id) }

                // Duration From
                mlCellLabel(
                    row.shift.durationFromString.isEmpty ? viewModel.formatTimestamp(row.shift.durationFrom) : row.shift.durationFromString,
                    colDurationFrom
                ) { viewModel.editDurationFrom(row.shift.id) }

                // Duration To
                mlCellLabel(
                    row.shift.durationToString.isEmpty ? viewModel.formatTimestamp(row.shift.durationTo) : row.shift.durationToString,
                    colDurationTo
                ) { viewModel.editDurationTo(row.shift.id) }

                // Contract Type (colored background)
                mlColoredBgCell(row.contractTypeDisplayText, row.contractTypeColor, colContractType) {
                    viewModel.editContractType(row.shift.id)
                }

                // Invoice Status (colored background)
                mlColoredBgCell(row.invoiceDisplayText, row.invoiceColor, colInvoiceStatus) {
                    viewModel.editInvoiceStatus(row.shift.id)
                }

                // H&S Form (colored background)
                mlColoredBgCell(row.hsFormText, row.hsFormColor, colHSForm) {
                    viewModel.editHSFormStatus(row.shift.id)
                }

                // Final Measure
                mlCellLabel(row.shift.finalMeasure, colFinalMeasure) { viewModel.editFinalMeasure(row.shift.id) }

                // Job Description
                mlCellLabel(row.shift.instructions, colInstructions) { viewModel.editJobDescription(row.shift.id) }

                // Quote (owner only)
                if viewModel.isOwner {
                    mlCellLabel(viewModel.formatAmount(row.shift.amount), colQuote)
                }

                // Contractor Quote
                mlCellLabel(viewModel.formatAmount(row.shift.acceptedQuoteAmount), colContractorQuote)

                // Status (colored background, read-only)
                mlColoredBgCell(row.statusDisplayText, row.statusColor, colStatus)

                // Files
                ZStack {
                    Rectangle().stroke(borderColor, lineWidth: 0.5)
                    Button(action: { onViewFiles(row.shift.id) }) {
                        Image(systemName: "folder")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(hex: "007AFF"))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
                .frame(width: colFiles, height: 55)

                // Actions
                ZStack {
                    Rectangle().stroke(borderColor, lineWidth: 0.5)
                    HStack(spacing: 5) {
                        Button(action: { onShiftDetails(row.shift.id) }) {
                            Image(systemName: "eye")
                                .font(.system(size: 13))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(hex: "007AFF"))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)

                        if row.shift.hasQuotations {
                            Button(action: { onViewQuotations(row.shift.id) }) {
                                Text("View Quotations")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(DoerTheme.primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(width: colActions, height: 55)
            }

            // Expanded Sub-Items
            if row.isExpanded {
                subItemsSection(row: row)
            }
        }
        .onAppear {
            // Load more when near bottom
            if let lastJob = viewModel.jobs.last, row.shift.id == lastJob.shift.id {
                viewModel.loadMore()
            }
        }
    }

    private func mlCellLabel(_ text: String, _ width: CGFloat, onClick: (() -> Void)? = nil) -> some View {
        Group {
            if let onClick = onClick {
                Button(action: onClick) {
                    Text(text)
                        .font(.system(size: 14))
                        .foregroundColor(textPrimary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                }
            } else {
                Text(text)
                    .font(.system(size: 14))
                    .foregroundColor(textPrimary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
            }
        }
        .frame(width: width, height: 55)
        .clipped()
        .overlay(Rectangle().stroke(borderColor, lineWidth: 0.5))
    }

    private func mlColoredBgCell(_ text: String, _ color: Color, _ width: CGFloat, onClick: (() -> Void)? = nil) -> some View {
        Group {
            if let onClick = onClick {
                Button(action: onClick) {
                    Text(text)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                }
            } else {
                Text(text)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
            }
        }
        .frame(width: width, height: 55)
        .background(color)
        .clipped()
        .overlay(Rectangle().stroke(borderColor, lineWidth: 0.5))
    }

    // MARK: - Sub-Items Section

    private func subItemsSection(row: JobRowItem) -> some View {
        VStack(spacing: 0) {
            // Sub-items Header
            HStack(spacing: 0) {
                subItemHeaderCell("\u{1F527} Sub Item", subColName)
                subItemHeaderCell("\u{1F6E1}\u{FE0F} H&S Status", subColHS)
                subItemHeaderCell("\u{1F4CA} Status", subColStatus)
                subItemHeaderCell("\u{1F680} Date Started", subColStarted)
                subItemHeaderCell("\u{2705} Completed", subColCompleted)
                subItemHeaderCell("\u{1F4C1} Files", subColFiles)
                if viewModel.isOwner {
                    subItemHeaderCell("\u{1F5D1}\u{FE0F} Delete", subColDelete)
                }
            }
            .padding(.top, 15)

            // Sub-item rows
            if row.subItems.isEmpty {
                Text("No sub-items")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .padding(8)
            } else {
                ForEach(row.subItems) { subItem in
                    subItemDataRow(subItem: subItem, shiftId: row.shift.id)
                }
            }

            // Add Sub Item Row
            if row.isAddSubItem {
                addSubItemRow(row: row)
            }

            Spacer().frame(height: 8)
        }
        .padding(.leading, colExpand)
        .background(Color(hex: "#F9FAFB"))
    }

    private func subItemHeaderCell(_ text: String, _ width: CGFloat) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.black)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .frame(width: width, height: 45)
            .clipped()
            .background(headerBg)
            .overlay(Rectangle().stroke(Color.gray, lineWidth: 0.5))
    }

    private func subItemDataRow(subItem: ShiftSubItemDto, shiftId: Int) -> some View {
        let hsText = MainLeadsJobsViewModel.getHSFormText(subItem.hsRequired)
        let hsColor = MainLeadsJobsViewModel.getHSFormColor(subItem.hsRequired)
        let statusText = MainLeadsJobsViewModel.getSubItemStatusText(subItem.status)
        let statusColor = MainLeadsJobsViewModel.getSubItemStatusColor(subItem.status)

        return HStack(spacing: 0) {
            // Sub-item name + message icon
            HStack(spacing: 0) {
                Text(subItem.subitem)
                    .font(.system(size: 15))
                    .foregroundColor(textPrimary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: { onViewSubItemMessages(shiftId, subItem.id) }) {
                    Text("\u{1F4AC}")
                        .font(.system(size: 16))
                }
                .padding(.leading, 4)
            }
            .padding(.horizontal, 8)
            .frame(width: subColName, height: 65)
            .clipped()
            .overlay(Rectangle().stroke(Color(hex: "#E5E7EB"), lineWidth: 0.5))

            // H&S Required (colored)
            Button(action: { viewModel.editSubItemHSStatus(subItem.id) }) {
                Text(hsText)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 8)
            }
            .frame(width: subColHS, height: 65)
            .background(hsColor)
            .clipped()
            .overlay(Rectangle().stroke(Color(hex: "#E5E7EB"), lineWidth: 0.5))

            // Status (colored)
            Button(action: { viewModel.editSubItemStatus(subItem.id) }) {
                Text(statusText)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 8)
            }
            .frame(width: subColStatus, height: 65)
            .background(statusColor)
            .clipped()
            .overlay(Rectangle().stroke(Color(hex: "#E5E7EB"), lineWidth: 0.5))

            // Date Started
            subItemTextCell(
                subItem.dateStartedString.isEmpty ? "Not Started" : subItem.dateStartedString,
                subColStarted
            ) { viewModel.editSubItemDateStarted(shiftId: shiftId, subItemId: subItem.id) }

            // Date Completed
            subItemTextCell(
                subItem.dateCompletedString.isEmpty ? "Not Completed" : subItem.dateCompletedString,
                subColCompleted
            )

            // Files button
            Button(action: { onViewSubItemFiles(shiftId, subItem.id) }) {
                Image(systemName: "folder")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(hex: "007AFF"))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .frame(width: subColFiles, height: 65)
            .overlay(Rectangle().stroke(Color(hex: "#E5E7EB"), lineWidth: 0.5))

            // Delete button (owner only)
            if viewModel.isOwner {
                Button(action: { viewModel.confirmDeleteSubItem(subItem.id) }) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(hex: "FF3B30"))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .frame(width: subColDelete, height: 65)
                .overlay(Rectangle().stroke(Color(hex: "#E5E7EB"), lineWidth: 0.5))
            }
        }
    }

    private func subItemTextCell(_ text: String, _ width: CGFloat, onClick: (() -> Void)? = nil) -> some View {
        Group {
            if let onClick = onClick {
                Button(action: onClick) {
                    Text(text)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                }
            } else {
                Text(text)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
            }
        }
        .frame(width: width, height: 65)
        .clipped()
        .background(Color.white)
        .overlay(Rectangle().stroke(Color(hex: "#E5E7EB"), lineWidth: 0.5))
    }

    private func addSubItemRow(row: JobRowItem) -> some View {
        HStack(spacing: 0) {
            // Name input + Add button
            HStack(spacing: 5) {
                TextField("Enter sub item name...", text: Binding(
                    get: { row.newSubItemName },
                    set: { viewModel.updateNewSubItemName(shiftId: row.shift.id, name: $0) }
                ))
                .font(.system(size: 13))
                .foregroundColor(textPrimary)
                .textFieldStyle(.roundedBorder)

                Button(action: { viewModel.addNewSubItem(row.shift.id) }) {
                    Text("Add")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(greenPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .frame(height: 30)
            }
            .padding(.horizontal, 8)
            .frame(width: subColName, height: 50)
            .clipped()
            .background(addSubItemBg)
            .overlay(Rectangle().stroke(greenPrimary, lineWidth: 2))

            // Empty placeholder cells
            ForEach(Array([subColHS, subColStatus, subColStarted, subColCompleted, subColFiles].enumerated()), id: \.offset) { _, w in
                Color.clear
                    .frame(width: w, height: 50)
                    .background(addSubItemBg)
                    .overlay(Rectangle().stroke(greenPrimary, lineWidth: 2))
            }
            if viewModel.isOwner {
                Color.clear
                    .frame(width: subColDelete, height: 50)
                    .background(addSubItemBg)
                    .overlay(Rectangle().stroke(greenPrimary, lineWidth: 2))
            }
        }
        .padding(.bottom, 5)
    }

    // MARK: - Kanban View

    private var kanbanView: some View {
        Group {
            if viewModel.kanbanColumns.isEmpty {
                kanbanEmptyView
            } else {
                kanbanTabView
            }
        }
    }

    private var kanbanEmptyView: some View {
        VStack {
            Spacer()
            Text("No data for Kanban view")
                .foregroundColor(.gray)
            Spacer()
        }
    }

    private var kanbanTabView: some View {
        TabView {
            ForEach(viewModel.kanbanColumns) { column in
                kanbanColumnView(column: column)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
    }

    private func kanbanColumnView(column: KanbanColumn) -> some View {
        VStack(spacing: 0) {
            // Column Header
            Text(column.title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(column.headerColor)
                .clipShape(RoundedRectangle(cornerRadius: 14))

            Spacer().frame(height: 12)

            // Cards
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(column.items) { job in
                        kanbanCard(job: job)
                    }
                }
            }
        }
        .padding(10)
    }

    private func kanbanCard(job: JobRowItem) -> some View {
        Button(action: { onShiftDetails(job.shift.id) }) {
            VStack(alignment: .leading, spacing: 8) {
                // Title + Message
                HStack {
                    Text(job.shift.projectName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(hex: "#111827"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button(action: { onViewMessages(job.shift.id) }) {
                        Text("\u{1F4AC}")
                            .font(.system(size: 16))
                    }
                }

                // Duration From
                HStack {
                    Text("\u{1F4C5} Duration From")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#111827"))
                    Spacer()
                    Text(job.shift.durationFromString.isEmpty ? job.shift.durationFrom : job.shift.durationFromString)
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#6B7280"))
                        .padding(8)
                        .background(Color(hex: "#F3F4F6"))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#E5E7EB"), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                // Sub Items count
                HStack {
                    Text("Sub Items")
                        .font(.system(size: 14))
                    Spacer()
                    Text("\(job.subItems.count)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(textPrimary)
                        .padding(6)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#E5E7EB"), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(10)
        }
        .buttonStyle(.plain)
        .background(Color.white)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#E5E7EB"), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Edit Dialog Sheet

    private var editDateBinding: Binding<Date> {
        Binding(
            get: { viewModel.editDialog.selectedDate },
            set: { viewModel.updateEditDialogDate($0) }
        )
    }

    private var editTimeBinding: Binding<Date> {
        Binding(
            get: {
                let calendar = Calendar.current
                var components = DateComponents()
                components.hour = viewModel.editDialog.selectedHour
                components.minute = viewModel.editDialog.selectedMinute
                return calendar.date(from: components) ?? Date()
            },
            set: { newDate in
                let calendar = Calendar.current
                let hour = calendar.component(.hour, from: newDate)
                let minute = calendar.component(.minute, from: newDate)
                viewModel.updateEditDialogTime(hour: hour, minute: minute)
            }
        )
    }

    @ViewBuilder
    private var editDialogSheet: some View {
        switch viewModel.editDialog.type {
        case .textEditor:
            MLTextEditorSheet(
                title: viewModel.editDialog.title,
                text: Binding(
                    get: { viewModel.editDialog.textValue },
                    set: { viewModel.updateEditDialogText($0) }
                ),
                onSave: { viewModel.saveTextEdit() },
                onDismiss: { viewModel.dismissEditDialog() }
            )
        case .dateTimePicker, .subItemDatePicker:
            MLDateTimePickerSheet(
                date: editDateBinding,
                time: editTimeBinding,
                onSave: {
                    if viewModel.editDialog.type == .subItemDatePicker {
                        viewModel.saveSubItemDate(
                            date: viewModel.editDialog.selectedDate,
                            hour: viewModel.editDialog.selectedHour,
                            minute: viewModel.editDialog.selectedMinute
                        )
                    } else {
                        viewModel.saveDateTimeEdit()
                    }
                },
                onDismiss: { viewModel.dismissEditDialog() }
            )
        case .contractTypePicker:
            MLStatusPickerSheet(
                title: "Contract Type",
                items: MainLeadsJobsViewModel.contractTypeOptions.map { ($0.value, $0.name, $0.color) },
                onSelect: { value in
                    viewModel.selectContractType(value)
                },
                onDismiss: { viewModel.dismissEditDialog() }
            )
        case .invoiceStatusPicker:
            MLStatusPickerSheet(
                title: "Invoice Status",
                items: MainLeadsJobsViewModel.invoiceStatusOptions.map { ($0.value, $0.name, $0.color) },
                onSelect: { value in
                    viewModel.selectInvoiceStatus(value)
                },
                onDismiss: { viewModel.dismissEditDialog() }
            )
        case .hsFormStatusPicker:
            MLStatusPickerSheet(
                title: "H&S Form Status",
                items: MainLeadsJobsViewModel.hsFormOptions.map { ($0.value, $0.name, $0.color) },
                onSelect: { value in
                    viewModel.selectHSFormStatus(value)
                },
                onDismiss: { viewModel.dismissEditDialog() }
            )
        case .subItemHSPicker:
            MLStatusPickerSheet(
                title: "H&S Status",
                items: MainLeadsJobsViewModel.hsFormOptions.map { ($0.value, $0.name, $0.color) },
                onSelect: { value in
                    viewModel.selectSubItemHSStatus(value)
                },
                onDismiss: { viewModel.dismissEditDialog() }
            )
        case .subItemStatusPicker:
            MLStatusPickerSheet(
                title: "Sub-Item Status",
                items: MainLeadsJobsViewModel.subItemStatusOptions.map { ($0.value, $0.name, $0.color) },
                onSelect: { value in
                    viewModel.selectSubItemStatus(value)
                },
                onDismiss: { viewModel.dismissEditDialog() }
            )
        case .addressSearch:
            MLAddressSearchSheet(
                searchText: Binding(
                    get: { viewModel.addressSearchText },
                    set: { viewModel.addressSearchText = $0 }
                ),
                suggestions: viewModel.placeSuggestions,
                onSearchChange: { viewModel.onAddressSearchChange($0) },
                onPlaceSelected: { viewModel.onPlaceSelected($0) },
                onDismiss: { viewModel.dismissEditDialog() }
            )
        case .clientPicker:
            MLClientPickerSheet(
                clients: viewModel.clients,
                onSelect: { client in
                    viewModel.selectClient(client.id, clientName: client.name)
                },
                onDismiss: { viewModel.dismissEditDialog() }
            )
        case .deleteSubItem:
            MLDeleteConfirmSheet(
                subItemName: viewModel.deleteSubItemName,
                onConfirm: { viewModel.deleteSubItem(viewModel.editDialog.selectedSubItemId) },
                onDismiss: { viewModel.dismissEditDialog() }
            )
        case .none:
            EmptyView()
        }
    }
}

// MARK: - Bottom Sheet Dialogs

private struct MLTextEditorSheet: View {
    let title: String
    @Binding var text: String
    let onSave: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
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

            Rectangle()
                .fill(Color(hex: "#667685"))
                .frame(height: 1)

            TextEditor(text: $text)
                .frame(height: 150)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray))
                .padding(16)

            Spacer()
        }
        .presentationDetents([.large])
    }
}

private struct MLDateTimePickerSheet: View {
    @Binding var date: Date
    @Binding var time: Date
    let onSave: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 20))
                        .foregroundColor(.black)
                        .frame(width: 30, height: 30)
                }
                Spacer()
                Text("Select Date & Time")
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

            Rectangle()
                .fill(Color(hex: "#667685"))
                .frame(height: 1)

            DatePicker("Date", selection: $date, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .padding(.horizontal, 16)
                .tint(Color(hex: "007AFF"))

            DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                .padding(.horizontal, 16)
                .tint(Color(hex: "007AFF"))

            Spacer()
        }
        .presentationDetents([.large])
    }
}

private struct MLStatusPickerSheet: View {
    let title: String
    let items: [(Int, String, Color)]
    let onSelect: (Int) -> Void
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
                Text(title)
                    .font(.system(size: 18, weight: .bold))
            }
            .padding(16)

            ScrollView {
                VStack(spacing: 4) {
                    ForEach(items, id: \.0) { id, name, color in
                        Button(action: { onSelect(id) }) {
                            Text(name)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(12)
                        }
                        .background(color)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.horizontal, 16)
            }

            Spacer()
        }
        .presentationDetents([.large])
    }
}

private struct MLAddressSearchSheet: View {
    @Binding var searchText: String
    let suggestions: [PlacePrediction]
    let onSearchChange: (String) -> Void
    let onPlaceSelected: (PlacePrediction) -> Void
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
                Text("Search Address")
                    .font(.system(size: 18, weight: .bold))
            }
            .padding(16)

            // Search field
            HStack {
                TextField("Type to search...", text: Binding(
                    get: { searchText },
                    set: { onSearchChange($0) }
                ))
                if !searchText.isEmpty {
                    Button(action: { onSearchChange("") }) {
                        Text("X")
                            .foregroundColor(.black)
                            .font(.system(size: 16))
                    }
                }
            }
            .padding()
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray))
            .padding(.horizontal, 16)

            if suggestions.isEmpty && searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                VStack {
                    Text("Start typing to search")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#6B7280"))
                }
                .frame(maxWidth: .infinity)
                .padding(20)
            }

            // Suggestions
            if !suggestions.isEmpty {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(suggestions, id: \.placeId) { prediction in
                            Button(action: { onPlaceSelected(prediction) }) {
                                Text(prediction.description)
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(hex: "#333333"))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(8)
                            }
                            Divider()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }

            Spacer()
        }
        .presentationDetents([.large])
    }
}

private struct MLClientPickerSheet: View {
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
                Text("Select Client")
                    .font(.system(size: 18, weight: .bold))
            }
            .padding(16)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(clients) { client in
                        Button(action: { onSelect(client) }) {
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(hex: "#007AFF"))
                                    .frame(width: 20, height: 20)
                                Text(client.name)
                                    .font(.system(size: 15))
                                    .foregroundColor(Color(hex: "#333333"))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                        }
                        Divider()
                    }
                }
                .padding(.horizontal, 16)
            }

            Spacer()
        }
        .presentationDetents([.large])
    }
}

private struct MLDeleteConfirmSheet: View {
    let subItemName: String
    let onConfirm: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Delete Sub-Item")
                .font(.system(size: 18, weight: .bold))
                .padding(.top, 24)

            Text("Are you sure you want to delete \"\(subItemName)\"?")
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "#374151"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            HStack(spacing: 16) {
                Button(action: onDismiss) {
                    Text("Cancel")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                        .padding(12)
                }
                .background(Color(hex: "#F3F4F6"))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Button(action: onConfirm) {
                    Text("Delete")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(12)
                }
                .background(Color(hex: "#FF3B30"))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(.horizontal, 16)

            Spacer()
        }
        .presentationDetents([.large])
    }
}
