import SwiftUI

struct ShiftDetailsScreen: View {
    @Binding var path: NavigationPath
    @State private var viewModel: ShiftDetailsViewModel
    @State private var showDeleteDialog = false
    @State private var toastMessage: String? = nil

    init(path: Binding<NavigationPath>, shiftId: Int) {
        self._path = path
        self._viewModel = State(initialValue: ShiftDetailsViewModel(shiftId: shiftId))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(hex: "F8F9FA").ignoresSafeArea()

            if viewModel.isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if viewModel.shift == nil {
                VStack {
                    Spacer()
                    Text("Failed to load job details")
                        .foregroundColor(.gray)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                let shift = viewModel.shift!

                ScrollView {
                    VStack(spacing: 20) {
                        // Manager Selection (Admin only)
                        if viewModel.isAdmin {
                            ManagerPickerSection(
                                managersList: viewModel.managersList,
                                selectedManagerId: viewModel.selectedManagerId,
                                onSelectManager: { managerId in
                                    viewModel.selectManager(managerId)
                                    viewModel.updateShift()
                                }
                            )
                        }

                        // Manager Information Card (Admin only)
                        if viewModel.isAdmin && !viewModel.managerName.isEmpty {
                            InfoCard(
                                icon: "\u{1F464}",
                                title: "Manager Information",
                                rows: [
                                    ("\u{1F464}", "Manager Name:", viewModel.managerName),
                                    ("\u{1F4E7}", "Manager Email:", viewModel.managerEmail),
                                    ("\u{1F4F1}", "Manager Phone:", viewModel.managerPhone)
                                ]
                            )
                        }

                        // Contractor Information Card
                        if viewModel.isManager && !viewModel.contractorName.isEmpty {
                            InfoCard(
                                icon: "\u{1F464}",
                                title: "Contractor Information",
                                rows: [
                                    ("\u{1F464}", "Name:", viewModel.contractorName),
                                    ("\u{1F4E7}", "Email:", viewModel.contractorEmail),
                                    ("\u{1F4F1}", "Phone:", viewModel.contractorPhone)
                                ]
                            )
                        }

                        // Project Name
                        DetailCard(icon: "\u{1F4CB}", title: "Project Name") {
                            Text(shift.projectName.isEmpty ? "Not Set" : shift.projectName)
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "6B7280"))
                                .padding(.leading, 26)
                        }

                        // Client Name
                        DetailCard(icon: "\u{1F464}", title: "Client Name") {
                            Text(shift.clientName ?? "")
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "6B7280"))
                                .padding(.leading, 26)
                        }

                        // All Day toggle (Manager/Admin only)
                        if viewModel.isAllDayEditable {
                            VStack {
                                HStack {
                                    Text("All Day")
                                        .font(.system(size: 16))
                                        .fontWeight(.bold)
                                        .foregroundColor(Color(hex: "007AFF"))
                                    Spacer()
                                    Toggle("", isOn: Binding(
                                        get: { viewModel.isAllDay },
                                        set: { newValue in
                                            viewModel.updateIsAllDay(newValue)
                                            viewModel.updateShift()
                                        }
                                    ))
                                    .labelsHidden()
                                }
                                .padding(.horizontal, 15)
                                .padding(.vertical, 10)
                            }
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.08), radius: 2, y: 1)
                        }

                        // Reminder Section
                        if viewModel.showReminderSection {
                            ReminderCard(
                                canEdit: viewModel.canEditReminder,
                                canViewOnly: viewModel.canViewReminderOnly,
                                hasReminderSet: viewModel.hasReminderSet,
                                reminderOptions: viewModel.reminderOptions,
                                selectedLabel: viewModel.selectedReminderLabel,
                                reminderTime: viewModel.shift?.reminderTime,
                                onSelectReminder: { label in
                                    viewModel.selectReminder(label)
                                    viewModel.addReminder()
                                }
                            )
                        }

                        // Job Location
                        DetailCard(icon: "\u{1F4CD}", title: "Job Location") {
                            Text(shift.address.isEmpty ? "Not Set" : shift.address)
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "6B7280"))
                                .padding(.leading, 26)
                        }

                        // Job Schedule
                        DetailCard(icon: "\u{23F0}", title: "Job Schedule") {
                            VStack(spacing: 10) {
                                ScheduleRow(label: "\u{1F550} Duration From:", value: viewModel.durationFromFormatted)
                                ScheduleRow(label: "\u{1F555} Duration To:", value: viewModel.durationToFormatted)
                                if viewModel.showShiftStartTime && !viewModel.shiftStartTimeFormatted.isEmpty {
                                    ScheduleRow(label: "\u{2705} Actual Start:", value: viewModel.shiftStartTimeFormatted)
                                }
                                if viewModel.showShiftEndTime && !viewModel.shiftEndTimeFormatted.isEmpty {
                                    ScheduleRow(label: "\u{1F3C1} Actual End:", value: viewModel.shiftEndTimeFormatted)
                                }
                            }
                        }

                        // Job Description
                        DetailCard(icon: "\u{1F4DD}", title: "Job Description") {
                            Text(shift.instructions.isEmpty ? "No description" : shift.instructions)
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "6B7280"))
                                .padding(.leading, 26)
                        }

                        // Contract Type
                        DetailCard(icon: "\u{1F4C4}", title: "Contract Type") {
                            Text(viewModel.contractTypeText)
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "6B7280"))
                                .padding(.leading, 26)
                        }

                        // Invoice Status
                        DetailCard(icon: "\u{1F9FE}", title: "Invoice Status") {
                            Text(viewModel.invoiceStatusText)
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "6B7280"))
                                .padding(.leading, 26)
                        }

                        // H&S Forms Required
                        DetailCard(icon: "\u{1F6E1}\u{FE0F}", title: "H&S Forms Required") {
                            if viewModel.showHsForm {
                                Text(viewModel.hsFormText)
                                    .font(.system(size: 14))
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 15)
                                    .padding(.vertical, 8)
                                    .background(viewModel.hsFormColor)
                                    .cornerRadius(12)
                                    .padding(.leading, 26)
                                    .padding(.top, 8)
                            }
                        }

                        // Feedback Section
                        if viewModel.showFeedback {
                            FeedbackCard(shift: shift)
                        }

                        // Job Status
                        DetailCard(icon: "\u{1F4CA}", title: "Job Status") {
                            Text(viewModel.statusMessage)
                                .font(.system(size: 14))
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(viewModel.statusColor)
                                .cornerRadius(20)
                        }

                        // Action Buttons Section
                        ActionButtonsSection(
                            viewModel: viewModel,
                            onSendQuote: {
                                path.append(Route.sendQuote(shiftId: shift.id))
                            },
                            onViewQuotations: {
                                path.append(Route.viewQuotations(shiftId: shift.id))
                            },
                            onSendFeedback: { shiftId in
                                path.append(Route.sendFeedback(shiftId: shiftId))
                            }
                        )

                        Spacer().frame(height: 30)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 30)
                }
            }

            // Toast message
            if let message = toastMessage {
                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(8)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle("Job Details")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .toolbar {
            if viewModel.isDeleteButton {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showDeleteDialog = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .frame(width: 40, height: 40)
                            .background(Color(hex: "E3F2FD"))
                            .clipShape(Circle())
                    }
                }
            }
        }
        .alert("Delete Job", isPresented: $showDeleteDialog) {
            Button("Yes", role: .destructive) {
                viewModel.deleteShift()
            }
            Button("No", role: .cancel) {}
        } message: {
            Text("Do you really want to delete this job?")
        }
        .onChange(of: viewModel.isDeleted) { _, newValue in
            if newValue { path.removeLast() }
        }
        .onChange(of: viewModel.navigateToFeedbackShiftId) { _, newValue in
            if let shiftId = newValue {
                viewModel.onFeedbackNavigated()
                path.append(Route.sendFeedback(shiftId: shiftId))
            }
        }
        .onChange(of: viewModel.errorMessage) { _, newValue in
            if let msg = newValue {
                showToast(msg)
                viewModel.clearError()
            }
        }
        .onChange(of: viewModel.successMessage) { _, newValue in
            if let msg = newValue {
                showToast(msg)
                viewModel.clearSuccessMessage()
                if msg == "Shift started" || msg == "Shift ended" || msg == "Shift marked as not completed" || msg == "Shift updated" {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        path.removeLast()
                    }
                }
            }
        }
        .onAppear {
            if viewModel.shift == nil {
                viewModel.loadInitialData()
            } else {
                viewModel.refresh()
            }
        }
    }

    private func showToast(_ message: String) {
        withAnimation {
            toastMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                toastMessage = nil
            }
        }
    }
}

