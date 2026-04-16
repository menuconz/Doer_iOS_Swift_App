import SwiftUI

struct TimeTrackingDashboardView: View {
    @StateObject private var viewModel = TimeTrackingDashboardViewModel()
    let onOpenDrawer: () -> Void
    @State private var showDatePicker = false

    private let displayDateFormat: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd MMM yyyy"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            // Top Bar
            HStack {
                Button(action: onOpenDrawer) {
                    Image(systemName: "line.3.horizontal").foregroundColor(.white).font(.title2)
                }
                Text("Time Tracking").font(.headline).foregroundColor(.white)
                Spacer()
                Button(action: { viewModel.refresh() }) {
                    Image(systemName: "arrow.clockwise").foregroundColor(.white)
                }
            }
            .padding()
            .background(DoerTheme.primary)

            // Date Picker Row
            HStack {
                Text("Date").font(.subheadline).fontWeight(.bold).foregroundColor(.gray)
                Spacer()
                Button(action: { showDatePicker.toggle() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar").foregroundColor(DoerTheme.primary)
                        Text(displayDateFormat.string(from: viewModel.selectedDate))
                            .font(.subheadline).fontWeight(.bold).foregroundColor(DoerTheme.primary)
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Color.white)

            if showDatePicker {
                DatePicker("", selection: Binding(get: { viewModel.selectedDate },
                    set: { viewModel.selectDate($0); showDatePicker = false }),
                    displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding(.horizontal)
                    .background(Color.white)
            }

            // Summary Stats
            HStack(spacing: 24) {
                SummaryStatView(label: "Sites", value: "\(viewModel.totalSites)", color: DoerTheme.primary)
                SummaryStatView(label: "Contractors", value: "\(viewModel.totalDoers)", color: .purple)
                SummaryStatView(label: "Hours", value: formatHoursAndMinutes(viewModel.totalHours), color: .green)
                if viewModel.alertCount > 0 {
                    SummaryStatView(label: "Alerts", value: "\(viewModel.alertCount)", color: .red)
                }
            }
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(Color.white)

            // Content
            if viewModel.isLoading && viewModel.sites.isEmpty {
                Spacer()
                ProgressView()
                Spacer()
            } else if viewModel.sites.isEmpty {
                Spacer()
                Text("No site data for this date").foregroundColor(.gray)
                Text("Select a different date").font(.caption).foregroundColor(.gray.opacity(0.5))
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.sites) { site in
                            SiteHoursCardView(site: site,
                                onToggle: { viewModel.toggleExpanded(site.shiftId) },
                                onEditDoer: { doer in
                                    viewModel.editClockIn = String(doer.clockInTime.suffix(8).prefix(5))
                                    viewModel.editClockOut = doer.clockOutTime.isEmpty ? "" : String(doer.clockOutTime.suffix(8).prefix(5))
                                    viewModel.editReason = ""
                                    viewModel.editingDoer = doer
                                },
                                onToggleDoer: { shiftId, userId in
                                    viewModel.toggleDoerExpanded(shiftId: shiftId, userId: userId)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                }
            }
        }
        .background(Color(hex: "F8F9FA"))
        .navigationBarHidden(true)
        .sheet(item: $viewModel.editingDoer) { doer in
            EditTimeEntrySheet(
                doerName: doer.displayName.isEmpty ? "Doer \(doer.userId.prefix(6))" : doer.displayName,
                clockIn: $viewModel.editClockIn,
                clockOut: $viewModel.editClockOut,
                reason: $viewModel.editReason,
                onSave: { viewModel.editTimeEntry() },
                onCancel: { viewModel.editingDoer = nil }
            )
            .presentationDetents([.medium])
        }
    }
}

// MARK: - Site Card

struct SiteHoursCardView: View {
    let site: SiteHoursUi
    let onToggle: () -> Void
    let onEditDoer: (DoerHoursUi) -> Void
    let onToggleDoer: (Int, String) -> Void

    var thresholdColor: Color {
        if site.isOverThreshold { return .red }
        if site.isApproachingThreshold { return .orange }
        return .green
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(thresholdColor.opacity(0.12))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Group {
                                if site.isOverThreshold {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                } else {
                                    Text(site.totalHoursFormatted)
                                        .font(.caption2).fontWeight(.bold).foregroundColor(thresholdColor)
                                }
                            }
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(site.projectName.isEmpty ? "Site #\(site.shiftId)" : site.projectName)
                            .font(.subheadline).fontWeight(.bold).foregroundColor(Color(hex: "1F2937"))
                        if !site.clientName.isEmpty {
                            Text(site.clientName).font(.caption).foregroundColor(.gray)
                        }
                        HStack(spacing: 6) {
                            Text("\(site.doerCount) doers").font(.caption).foregroundColor(.gray)
                            Text("•").font(.caption2).foregroundColor(.gray)
                            Text(site.totalHoursFormatted).font(.caption).fontWeight(.bold).foregroundColor(thresholdColor)
                            if !site.stages.isEmpty {
                                Text("•").font(.caption2).foregroundColor(.gray)
                                Text("\(site.stages.count) stages").font(.caption).foregroundColor(.gray)
                            }
                        }
                    }
                    Spacer()
                    Image(systemName: site.isExpanded ? "chevron.up" : "chevron.down").foregroundColor(.gray)
                }
                .padding(14)
            }
            .buttonStyle(PlainButtonStyle())

