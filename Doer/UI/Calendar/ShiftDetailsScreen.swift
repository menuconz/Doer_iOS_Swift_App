import SwiftUI
import UIKit
import CoreLocation
import GoogleNavigation

struct ShiftDetailsScreen: View {
    @Binding var path: NavigationPath
    @State private var viewModel: ShiftDetailsViewModel
    @State private var showDeleteDialog = false
    @State private var toastMessage: String? = nil
    // Skip refresh on the first appearance (init already loaded). Refresh on
    // subsequent appearances — i.e., when returning from feedback/reviews/edit.
    @State private var hasInitiallyAppeared = false
    @State private var boardConfigCache: BoardConfigCache = DIContainer.shared.boardConfigCache

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

                VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 12) {
                        // SECTION 1: Project + Status + Location (combined)
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(shift.projectName.isEmpty ? "Not Set" : shift.projectName)
                                    .font(.system(size: 18)).fontWeight(.bold).foregroundColor(Color(hex: "1F2937"))
                                Spacer()
                                Text(viewModel.statusMessage)
                                    .font(.system(size: 12)).fontWeight(.bold).foregroundColor(.white)
                                    .padding(.horizontal, 10).padding(.vertical, 4)
                                    .background(viewModel.statusColor).cornerRadius(20)
                            }
                            if let clientName = shift.clientName, !clientName.isEmpty {
                                HStack(spacing: 6) {
                                    Text("\u{1F464}").font(.system(size: 14))
                                    Text(clientName).font(.system(size: 14)).foregroundColor(Color(hex: "6B7280"))
                                }
                            }
                            HStack(spacing: 6) {
                                Text("\u{1F4CD}").font(.system(size: 14))
                                Text(shift.address.isEmpty ? "Not Set" : shift.address).font(.system(size: 14)).foregroundColor(Color(hex: "6B7280"))
                            }
                        }
                        .padding(16)
                        .background(Color.white).cornerRadius(15)
                        .shadow(color: .black.opacity(0.08), radius: 2, y: 1)

                        // SECTION 2: Tracking + Navigate + Clock In/Out
                        if viewModel.isTrackingActive && viewModel.isCaregiver {
                            TrackingStatusCard(trackingState: viewModel.trackingState)
                        }

                        if viewModel.showNavigateButton {
                            Button {
                                // Accept T&C before opening navigation (must happen before fullScreenCover)
                                GMSNavigationServices.showTermsAndConditionsDialogIfNeeded(
                                    withCompanyName: "Doer"
                                ) { accepted in
                                    if accepted {
                                        viewModel.showNavigation = true
                                    }
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "location.fill").font(.system(size: 16))
                                    Text("Navigate to Site").fontWeight(.bold).font(.system(size: 16))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity).frame(height: 50)
                                .background(Color(hex: "007AFF")).cornerRadius(12)
                            }
                            .fullScreenCover(isPresented: Binding(
                                get: { viewModel.showNavigation },
                                set: { viewModel.showNavigation = $0 }
                            )) {
                                TurnByTurnNavigationView(
                                    destinationLatitude: shift.latitude ?? 0,
                                    destinationLongitude: shift.longitude ?? 0,
                                    projectName: shift.projectName.isEmpty ? "Site #\(shift.id)" : shift.projectName,
                                    onDismiss: { viewModel.showNavigation = false }
                                )
                                .ignoresSafeArea()
                            }
                        }

                        if viewModel.showMultiSiteWarning {
                            VStack(spacing: 12) {
                                Text("You are currently clocked in at \(viewModel.activeShiftProjectName). Clock out first before clocking in here.")
                                    .font(.system(size: 14)).foregroundColor(Color(hex: "856404"))
                                Button {
                                    viewModel.clockOutOtherShift()
                                } label: {
                                    Text("Clock Out from \(viewModel.activeShiftProjectName)")
                                        .fontWeight(.bold).foregroundColor(.white)
                                        .frame(maxWidth: .infinity).frame(height: 44)
                                        .background(Color.red).cornerRadius(10)
                                }
                            }
                            .padding(16)
                            .background(Color(hex: "FFF3CD")).cornerRadius(15)
                        }

                        if viewModel.showClockInButton || viewModel.showClockOutButton {
                            ClockInOutSection(viewModel: viewModel)
                        }

                        // SECTION 3: People Info
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
                        if viewModel.isAdmin && !viewModel.managerName.isEmpty {
                            InfoCard(icon: "\u{1F464}", title: "Manager Information", rows: [
                                ("\u{1F464}", "Manager Name:", viewModel.managerName),
                                ("\u{1F4E7}", "Manager Email:", viewModel.managerEmail),
                                ("\u{1F4F1}", "Manager Phone:", viewModel.managerPhone)
                            ])
                        }
                        if viewModel.isManager && !viewModel.contractorName.isEmpty {
                            InfoCard(icon: "\u{1F464}", title: "Contractor Information", rows: [
                                ("\u{1F464}", "Name:", viewModel.contractorName),
                                ("\u{1F4E7}", "Email:", viewModel.contractorEmail),
                                ("\u{1F4F1}", "Phone:", viewModel.contractorPhone)
                            ])
                        }

                        // SECTION 4: Schedule
                        DetailCard(icon: "\u{23F0}", title: "Job Schedule") {
                            VStack(spacing: 8) {
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
                        if !shift.instructions.isEmpty {
                            DetailCard(icon: "\u{1F4DD}", title: "Job Description") {
                                Text(shift.instructions).font(.system(size: 14)).foregroundColor(Color(hex: "6B7280")).padding(.leading, 26)
                            }
                        }

                        // SECTION 5: Job Details (combined)
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Text("\u{1F4C4}").font(.system(size: 18))
                                Text("Job Details").font(.system(size: 18)).fontWeight(.bold).foregroundColor(Color(hex: "007AFF"))
                            }
                            HStack { Text("Contract Type").font(.system(size: 14)).fontWeight(.bold).foregroundColor(Color(hex: "6B7280")); Spacer(); Text(viewModel.contractTypeText).font(.system(size: 14)) }
                            HStack { Text("Invoice Status").font(.system(size: 14)).fontWeight(.bold).foregroundColor(Color(hex: "6B7280")); Spacer(); Text(viewModel.invoiceStatusText).font(.system(size: 14)) }
                            if viewModel.showHsForm {
                                HStack {
                                    Text("H&S Forms").font(.system(size: 14)).fontWeight(.bold).foregroundColor(Color(hex: "6B7280"))
                                    Spacer()
                                    Text(viewModel.hsFormText).font(.system(size: 12)).fontWeight(.bold).foregroundColor(.white)
                                        .padding(.horizontal, 10).padding(.vertical, 4).background(viewModel.hsFormColor).cornerRadius(8)
                                }
                            }
                            if viewModel.isAllDayEditable {
                                HStack {
                                    Text("All Day").font(.system(size: 14)).fontWeight(.bold).foregroundColor(Color(hex: "6B7280"))
                                    Spacer()
                                    Toggle("", isOn: Binding(get: { viewModel.isAllDay }, set: { viewModel.updateIsAllDay($0); viewModel.updateShift() })).labelsHidden()
                                }
                            }
                        }
                        .padding(16).background(Color.white).cornerRadius(15)
                        .shadow(color: .black.opacity(0.08), radius: 2, y: 1)

                        // Reminder
                        if viewModel.showReminderSection {
                            ReminderCard(canEdit: viewModel.canEditReminder, canViewOnly: viewModel.canViewReminderOnly, hasReminderSet: viewModel.hasReminderSet, reminderOptions: viewModel.reminderOptions, selectedLabel: viewModel.selectedReminderLabel, reminderTime: viewModel.shift?.reminderTime, onSelectReminder: { label in viewModel.selectReminder(label); viewModel.addReminder() })
                        }

                        // Feedback
                        if viewModel.showFeedback { FeedbackCard(shift: shift) }

                        Spacer().frame(height: 16)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 15)
                }

                // Sticky Bottom Buttons
                ActionButtonsSection(viewModel: viewModel,
                    onSendQuote: { path.append(Route.sendQuote(shiftId: shift.id)) },
                    onViewQuotations: { path.append(Route.viewQuotations(shiftId: shift.id)) },
                    onSendFeedback: { shiftId in path.append(Route.sendFeedback(shiftId: shiftId)) }
                )
                } // End VStack
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
        .onAppear {
            if hasInitiallyAppeared {
                viewModel.refresh()
            } else {
                hasInitiallyAppeared = true
            }
        }
        .onChange(of: boardConfigCache.version) { _, _ in
            viewModel.refresh()
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
        .onChange(of: viewModel.navigateToReviewsShiftId) { _, newValue in
            if let shiftId = newValue {
                viewModel.onReviewsNavigated()
                path.append(Route.reviews(shiftId: shiftId))
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
                if msg == "Shift marked as not completed" || msg == "Shift updated" {
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

    var hasAnyButton: Bool {
        viewModel.quotationButton || viewModel.viewQuotationsButton ||
        viewModel.completeButton || viewModel.markCompleteButton ||
        viewModel.rejectButton || viewModel.reviewsButton || viewModel.isUpdating
    }

    var body: some View {
        if !hasAnyButton { EmptyView() }
        else if viewModel.isUpdating {
            HStack { Spacer(); ProgressView(); Spacer() }
                .padding(12).background(Color.white)
        } else {
            VStack(spacing: 0) {
                Divider()
                HStack(spacing: 10) {
                    if viewModel.quotationButton {
                        ActionButton(text: "Send Quote", bgColor: .black, action: onSendQuote)
                    }
                    if viewModel.viewQuotationsButton {
                        ActionButton(text: "View Quotations", bgColor: .black, action: onViewQuotations)
                    }
                    if viewModel.completeButton {
                        ActionButton(text: "Complete", bgColor: .black, action: viewModel.completeShift)
                    }
                    if viewModel.markCompleteButton {
                        ActionButton(text: "Mark Complete", bgColor: Color(hex: "007AFF"), action: viewModel.markShiftComplete)
                    }
                    if viewModel.rejectButton {
                        ActionButton(text: "Reject", bgColor: Color(hex: "8B0000"), action: viewModel.rejectShift)
                    }
                    if viewModel.reviewsButton {
                        ActionButton(text: "Reviews", bgColor: .black, action: viewModel.viewReviews)
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
            }
            .background(Color.white)
        }
    }
}

// MARK: - Tracking Status Card

private struct TrackingStatusCard: View {
    let trackingState: DoerTrackingState

    var statusColor: Color {
        switch trackingState {
        case .idle: return .gray
        case .clockedIn: return Color(hex: "007AFF")
        case .enRoute: return Color(hex: "3B82F6")
        case .arrived: return Color(hex: "10B981")
        case .onSite: return Color(hex: "00C875")
        case .leaving: return Color(hex: "F59E0B")
        case .clockedOut: return .gray
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Text("\u{1F4E1}").font(.system(size: 18))
                Text("Live Tracking").font(.system(size: 18)).fontWeight(.bold).foregroundColor(Color(hex: "007AFF"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Text("Status:").font(.system(size: 14)).fontWeight(.bold).foregroundColor(Color(hex: "6B7280"))
                Spacer()
                Text(trackingState.label)
                    .font(.system(size: 14)).fontWeight(.bold).foregroundColor(.white)
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(statusColor).cornerRadius(20)
            }

            if trackingState == .leaving {
                Text("Auto clock-out in 5 minutes if you don't return to site")
                    .font(.system(size: 12)).foregroundColor(Color(hex: "F59E0B"))
            }
        }
        .padding(16).background(Color.white).cornerRadius(15)
        .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
    }
}

// MARK: - Clock In/Out Section

private struct ClockInOutSection: View {
    let viewModel: ShiftDetailsViewModel
    @State private var showClockOutDialog = false
    @State private var clockOutReason = ""
    @State private var showForegroundLocationDisclosure = false
    @State private var showBackgroundLocationDisclosure = false
    @State private var hasBackgroundLocation = (CLLocationManager().authorizationStatus == .authorizedAlways)
    @State private var pendingBackgroundPrompt = false
    @State private var locationFetcher = OneShotLocationFetcher()

    private func performClockIn() {
        locationFetcher.fetch { loc in
            viewModel.clockInWithTracking(
                latitude: loc?.coordinate.latitude ?? 0,
                longitude: loc?.coordinate.longitude ?? 0
            )
        }
    }

    private func refreshPermissionState() {
        hasBackgroundLocation = locationFetcher.authorizationStatus == .authorizedAlways
    }

    private func handleClockInTapped() {
        let status = locationFetcher.authorizationStatus
        switch status {
        case .notDetermined:
            // First time — show disclosure before system prompt
            showForegroundLocationDisclosure = true
        case .authorizedWhenInUse:
            // Have foreground — show background disclosure before upgrading
            showBackgroundLocationDisclosure = true
        case .authorizedAlways:
            performClockIn()
        case .denied, .restricted:
            // User denied — still allow clock in, but tracking will be limited
            performClockIn()
        @unknown default:
            performClockIn()
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("\u{23F1}\u{FE0F}").font(.system(size: 18))
                Text("Clock In / Out").font(.system(size: 18)).fontWeight(.bold).foregroundColor(Color(hex: "007AFF"))
            }

            if viewModel.showClockInButton {
                Text("Where are you clocking in?").font(.system(size: 14)).fontWeight(.bold).foregroundColor(Color(hex: "6B7280"))

                // Location type chips
                HStack(spacing: 8) {
                    ForEach([ClockLocationType.site, .yard, .office], id: \.rawValue) { type in
                        let label = type == .site ? "Site" : type == .yard ? "Yard" : "Office"
                        let isSelected = viewModel.selectedClockLocationType == type
                        Button { viewModel.selectedClockLocationType = type } label: {
                            Text(label).font(.system(size: 14)).fontWeight(.bold)
                                .foregroundColor(isSelected ? .white : Color(hex: "007AFF"))
                                .padding(.horizontal, 16).padding(.vertical, 8)
                                .background(isSelected ? Color(hex: "007AFF") : Color(hex: "007AFF").opacity(0.1))
                                .cornerRadius(20)
                        }
                    }
                }

                // Stage picker
                if !viewModel.availableStages.isEmpty {
                    Text("Select Stage:").font(.system(size: 14)).fontWeight(.bold).foregroundColor(Color(hex: "6B7280"))
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(viewModel.availableStages, id: \.id) { stage in
                                let isSelected = viewModel.selectedStageName == stage.subitem
                                Button { viewModel.selectedStageName = stage.subitem } label: {
                                    Text(stage.subitem).font(.system(size: 12)).fontWeight(.bold)
                                        .foregroundColor(isSelected ? .white : Color(hex: "8B5CF6"))
                                        .padding(.horizontal, 12).padding(.vertical, 8)
                                        .background(isSelected ? Color(hex: "8B5CF6") : Color(hex: "8B5CF6").opacity(0.1))
                                        .cornerRadius(20)
                                }
                            }
                        }
                    }
                }

                // Background location warning banner
                if !hasBackgroundLocation {
                    Button { showBackgroundLocationDisclosure = true } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(Color(hex: "B25E02"))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Background location is off")
                                    .font(.system(size: 14)).fontWeight(.bold)
                                    .foregroundColor(Color(hex: "663900"))
                                Text("Doer can't track your shift when the phone is locked or you're in another app. Tap to enable \"Always\".")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "663900"))
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer()
                        }
                        .padding(12)
                        .background(Color(hex: "FFF4E5"))
                        .cornerRadius(12)
                    }
                }

                // Clock In button
                Button {
                    handleClockInTapped()
                } label: {
                    Text("Clock In").fontWeight(.bold).font(.system(size: 16)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .background(Color(hex: "00C875")).cornerRadius(12)
                }
            }

            if viewModel.showClockOutButton {
                Button { showClockOutDialog = true } label: {
                    Text("Clock Out").fontWeight(.bold).font(.system(size: 16)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .background(Color.red).cornerRadius(12)
                }
                .alert("Clock Out", isPresented: $showClockOutDialog) {
                    TextField("Reason (optional)", text: $clockOutReason)
                    Button("Clock Out", role: .destructive) {
                        let reason = clockOutReason.isEmpty ? nil : clockOutReason
                        locationFetcher.fetch { loc in
                            viewModel.clockOutWithTracking(
                                latitude: loc?.coordinate.latitude ?? 0,
                                longitude: loc?.coordinate.longitude ?? 0,
                                reasonCode: reason
                            )
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Are you sure you want to clock out?")
                }
            }
        }
        .padding(16).background(Color.white).cornerRadius(15)
        .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
        .onAppear { refreshPermissionState() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            refreshPermissionState()
            if pendingBackgroundPrompt {
                pendingBackgroundPrompt = false
                let status = locationFetcher.authorizationStatus
                switch status {
                case .authorizedWhenInUse:
                    showBackgroundLocationDisclosure = true
                case .authorizedAlways:
                    performClockIn()
                default:
                    performClockIn()
                }
            }
        }
        .alert("Location access required", isPresented: $showForegroundLocationDisclosure) {
            Button("Continue") {
                // Request When-In-Use; when iOS dialog closes, didBecomeActive fires
                // and we show the Always-upgrade dialog.
                pendingBackgroundPrompt = true
                locationFetcher.requestWhenInUseAuthorization()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Doer collects location data to track your shift, record the route to the job site, enable turn-by-turn navigation, and automatically clock you in and out via geofences at customer sites.\n\nLocation is used only while you are clocked in. A persistent indicator will show while tracking, and tracking stops as soon as you clock out.")
        }
        .alert("Allow background location", isPresented: $showBackgroundLocationDisclosure) {
            Button("Continue") {
                locationFetcher.requestAlwaysAuthorization()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    refreshPermissionState()
                    performClockIn()
                }
            }
            Button("Not now", role: .cancel) {
                performClockIn()
            }
        } message: {
            Text("To keep tracking your shift accurately when the phone is locked or you are using another app, Doer needs permission to access location in the background.\n\nOn the next screen, please choose \"Change to Always Allow\".\n\nBackground tracking runs only while you are clocked in and stops the moment you clock out.")
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
                .padding(.horizontal, 16)
                .frame(height: 40)
                .background(bgColor)
                .cornerRadius(20)
        }
    }
}

// MARK: - One-shot location fetcher
//
// CLLocationManager only populates `.location` after `requestLocation()` /
// `startUpdatingLocation()`; without this, clock-in/out always sent (0, 0).
// Hands back a fresh fix (or the most recent one if it times out).
private final class OneShotLocationFetcher: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var pending: ((CLLocation?) -> Void)?
    private var timeoutWorkItem: DispatchWorkItem?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    var authorizationStatus: CLAuthorizationStatus { manager.authorizationStatus }

    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func requestAlwaysAuthorization() {
        manager.requestAlwaysAuthorization()
    }

    func fetch(timeout: TimeInterval = 6, completion: @escaping (CLLocation?) -> Void) {
        let status = manager.authorizationStatus
        guard status == .authorizedAlways || status == .authorizedWhenInUse else {
            completion(nil)
            return
        }
        if let cached = manager.location, Date().timeIntervalSince(cached.timestamp) < 30 {
            completion(cached)
            return
        }
        if let prev = pending {
            prev(nil)
        }
        pending = completion
        timeoutWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self = self, let cb = self.pending else { return }
            self.pending = nil
            cb(self.manager.location)
        }
        timeoutWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: item)
        manager.requestLocation()
    }

    // MARK: CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let cb = pending else { return }
        pending = nil
        timeoutWorkItem?.cancel()
        cb(locations.last)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("OneShotLocationFetcher error: \(error.localizedDescription)")
        guard let cb = pending else { return }
        pending = nil
        timeoutWorkItem?.cancel()
        cb(manager.location)
    }
}