// MARK: - Detail Card

private struct DetailCard<Content: View>: View {
    let icon: String
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(icon)
                    .font(.system(size: 18))
                Text(title)
                    .font(.system(size: 18))
                    .fontWeight(.bold)
                    .foregroundColor(Color(hex: "007AFF"))
            }
            Spacer().frame(height: 8)
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.08), radius: 2, y: 1)
    }
}

// MARK: - Info Card

private struct InfoCard: View {
    let icon: String
    let title: String
    let rows: [(String, String, String)] // (icon, label, value)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(icon)
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: "007AFF"))
                Text(title)
                    .font(.system(size: 18))
                    .fontWeight(.bold)
                    .foregroundColor(Color(hex: "007AFF"))
            }
            Spacer().frame(height: 15)
            VStack(spacing: 10) {
                ForEach(rows.indices, id: \.self) { idx in
                    HStack(spacing: 8) {
                        Text(rows[idx].0)
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "6B7280"))
                        Text(rows[idx].1)
                            .font(.system(size: 14))
                            .fontWeight(.bold)
                            .foregroundColor(Color(hex: "6B7280"))
                        Text(rows[idx].2)
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "6B7280"))
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.08), radius: 2, y: 1)
    }
}

// MARK: - Schedule Row

private struct ScheduleRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .fontWeight(.bold)
                .foregroundColor(Color(hex: "6B7280"))
            Spacer()
            Text(value)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "6B7280"))
        }
    }
}

