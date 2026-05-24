import Foundation
import UserNotifications

class TrackingNotificationHelper {
    static let shared = TrackingNotificationHelper()
    private let prefs = DIContainer.shared.preferencesManager
    private let offlineSync = OfflineSyncManager.shared

    // Notification IDs for updating/replacing
    private static let notifIdEnRoute = "doer_tracking_enroute"
    private static let notifIdOnSite = "doer_tracking_onsite"
    private static let notifIdClockIn = "doer_tracking_clockin"
    private static let notifIdArrived = "doer_tracking_arrived"
    private static let notifIdLeftSite = "doer_tracking_leftsite"
    private static let notifIdThreshold = "doer_tracking_threshold"
    private static let notifIdClockOut = "doer_tracking_clockout"
    private static let notifIdAutoClockIn = "doer_tracking_autoclockin"

    func onEnRoute(shiftId: Int, latitude: Double, longitude: Double, projectName: String) {
        showLocalNotification(id: Self.notifIdEnRoute, title: "On the Way",
                              body: "Navigating to \(projectName). Drive safely!", priority: .timeSensitive)
        sendToManager(shiftId: shiftId, type: "TRACKING_EN_ROUTE", title: "Doer En Route",
                      body: "A Doer is heading to \(projectName)",
                      state: .enRoute, latitude: latitude, longitude: longitude)
    }

    func onAutoClockInSuggestion(shiftId: Int, projectName: String) {
        showLocalNotification(id: Self.notifIdAutoClockIn, title: "Clock In?",
                              body: "You're near \(projectName). Would you like to clock in?", priority: .timeSensitive)
    }

    func onClockIn(shiftId: Int, latitude: Double, longitude: Double, projectName: String) {
        showLocalNotification(id: Self.notifIdClockIn, title: "Clocked In", body: "You've clocked in for \(projectName). Safe travels!")
        sendToManager(shiftId: shiftId, type: "TRACKING_CLOCK_IN", title: "Doer Clocked In",
                      body: "A Doer has clocked in and is heading to \(projectName)",
                      state: .clockedIn, latitude: latitude, longitude: longitude)
    }

    func onArrived(shiftId: Int, latitude: Double, longitude: Double, projectName: String) {
        showLocalNotification(id: Self.notifIdArrived, title: "Arrived at Site", body: "Welcome to \(projectName). Time tracking has started.")
        sendToManager(shiftId: shiftId, type: "TRACKING_ARRIVED", title: "Doer Arrived",
                      body: "A Doer has arrived at \(projectName)",
                      state: .arrived, latitude: latitude, longitude: longitude)
    }

    func onLeftSite(shiftId: Int, latitude: Double, longitude: Double, projectName: String) {
        showLocalNotification(id: Self.notifIdLeftSite, title: "Left Site Area", body: "You've left \(projectName). Auto clock-out in 5 minutes if you don't return.")
        sendToManager(shiftId: shiftId, type: "TRACKING_LEFT_SITE", title: "Doer Left Site",
                      body: "A Doer has left \(projectName)",
                      state: .leaving, latitude: latitude, longitude: longitude)
    }

    func onThresholdWarning(shiftId: Int, hoursOnSite: Double, projectName: String) {
        showLocalNotification(id: Self.notifIdThreshold, title: "Approaching 12-Hour Limit",
                              body: "You've been at \(projectName) for \(Int(hoursOnSite)) hours. 1 hour remaining.", priority: .timeSensitive)
        sendToManager(shiftId: shiftId, type: "TRACKING_THRESHOLD_WARNING", title: "12-Hour Warning",
                      body: "A Doer is approaching 12 hours at \(projectName) (\(Int(hoursOnSite))h)",
                      state: .onSite, hoursOnSite: hoursOnSite)
    }

    func onThresholdExceeded(shiftId: Int, hoursOnSite: Double, projectName: String) {
        showLocalNotification(id: Self.notifIdThreshold, title: "12-Hour Limit Exceeded",
                              body: "You've exceeded 12 hours at \(projectName). Please clock out.", priority: .timeSensitive)
        sendToManager(shiftId: shiftId, type: "TRACKING_THRESHOLD_EXCEEDED", title: "12-Hour Limit Exceeded!",
                      body: "A Doer has exceeded 12 hours at \(projectName) (\(String(format: "%.1f", hoursOnSite))h)",
                      state: .onSite, hoursOnSite: hoursOnSite)
    }

    func onClockOut(shiftId: Int, latitude: Double, longitude: Double, projectName: String) {
        showLocalNotification(id: Self.notifIdClockOut, title: "Clocked Out", body: "You've clocked out from \(projectName). Great work!")
        sendToManager(shiftId: shiftId, type: "TRACKING_CLOCK_OUT", title: "Doer Clocked Out",
                      body: "A Doer has clocked out from \(projectName)",
                      state: .clockedOut, latitude: latitude, longitude: longitude)
    }

    func onShiftDeleted(shiftId: Int, projectName: String) {
        let label = projectName.isEmpty ? "the active job" : "\"\(projectName)\""
        showLocalNotification(id: "doer_tracking_shift_deleted",
                              title: "Shift removed",
                              body: "\(label) was deleted — tracking has been stopped.",
                              priority: .timeSensitive)
    }

    func onGpsPermissionRevoked(shiftId: Int) {
        showLocalNotification(id: "doer_tracking_gps_revoked", title: "Location Permission Required",
                              body: "Location access was revoked. Open Settings to re-enable for tracking.", priority: .timeSensitive)
        sendToManager(shiftId: shiftId, type: "TRACKING_GPS_REVOKED", title: "GPS Permission Revoked",
                      body: "A Doer has revoked location permission while tracking is active",
                      state: .onSite)
    }

    // MARK: - Private

    private func showLocalNotification(id: String = UUID().uuidString, title: String, body: String,
                                       priority: UNNotificationInterruptionLevel = .active) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = priority == .timeSensitive ? .defaultCritical : .default
        content.interruptionLevel = priority
        // Using specific ID allows replacing/updating existing notifications
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private func sendToManager(shiftId: Int, type: String, title: String, body: String,
                                state: DoerTrackingState, latitude: Double = 0, longitude: Double = 0,
                                hoursOnSite: Double? = nil) {
        let userId = prefs.userId
        let ts = Constants.nowNz()
        Task {
            await offlineSync.queueNotification(
                userId: userId, shiftId: shiftId, notificationType: type,
                title: title, body: body, trackingState: state.rawValue,
                latitude: latitude, longitude: longitude,
                timestamp: ts, hoursOnSite: hoursOnSite
            )
        }
    }
}
