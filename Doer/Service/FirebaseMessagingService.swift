import Foundation
import UserNotifications
import UIKit
import FirebaseMessaging

class FirebaseMessagingService: NSObject, UNUserNotificationCenterDelegate, MessagingDelegate {
    static let shared = FirebaseMessagingService()

    private let prefs = PreferencesManager.shared

    func configure() {
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        requestPermission()
    }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }

    // Called when APNS device token is received - pass to Firebase
    func updateAPNSToken(_ deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    // MARK: - MessagingDelegate

    // Called when FCM token is refreshed
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        print("FCM Token: \(token)")

        // Send token to server if user is logged in
        Task {
            let email = prefs.email
            guard !email.isEmpty else { return }
            // iOS-side registrations MUST use Constants.deviceTypeIOS (1). Sending
            // 2 here (the Android value) makes the server think this device is an
            // Android phone, so APNs payloads are never produced for it and iOS
            // never receives notifications.
            _ = await DIContainer.shared.accountRepository.authenticate(
                userName: email,
                password: "",
                deviceToken: token,
                deviceTypeId: Constants.deviceTypeIOS
            )
            print("FCM token updated on server (deviceTypeId=\(Constants.deviceTypeIOS) iOS)")
        }
    }

    // Get current FCM token (returns empty string on simulator or if APNS not ready)
    func getToken() async -> String {
        #if targetEnvironment(simulator)
        return ""
        #else
        do {
            let token = try await Messaging.messaging().token()
            return token
        } catch {
            print("FCM token not available yet, will be sent on next token refresh")
            return ""
        }
        #endif
    }

    // MARK: - UNUserNotificationCenterDelegate

    // Handle foreground notifications
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    // Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        print("Notification tapped: \(userInfo)")
        // Post notification for navigation
        NotificationCenter.default.post(
            name: .navigateToNotifications,
            object: nil,
            userInfo: userInfo as? [String: Any]
        )
        completionHandler()
    }
}

extension Notification.Name {
    static let navigateToNotifications = Notification.Name("navigateToNotifications")
}
