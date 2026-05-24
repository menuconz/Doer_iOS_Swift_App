import SwiftUI
import FirebaseCore
import FirebaseCrashlytics
import GoogleMaps
import GoogleNavigation

@main
struct DoerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    init() {
        // Clear Keychain on first launch after (re)install. iOS preserves Keychain
        // items across app deletion, which would otherwise leave a stale
        // `is_logged_in` flag and auto-login the user on reinstall.
        if !UserDefaults.standard.bool(forKey: "has_launched_before") {
            SecureStorageManager.shared.clear()
            UserDefaults.standard.set(true, forKey: "has_launched_before")
        }

        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color(hex: "#667685"))
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]

        // White back button with arrow only (no "Back" text)
        let backButtonAppearance = UIBarButtonItemAppearance()
        backButtonAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.clear]
        appearance.backButtonAppearance = backButtonAppearance

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance

        // Set cursor color to dark for text fields (prevent white cursor from .tint(.white))
        UITextField.appearance().tintColor = UIColor(Color(hex: "#007AFF"))
        UITextView.appearance().tintColor = UIColor(Color(hex: "#007AFF"))
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().tintColor = .white
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light)
                .task {
                    // Warm the BoardConfigCache so dynamic dropdown labels and the
                    // active board name are available across the app.
                    await DIContainer.shared.boardConfigCache.load()
                }
        }
    }
}

// MARK: - AppDelegate for Firebase & Push Notifications
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Initialize Google Maps & Navigation SDK
        GMSServices.provideAPIKey("AIzaSyDCmj86d3XA-GvAonJowP1ujnzCf7TDKAE")

        // Initialize Firebase
        FirebaseApp.configure()

        // Enable Crashlytics
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        Crashlytics.crashlytics().sendUnsentReports()

        // Configure push notifications
        FirebaseMessagingService.shared.configure()

        return true
    }

    // Pass APNS device token to Firebase
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        FirebaseMessagingService.shared.updateAPNSToken(deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("Failed to register for remote notifications: \(error)")
    }
}
