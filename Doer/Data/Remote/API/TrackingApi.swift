import Foundation
import Alamofire

class TrackingApi {
    private let network = NetworkManager.shared

    func recordClockEvent(_ event: ClockEventDto) async throws -> String {
        return try await network.postString("Tracking/ClockEvent", body: event)
    }

    func sendLocationBatch(_ batch: LocationBatchDto) async throws -> String {
        return try await network.postString("Tracking/LocationBatch", body: batch)
    }

    func updateTrackingStatus(_ status: TrackingStatusDto) async throws -> String {
        return try await network.postString("Tracking/UpdateStatus", body: status)
    }

    func getActiveDoers(siteId: Int = 1, lId: Int = 1) async throws -> [TrackingStatusDto] {
        return try await network.get("Tracking/ActiveDoers", parameters: ["siteId": siteId, "lId": lId])
    }

    func sendTrackingNotification(_ notification: TrackingNotificationDto) async throws -> String {
        return try await network.postString("Tracking/SendNotification", body: notification)
    }

    func editTimeEntry(_ request: EditTimeEntryDto) async throws -> String {
        return try await network.postString("Tracking/EditTimeEntry", body: request)
    }
}