// MARK: - Manager Picker Section

private struct ManagerPickerSection: View {
    let managersList: [UserDto]
    let selectedManagerId: String?
    let onSelectManager: (String) -> Void

    @State private var isExpanded = false

    var body: some View {
        if managersList.isEmpty { EmptyView() } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 5) {
                    Text("\u{1F464}")
                        .font(.system(size: 16))
                    Text("Assigned Manager:")
                        .font(.system(size: 16))
                        .fontWeight(.bold)
                        .foregroundColor(Color(hex: "007AFF"))
                }

                Menu {
                    ForEach(managersList) { manager in
                        Button {
                            onSelectManager(manager.id)
                        } label: {
                            Text(manager.displayName)
                                .fontWeight(.bold)
                                .foregroundColor(Color(hex: "007AFF"))
                        }
                    }
                } label: {
                    HStack {
                        Text(managersList.first(where: { $0.id == selectedManagerId })?.displayName ?? "Select Manager")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                    )
                }
            }
        }
    }
}

// MARK: - Reminder Card

private struct ReminderCard: View {
    let canEdit: Bool
    let canViewOnly: Bool
    let hasReminderSet: Bool
    let reminderOptions: [ReminderOption]
    let selectedLabel: String
    let reminderTime: String?
    let onSelectReminder: (String) -> Void

