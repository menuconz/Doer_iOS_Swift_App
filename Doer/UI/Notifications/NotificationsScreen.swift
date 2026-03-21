import SwiftUI

private let UnreadBg = Color(hex: "#FFF9C4")
private let ReadBg = Color.white
private let UnreadDotColor = Color.red
private let GrayText = Color(hex: "#757575")
private let TimeColor = Color(hex: "#9E9E9E")
private let DateHeaderColor = Color(hex: "#424242")
private let DateHeaderBg = Color(hex: "#F8F9FA")
private let TitleColor = Color(hex: "#212121")

struct NotificationsScreen: View {
    var onBack: () -> Void
    var onNavigateToShift: (String, Int) -> Void
    var onNavigateToMessages: (Int) -> Void

    @State private var viewModel = NotificationsViewModel()

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                if viewModel.groups.isEmpty {
                    ScrollView {
                        VStack(spacing: 4) {
                            Spacer().frame(height: 80)
                            Text("\u{1F514}").font(.system(size: 64)).padding(.bottom, 16)
                            Text("No notifications yet").font(.system(size: 18)).foregroundColor(TimeColor)
                            Text("Pull down to refresh").font(.system(size: 14)).foregroundColor(Color(hex: "#CCCCCC"))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .refreshable { viewModel.refresh() }
                } else {
                    List {
                        ForEach(viewModel.groups) { group in
                            Section {
                                ForEach(group.notifications, id: \.id) { notification in
                                    NotificationCard(
                                        notification: notification,
                                        formattedTime: viewModel.formatTime(notification.sentAt),
                                        onClick: { viewModel.onNotificationTapped(notification) }
                                    )
                                    .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                                    .listRowSeparator(.hidden)
                                }
                            } header: {
                                Text(group.dateLabel)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(DateHeaderColor)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 4)
                                    .background(DateHeaderBg)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .refreshable { viewModel.refresh() }
                }
            }
        }
        .background(Color.white)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .onAppear { viewModel.loadInitialData() }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: onBack) { Image(systemName: "chevron.left") }
            }
        }
        .onChange(of: viewModel.navigateToShift?.1) { _, shiftId in
            if let nav = viewModel.navigateToShift {
                onNavigateToShift(nav.0, nav.1)
                viewModel.clearNavigation()
            }
        }
        .onChange(of: viewModel.navigateToMessages) { _, shiftId in
            if let id = shiftId {
                onNavigateToMessages(id)
                viewModel.clearNavigation()
            }
        }
        .snackbar(message: Binding(
            get: { viewModel.errorMessage },
            set: { _ in viewModel.clearError() }
        ))
    }
}

// MARK: - Notification Card
private struct NotificationCard: View {
    let notification: NotificationsDto
    let formattedTime: String
    let onClick: () -> Void

    var body: some View {
        Button(action: onClick) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Text(notification.title)
                        .font(.system(size: 16, weight: notification.isRead ? .regular : .bold))
                        .foregroundColor(TitleColor)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if !notification.isRead {
                        Circle()
                            .fill(UnreadDotColor)
                            .frame(width: 8, height: 8)
                            .padding(.leading, 8)
                    }
                }

                if !notification.body.isEmpty {
                    Text(notification.body)
                        .font(.system(size: 14))
                        .foregroundColor(GrayText)
                        .lineSpacing(4)
                        .padding(.top, 4)
                }

                HStack(spacing: 0) {
                    Text(formattedTime)
                        .font(.system(size: 12))
                        .foregroundColor(TimeColor)

                    if !notification.projectName.isEmpty {
                        Text(" \u{2022} ")
                            .font(.system(size: 12))
                            .foregroundColor(TimeColor)
                        Text(notification.projectName)
                            .font(.system(size: 12))
                            .foregroundColor(TimeColor)
                            .lineLimit(1)
                    }
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(notification.isRead ? ReadBg : UnreadBg)
        .cornerRadius(8)
        .shadow(radius: 1)
    }
}
