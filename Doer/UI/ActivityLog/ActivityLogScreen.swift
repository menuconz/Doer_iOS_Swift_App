import SwiftUI

struct ActivityLogScreen: View {
    @State private var viewModel = ActivityLogViewModel()
    @State private var hasLoaded = false
    @State private var showEntityMenu = false
    @State private var showActionMenu = false

    var body: some View {
        ZStack {
            Color(red: 0.96, green: 0.97, blue: 0.98).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 8) {
                // Filter row
                HStack(spacing: 6) {
                    Menu {
                        ForEach(ActivityLogViewModel.entityTypes, id: \.label) { item in
                            Button(item.label) { viewModel.setEntityTypeFilter(item.value) }
                        }
                    } label: {
                        FilterChipLabel(text: "Type: \(currentEntityLabel())")
                    }

                    Menu {
                        ForEach(ActivityLogViewModel.actions, id: \.label) { item in
                            Button(item.label) { viewModel.setActionFilter(item.value) }
                        }
                    } label: {
                        FilterChipLabel(text: "Action: \(currentActionLabel())")
                    }

                    Spacer()
                    Text("\(viewModel.totalCount) entries")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 12)

                Button("Clear filters") { viewModel.clearFilters() }
                    .font(.caption)
                    .foregroundColor(Color(red: 0.10, green: 0.46, blue: 0.82))
                    .padding(.horizontal, 12)

                if viewModel.logs.isEmpty && !viewModel.isLoading {
                    Spacer()
                    Text("No activity yet").foregroundColor(.gray)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(viewModel.logs) { log in
                                ActivityLogCardView(log: log)
                                    .onAppear {
                                        if log.id == viewModel.logs.last?.id {
                                            viewModel.loadMore()
                                        }
                                    }
                            }
                            if viewModel.isLoading {
                                ProgressView().padding()
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                }
            }
            .padding(.top, 8)
        }
        .navigationTitle("Activity Log")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !hasLoaded {
                hasLoaded = true
                viewModel.loadFirstPage()
            }
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { _ in viewModel.clearError() }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private func currentEntityLabel() -> String {
        ActivityLogViewModel.entityTypes.first { $0.value == viewModel.entityTypeFilter }?.label ?? "All"
    }

    private func currentActionLabel() -> String {
        ActivityLogViewModel.actions.first { $0.value == viewModel.actionFilter }?.label ?? "All"
    }
}

private struct FilterChipLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Color.white)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.gray.opacity(0.3), lineWidth: 1))
            .foregroundColor(Color(red: 0.07, green: 0.09, blue: 0.15))
    }
}

private struct ActivityLogCardView: View {
    let log: ActivityLogDto

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                actionBadge
                Spacer()
                Text(formatTimestamp(log.timestamp))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            // User rows have entityId=0 (AppUser.Id is a string GUID, stored separately).
            // Skip the #0 in that case.
            Text({
                let head = (log.entityType.lowercased() == "user" || log.entityId == 0)
                    ? log.entityType
                    : "\(log.entityType) #\(log.entityId)"
                let suffix = log.fieldName.flatMap { $0.isEmpty ? nil : " · \($0)" } ?? ""
                return head + suffix
            }())
                .font(.subheadline.weight(.semibold))
                .foregroundColor(Color(red: 0.07, green: 0.09, blue: 0.15))

            if let desc = log.description, !desc.isEmpty {
                Text(desc).font(.footnote).foregroundColor(Color(red: 0.22, green: 0.25, blue: 0.31))
            } else if (log.oldValue?.isEmpty == false) || (log.newValue?.isEmpty == false) {
                Text("From: \(log.oldValue ?? "—") → To: \(log.newValue ?? "—")")
                    .font(.footnote).foregroundColor(Color(red: 0.22, green: 0.25, blue: 0.31))
            }

            if !log.userName.isEmpty {
                Text("by \(log.userName)").font(.caption2).foregroundColor(.gray)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var actionBadge: some View {
        let color: Color = {
            switch log.action {
            case "Created":       return Color(red: 0.0, green: 0.78, blue: 0.46)
            case "Deleted":       return Color(red: 0.94, green: 0.27, blue: 0.27)
            case "RoleChanged":   return Color(red: 0.62, green: 0.31, blue: 0.87)
            case "StatusChanged": return Color(red: 1.0,  green: 0.43, blue: 0.23)
            default:              return Color(red: 0.10, green: 0.46, blue: 0.82) // Updated
            }
        }()
        return Text(log.action)
            .font(.caption2.weight(.bold))
            .foregroundColor(color)
            .padding(.horizontal, 8).padding(.vertical, 2)
            .background(color.opacity(0.15))
            .overlay(Capsule().stroke(color, lineWidth: 1))
            .clipShape(Capsule())
    }

    private func formatTimestamp(_ raw: String) -> String {
        if raw.isEmpty { return "" }
        let parsers: [DateFormatter] = [
            { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"; f.locale = Locale(identifier: "en_US_POSIX"); return f }(),
            { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSS"; f.locale = Locale(identifier: "en_US_POSIX"); return f }(),
            { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"; f.locale = Locale(identifier: "en_US_POSIX"); return f }()
        ]
        let cleaned = raw.replacingOccurrences(of: "Z", with: "")
        for f in parsers {
            if let d = f.date(from: cleaned) {
                let out = DateFormatter()
                out.dateFormat = "dd MMM yyyy, h:mm a"
                out.locale = Locale(identifier: "en_US")
                return out.string(from: d)
            }
        }
        return raw
    }
}