    var body: some View {
        if !canEdit && !canViewOnly && !hasReminderSet {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Text("\u{1F514}")
                        .font(.system(size: 18))
                        .foregroundColor(Color(hex: "007AFF"))
                    Text("Reminder Information")
                        .font(.system(size: 18))
                        .fontWeight(.bold)
                        .foregroundColor(Color(hex: "007AFF"))
                }
                Spacer().frame(height: 12)

                if canEdit {
                    Text("Select Reminder:")
                        .font(.system(size: 14))
                        .fontWeight(.bold)
                        .foregroundColor(Color(hex: "6B7280"))
                    Spacer().frame(height: 8)

                    Menu {
                        ForEach(reminderOptions) { option in
                            Button {
                                onSelectReminder(option.label)
                            } label: {
                                Text(option.label)
                                    .font(.system(size: 14))
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedLabel)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                        )
                    }
                }

                if canViewOnly {
                    Text("Current Reminder:")
                        .font(.system(size: 14))
                        .fontWeight(.bold)
                        .foregroundColor(Color(hex: "6B7280"))
                    Spacer().frame(height: 8)
                    Text(selectedLabel)
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "6B7280"))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(hex: "F8F9FA"))
                        .cornerRadius(4)
                }

                if hasReminderSet && selectedLabel != "None" && !(reminderTime ?? "").isEmpty {
                    Spacer().frame(height: 8)
                    Text("Reminder Time:")
                        .font(.system(size: 14))
                        .fontWeight(.bold)
                        .foregroundColor(Color(hex: "4B5563"))
                    Spacer().frame(height: 5)
                    Text(reminderTime ?? "")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "1F2937"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(hex: "EFF6FF"))
                        .cornerRadius(4)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .cornerRadius(15)
            .shadow(color: Color.black.opacity(0.08), radius: 2, y: 1)
        }
    }
}

// MARK: - Feedback Card

private struct FeedbackCard: View {
    let shift: ShiftDto

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text("\u{1F4AC}")
                    .font(.system(size: 18))
                Text("Feedback and Reviews")
                    .font(.system(size: 18))
                    .fontWeight(.bold)
                    .foregroundColor(Color(hex: "007AFF"))
            }
            Spacer().frame(height: 12)

            Text("Manager's Feedback:")
                .font(.system(size: 14))
                .fontWeight(.bold)
                .foregroundColor(Color(hex: "6B7280"))
            Spacer().frame(height: 5)
            Text(shift.feedback)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "6B7280"))
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: "F0F8FF"))
                .cornerRadius(8)

            if !shift.contractorResponseToReview.isEmpty {
                Spacer().frame(height: 12)
                Text("Contractor's Response:")
                    .font(.system(size: 14))
                    .fontWeight(.bold)
                    .foregroundColor(Color(hex: "6B7280"))
                Spacer().frame(height: 5)
                Text(shift.contractorResponseToReview)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "6B7280"))
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(hex: "F0F8FF"))
                    .cornerRadius(8)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.08), radius: 2, y: 1)
    }
}

// MARK: - Action Buttons Section

private struct ActionButtonsSection: View {
    let viewModel: ShiftDetailsViewModel
    let onSendQuote: () -> Void
    let onViewQuotations: () -> Void
    let onSendFeedback: (Int) -> Void

    var body: some View {
        if viewModel.isUpdating {
            HStack {
                Spacer()
                ProgressView()
                Spacer()
            }
            .padding(20)
        } else {
            VStack(spacing: 15) {
                // Send Quote Button (Caregiver)
                if viewModel.quotationButton {
                    ActionButton(text: "Send Quote", bgColor: .black, action: onSendQuote)
                }

                // View Quotations Button (Manager/Admin)
                if viewModel.viewQuotationsButton {
                    ActionButton(text: "View Quotations", bgColor: .black, action: onViewQuotations)
                }

                // Main Action Buttons Row
                HStack(spacing: 10) {
                    if viewModel.startButton {
                        ActionButton(text: "Start", bgColor: .black, action: viewModel.startShift)
                    }
                    if viewModel.endButton {
                        ActionButton(text: "End", bgColor: .black, action: viewModel.endShift)
                    }
                    if viewModel.completeButton {
                        ActionButton(text: "Complete", bgColor: .black, action: viewModel.completeShift)
                    }
                }

                // Secondary Action Buttons Row
                HStack(spacing: 10) {
                    if viewModel.rejectButton {
                        ActionButton(text: "Reject", bgColor: Color(hex: "8B0000"), action: viewModel.rejectShift)
                    }
                    if viewModel.reviewsButton {
                        ActionButton(text: "Reviews", bgColor: .black, action: viewModel.viewReviews)
                    }
                }
            }
        }
    }
}

// MARK: - Action Button

private struct ActionButton: View {
    let text: String
    let bgColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .fontWeight(.bold)
                .font(.system(size: 14))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(bgColor)
                .cornerRadius(20)
        }
    }
}
