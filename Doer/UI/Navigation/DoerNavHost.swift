import SwiftUI

struct DoerNavHost: View {
    @State private var path = NavigationPath()
    @State private var showDrawer = false
    @State private var isLoggedIn: Bool? = nil
    @State private var unreadNotificationCount = 0

    private let prefs = PreferencesManager.shared
    private let secureStorage = SecureStorageManager.shared
    private let shiftRepo = DIContainer.shared.shiftRepository

    var body: some View {
        ZStack {
            if let loggedIn = isLoggedIn {
                if loggedIn {
                    mainContent
                } else {
                    authContent
                }
            } else {
                LoadingScreen(
                    onLoggedIn: { isLoggedIn = true },
                    onNotLoggedIn: { isLoggedIn = false }
                )
            }
        }
    }

    // MARK: - Auth Flow
    private var authContent: some View {
        NavigationStack(path: $path) {
            LoginScreen(
                onLoginSuccess: {
                    isLoggedIn = true
                    path = NavigationPath()
                },
                onForgotPassword: { path.append(Route.forgotPassword) },
                onRegisterContractor: { path.append(Route.registerContractor) },
                onRegisterManager: { path.append(Route.registerRestHome) }
            )
            .navigationBarHidden(true)
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .registerContractor:
                    RegisterContractorScreen(
                        onBack: { path.removeLast() },
                        onSuccess: { path = NavigationPath() }
                    )
                case .registerRestHome:
                    RegisterManagerScreen(
                        onBack: { path.removeLast() },
                        onSuccess: { path = NavigationPath() }
                    )
                case .forgotPassword:
                    ForgotPasswordScreen(
                        onBack: { path.removeLast() },
                        onResetSuccess: { path = NavigationPath() }
                    )
                case .generateOTP(let email):
                    GenerateOTPScreen(
                        onBack: { path.removeLast() },
                        onSuccess: { _ in path.append(Route.forgotPassword) }
                    )
                default:
                    EmptyView()
                }
            }
        }
    }

    // MARK: - Main App Content
    private var mainContent: some View {
        ZStack(alignment: .leading) {
            NavigationStack(path: $path) {
                calendarWithToolbar
                    .navigationDestination(for: Route.self) { route in
                        destinationView(for: route)
                    }
            }
            .tint(.white)

            // Drawer overlay
            if showDrawer {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation { showDrawer = false } }

                DrawerContent(
                    prefs: prefs,
                    onNavigate: { route in
                        withAnimation { showDrawer = false }
                        var newPath = NavigationPath()
                        if route != .calendar {
                            newPath.append(route)
                        }
                        path = newPath
                    },
                    onLogout: {
                        withAnimation { showDrawer = false }
                        doLogout()
                    }
                )
                .transition(.move(edge: .leading))
            }
        }
    }

    // MARK: - Calendar with Toolbar
    private var calendarWithToolbar: some View {
        CalendarScreen(path: $path)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    withAnimation { showDrawer.toggle() }
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .foregroundColor(.white)
                }
            }
            ToolbarItem(placement: .principal) {
                Text("Home")
                    .foregroundColor(.white)
                    .fontWeight(.semibold)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    path.append(Route.notifications)
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell")
                            .foregroundColor(.white)
                        if unreadNotificationCount > 0 {
                            Text(unreadNotificationCount > 99 ? "99+" : "\(unreadNotificationCount)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(3)
                                .background(Color(hex: "#FF3B30"))
                                .clipShape(Circle())
                                .offset(x: 8, y: -8)
                        }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(DoerTheme.primary, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            await loadUnreadCount()
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToNotifications)) { _ in
            path = NavigationPath()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                path.append(Route.notifications)
            }
        }
    }

    // MARK: - Route Destination
    @ViewBuilder
    private func destinationView(for route: Route) -> some View {
        switch route {
        // Calendar
        case .dayTimeline(let date):
            DayTimelineScreen(path: $path, date: date)
        case .dayDetail(let date, let shiftId):
            DayDetailScreen(path: $path, date: date, shiftId: shiftId)
        case .shiftDetails(let shiftId):
            ShiftDetailsScreen(path: $path, shiftId: shiftId)
        case .addShift(let date, let hour):
            AddShiftScreen(path: $path, date: date, hour: hour)
        case .editShift:
            AddShiftScreen(path: $path)

        // Files
        case .shiftFiles(let shiftId):
            ShiftFilesScreen(
                shiftId: String(shiftId),
                onBack: { path.removeLast() },
                onViewDocument: { fileUrl, isImage in path.append(Route.viewDocument(fileUrl: fileUrl, isImage: isImage)) }
            )
        case .subItemFiles(let shiftId, let subItemId):
            SubItemFilesScreen(
                shiftId: String(shiftId),
                subItemId: String(subItemId),
                onBack: { path.removeLast() },
                onViewDocument: { fileUrl, isImage in path.append(Route.viewDocument(fileUrl: fileUrl, isImage: isImage)) }
            )
        case .viewDocument(let fileUrl, let isImage):
            ViewDocumentScreen(fileUrl: fileUrl, isImage: isImage, onBack: { path.removeLast() })
        case .viewEmailDocument(let fileUrl):
            ViewEmailDocumentScreen(fileUrl: fileUrl, onBack: { path.removeLast() })

        // Messages
        case .emailMessages(let shiftId):
            MessagesScreen(
                shiftId: shiftId,
                onBack: { path.removeLast() },
                onViewAttachment: { fileUrl in path.append(Route.viewEmailDocument(fileUrl: fileUrl)) }
            )
        case .subItemMessages(let shiftId, let subItemId):
            SubItemMessagesScreen(
                shiftId: shiftId,
                subItemId: subItemId,
                onBack: { path.removeLast() },
                onViewAttachment: { fileUrl in path.append(Route.viewEmailDocument(fileUrl: fileUrl)) }
            )

        // Quotations
        case .sendQuote(let shiftId):
            SendQuoteScreen(shiftId: shiftId, onBack: { path.removeLast() })
        case .viewQuotations(let shiftId):
            ViewQuotationsScreen(shiftId: shiftId, onBack: { path.removeLast() })

        // Leads
        case .newLeads:
            NewLeadsScreen(
                onOpenDrawer: { withAnimation { showDrawer = true } },
                onAddLead: { path.append(Route.addNewLead) },
                onViewLead: { leadId in path.append(Route.leadDetail(leadId: leadId)) }
            )
        case .quotedLeads:
            QuotedLeadsScreen(
                onOpenDrawer: { withAnimation { showDrawer = true } },
                onViewLead: { leadId in path.append(Route.leadDetail(leadId: leadId)) }
            )
        case .contactedLeads:
            ContactedLeadsScreen(
                onOpenDrawer: { withAnimation { showDrawer = true } },
                onViewLead: { leadId in path.append(Route.leadDetail(leadId: leadId)) }
            )
        case .addNewLead:
            AddNewLeadScreen(
                onBack: { path.removeLast() },
                onSuccess: { path.removeLast() }
            )
        case .leadDetail(let leadId):
            ViewLeadScreen(leadId: leadId, onBack: { path.removeLast() })

        // Clients
        case .clients:
            ClientsScreen(
                onOpenDrawer: { withAnimation { showDrawer = true } },
                onAddClient: { path.append(Route.addNewClient) }
            )
        case .addNewClient:
            AddNewClientScreen(
                onBack: { path.removeLast() },
                onSuccess: { path.removeLast() }
            )

        // Contractors
        case .allContractors:
            AllContractorsScreen(
                onOpenDrawer: { withAnimation { showDrawer = true } },
                onViewContractorDetail: { contractorId in path.append(Route.contractorDetails(contractorId: contractorId)) }
            )
        case .contractorDetails(let contractorId):
            ContractorDetailsScreen(
                contractorId: contractorId,
                onBack: { path.removeLast() },
                onViewDocument: { fileUrl, isImage in path.append(Route.viewDocument(fileUrl: fileUrl, isImage: isImage)) }
            )

        // Profile
        case .profile:
            ProfileScreen(
                onOpenDrawer: { withAnimation { showDrawer = true } },
                onEditProfile: { path.append(Route.editProfile) },
                onDeletedAccount: { doLogout() },
                onViewDocument: { fileUrl, isImage in path.append(Route.viewDocument(fileUrl: fileUrl, isImage: isImage)) }
            )
        case .editProfile:
            EditProfileScreen(
                onBack: { path.removeLast() },
                onSuccess: { _ in path.removeLast() }
            )

        // Notifications
        case .notifications:
            NotificationsScreen(
                onBack: { path.removeLast() },
                onNavigateToShift: { dateStr, shiftId in path.append(Route.dayDetail(date: dateStr, shiftId: shiftId)) },
                onNavigateToMessages: { shiftId in path.append(Route.emailMessages(shiftId: shiftId)) }
            )

        // Feedback
        case .sendFeedback(let shiftId):
            SendFeedbackScreen(
                shiftId: shiftId,
                onBack: { path.removeLast() },
                onSuccess: { path.removeLast() }
            )
        case .reviews(let shiftId):
            ReviewsScreen(
                shiftId: shiftId,
                onBack: { path.removeLast() },
                onSuccess: { path.removeLast() }
            )

        // Admin
        case .mainLeadsJobs:
            MainLeadsJobsScreen(
                onOpenDrawer: { withAnimation { showDrawer = true } },
                onShiftDetails: { shiftId in path.append(Route.shiftDetails(shiftId: shiftId)) },
                onViewQuotations: { shiftId in path.append(Route.viewQuotations(shiftId: shiftId)) },
                onViewMessages: { shiftId in path.append(Route.emailMessages(shiftId: shiftId)) },
                onViewFiles: { shiftId in path.append(Route.shiftFiles(shiftId: shiftId)) },
                onViewSubItemMessages: { shiftId, subItemId in path.append(Route.subItemMessages(shiftId: shiftId, subItemId: subItemId)) },
                onViewSubItemFiles: { shiftId, subItemId in path.append(Route.subItemFiles(shiftId: shiftId, subItemId: subItemId)) }
            )
        case .filoKretoTeam:
            FiloKretoTeamScreen(
                onOpenDrawer: { withAnimation { showDrawer = true } }
            )

        case .liveTracking:
            LiveTrackingView(
                onOpenDrawer: { withAnimation { showDrawer = true } }
            )

        case .timeTracking:
            TimeTrackingDashboardView(
                onOpenDrawer: { withAnimation { showDrawer = true } }
            )

        case .navigationMap(let siteLat, let siteLng, let siteAddress, let projectName, let shiftId):
            NavigationMapScreen(
                onBack: { path.removeLast() },
                viewModel: NavigationMapViewModel(
                    siteLatitude: siteLat, siteLongitude: siteLng,
                    siteAddress: siteAddress, projectName: projectName, shiftId: shiftId
                )
            )

        case .boardSettings:
            BoardSettingsScreen()
                .navigationBarBackButtonHidden(true)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: { withAnimation { showDrawer = true } }) {
                            Image(systemName: "line.3.horizontal")
                                .foregroundColor(.white)
                        }
                    }
                }

        case .activityLog:
            ActivityLogScreen()
                .navigationBarBackButtonHidden(true)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: { withAnimation { showDrawer = true } }) {
                            Image(systemName: "line.3.horizontal")
                                .foregroundColor(.white)
                        }
                    }
                }

        default:
            EmptyView()
        }
    }

    // MARK: - Helpers

    private func doLogout() {
        // Auto clock-out if Doer is currently clocked in
        if TrackingManager.shared.activeShiftId != nil {
            TrackingManager.shared.clockOut()
        }
        secureStorage.isLoggedIn = false
        secureStorage.clear()
        prefs.clearSession()
        path = NavigationPath()
        isLoggedIn = false
    }

    private func loadUnreadCount() async {
        let userId = prefs.userId
        guard !userId.isEmpty else { return }
        let result = await shiftRepo.getUserAllNotificationsById(userId: userId)
        if case .success(let notifications) = result {
            await MainActor.run {
                unreadNotificationCount = notifications.filter { !$0.isRead }.count
            }
        }
    }
}