            // Expanded Content
            if site.isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    if !site.address.isEmpty {
                        Text(site.address).font(.caption).foregroundColor(.gray)
                    }
                    if !site.stages.isEmpty {
                        Text("Stages").font(.subheadline).fontWeight(.bold).foregroundColor(DoerTheme.primary)
                        ForEach(site.stages, id: \.stageName) { stage in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(stage.stageName.isEmpty ? "General" : stage.stageName).font(.caption).fontWeight(.medium)
                                    Text("\(stage.doerCount) doers").font(.caption2).foregroundColor(.gray)
                                }
                                Spacer()
                                let h = Int(stage.totalHours); let m = Int((stage.totalHours - Double(h)) * 60)
                                Text("\(h)h \(m)m").font(.caption).fontWeight(.bold).foregroundColor(DoerTheme.primary)
                            }
                            .padding(10)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    Divider()
                    Text("Contractor Hours").font(.subheadline).fontWeight(.bold).foregroundColor(DoerTheme.primary)
                    ForEach(site.doerHours) { doer in
                        DoerHoursRowView(
                            doer: doer,
                            onEdit: { onEditDoer(doer) },
                            onToggleExpand: { onToggleDoer(site.shiftId, doer.userId) }
                        )
                    }
                }
                .padding(14)
                .background(Color(hex: "F8F9FA"))
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
}

// MARK: - Doer Hours Row

struct DoerHoursRowView: View {
    let doer: DoerHoursUi
    let onEdit: () -> Void
    let onToggleExpand: () -> Void

