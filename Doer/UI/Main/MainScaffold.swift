import SwiftUI

struct DrawerMenuItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let route: Route
    var requiresAdmin: Bool = false
    var requiresManager: Bool = false
}

struct DrawerContent: View {
    let prefs: PreferencesManager
    let onNavigate: (Route) -> Void
    let onLogout: () -> Void

    // Observe the cache so the board name in the drawer updates when admin renames it.
    @State private var cache: BoardConfigCache = DIContainer.shared.boardConfigCache

    var body: some View {
        let menuItems = buildMenuItems()

        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Image("doerlogoheader")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 60)

                Text(prefs.fullName)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text(prefs.email)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(24)
            .frame(maxWidth: .infinity)

            Divider().background(Color.white.opacity(0.3))

            // Menu items
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(menuItems) { item in
                        DrawerItemView(item: item) {
                            onNavigate(item.route)
                        }
                    }
                }
            }

            Spacer()

            Divider().background(Color.white.opacity(0.3))

            // Logout
            DrawerItemView(
                item: DrawerMenuItem(title: "Logout", icon: "rectangle.portrait.and.arrow.right", route: .login)
            ) {
                onLogout()
            }
            .padding(.bottom, 16)
        }
        .frame(width: 280)
        .background(DoerTheme.primary)
    }

    private func buildMenuItems() -> [DrawerMenuItem] {
        var items: [DrawerMenuItem] = []
        items.append(DrawerMenuItem(title: "Home", icon: "house", route: .calendar))
        // Use cached board name so admin renames reflect here. Falls back to "NZ Mahi 2026".
        let boardName = cache.boardName(default: "NZ Mahi 2026")
        items.append(DrawerMenuItem(title: boardName, icon: "briefcase", route: .mainLeadsJobs))

        if prefs.isAdmin {
            items.append(DrawerMenuItem(title: "New Leads", icon: "chart.bar", route: .newLeads, requiresAdmin: true))
            items.append(DrawerMenuItem(title: "Quoted Leads", icon: "chart.bar", route: .quotedLeads, requiresAdmin: true))
            items.append(DrawerMenuItem(title: "Contacted Leads", icon: "chart.bar", route: .contactedLeads, requiresAdmin: true))
            items.append(DrawerMenuItem(title: "Clients", icon: "person.2", route: .clients, requiresAdmin: true))
            items.append(DrawerMenuItem(title: "FiloKreto Team", icon: "person.3", route: .filoKretoTeam, requiresAdmin: true))
        }

        if prefs.isAdmin || prefs.isManager {
            items.append(DrawerMenuItem(title: "Live Tracking", icon: "location.fill", route: .liveTracking, requiresManager: true))
            items.append(DrawerMenuItem(title: "Time Tracking", icon: "clock", route: .timeTracking, requiresManager: true))
            items.append(DrawerMenuItem(title: "Contractors", icon: "person.3", route: .allContractors, requiresManager: true))
            items.append(DrawerMenuItem(title: "Board Settings", icon: "slider.horizontal.3", route: .boardSettings, requiresManager: true))
            items.append(DrawerMenuItem(title: "Activity Log", icon: "clock.arrow.circlepath", route: .activityLog, requiresManager: true))
        }

        items.append(DrawerMenuItem(title: "Profile", icon: "person", route: .profile))

        return items
    }
}

struct DrawerItemView: View {
    let item: DrawerMenuItem
    let onClick: () -> Void

    var body: some View {
        Button(action: onClick) {
            HStack(spacing: 16) {
                Image(systemName: item.icon)
                    .frame(width: 24, height: 24)
                    .foregroundColor(.white)

                Text(item.title)
                    .font(.body)
                    .foregroundColor(.white)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
    }
}