    var hoursColor: Color {
        if doer.isOverThreshold { return .red }
        if doer.totalHours >= 11 { return .orange }
        return .green
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Circle().fill(hoursColor.opacity(0.12)).frame(width: 32, height: 32)
                    .overlay(Image(systemName: "person.fill").foregroundColor(hoursColor).font(.caption))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(doer.displayName.isEmpty ? "Doer \(doer.userId.prefix(6))" : doer.displayName)
                            .font(.caption).fontWeight(.bold).foregroundColor(Color(hex: "1F2937"))
                            .lineLimit(1)
                        if doer.isActive {
                            Circle().fill(.green).frame(width: 8, height: 8)
                        }
                        if doer.isOverThreshold {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red).font(.caption2)
                        }
                    }
                    if !doer.stage.isEmpty {
                        Text(doer.stage).font(.caption2).foregroundColor(.gray).lineLimit(1)
                    }
                    if doer.sessions.count > 1 {
                        let distinctDays = Set(doer.sessions.map { $0.date }).count
                        Text("\(doer.sessions.count) sessions across \(distinctDays) " +
                             (distinctDays == 1 ? "day" : "days"))
                            .font(.caption2).foregroundColor(.gray)
                    } else if !doer.clockInTime.isEmpty || !doer.clockOutTime.isEmpty {
                        HStack(spacing: 6) {
                            if !doer.clockInTime.isEmpty {
                                Text("In: \(String(doer.clockInTime.suffix(8).prefix(5)))").font(.caption2).foregroundColor(.gray)
                            }
                            if !doer.clockInTime.isEmpty && !doer.clockOutTime.isEmpty {
                                Text("•").font(.caption2).foregroundColor(.gray)
                            }
                            if !doer.clockOutTime.isEmpty {
                                Text("Out: \(String(doer.clockOutTime.suffix(8).prefix(5)))").font(.caption2).foregroundColor(.gray)
                            }
                        }
                    }
                }
                Spacer()

                Button(action: onEdit) {
                    Image(systemName: "pencil").foregroundColor(.gray).font(.caption)
                }

                Text(doer.totalHoursFormatted)
                    .font(.caption).fontWeight(.bold).foregroundColor(hoursColor)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(hoursColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                if !doer.sessions.isEmpty {
                    Image(systemName: doer.isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.gray).font(.caption)
                }
            }
            .padding(10)
            .contentShape(Rectangle())
            .onTapGesture { onToggleExpand() }

            if doer.isExpanded && !doer.sessions.isEmpty {
                VStack(spacing: 4) {
                    ForEach(doer.sessions) { session in
                        SessionRowView(session: session)
                    }
                }
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(Color(hex: "F8F9FA"))
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct SessionRowView: View {
    let session: SessionUi

    var body: some View {
        HStack {
            Text(session.displayDate)
                .font(.caption2).fontWeight(.medium)
                .foregroundColor(Color(hex: "1F2937"))
                .frame(width: 90, alignment: .leading)
            Text(session.clockOutTime.isEmpty
                 ? "In: \(session.clockInTime) • Out: —"
                 : "In: \(session.clockInTime) • Out: \(session.clockOutTime)")
                .font(.caption2).foregroundColor(.gray)
            Spacer()
            if session.isActive {
                Circle().fill(.green).frame(width: 6, height: 6)
            }
            Text(session.hoursFormatted)
                .font(.caption2).fontWeight(.bold)
                .foregroundColor(Color(hex: "1F2937"))
        }
    }
}

// MARK: - Summary Stat

struct SummaryStatView: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack {
            Text(value)
                .font(value.count > 4 ? .subheadline : .title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(label).font(.caption2).foregroundColor(.gray)
        }
    }
}

/// Formats total hours as "Xh Ym" (e.g. 0.5 → "0h 30m", 48 → "48h 0m").
/// Multi-day totals stay in hours rather than being split into days.
private func formatHoursAndMinutes(_ totalHours: Double) -> String {
    let totalMinutes = Int(totalHours * 60)
    let hours = totalMinutes / 60
    let minutes = totalMinutes % 60
    return "\(hours)h \(minutes)m"
}

// MARK: - Edit Sheet

struct EditTimeEntrySheet: View {
    let doerName: String
    @Binding var clockIn: String
    @Binding var clockOut: String
    @Binding var reason: String
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Editing: \(doerName)")) {
                    TextField("Clock-In Time (HH:mm)", text: $clockIn)
                    TextField("Clock-Out Time (HH:mm)", text: $clockOut)
                    TextField("Reason (required)", text: $reason)
                }
            }
            .navigationTitle("Edit Time Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: onSave)
                        .disabled(reason.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
