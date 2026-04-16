import Foundation

class TrackingRepository {
    private let trackingApi: TrackingApi
    private let prefs: PreferencesManager

    init(trackingApi: TrackingApi, prefs: PreferencesManager) {
        self.trackingApi = trackingApi
        self.prefs = prefs
    }

    func recordClockEvent(_ event: ClockEventDto) async -> ApiResult<String> {
        do {
            let result = try await trackingApi.recordClockEvent(event)
            return .success(result)
        } catch {
            return .error(error.localizedDescription)
        }
    }

    func sendLocationBatch(_ batch: LocationBatchDto) async -> ApiResult<String> {
        do {
            let result = try await trackingApi.sendLocationBatch(batch)
            return .success(result)
        } catch {
            return .error(error.localizedDescription)
        }
    }

    func updateTrackingStatus(_ status: TrackingStatusDto) async -> ApiResult<String> {
        do {
            let result = try await trackingApi.updateTrackingStatus(status)
            return .success(result)
        } catch {
            return .error(error.localizedDescription)
        }
    }

    func getActiveDoers() async -> ApiResult<[TrackingStatusDto]> {
        do {
            let result = try await trackingApi.getActiveDoers()
            return .success(result)
        } catch {
            return .error(error.localizedDescription)
        }
    }

    func sendTrackingNotification(_ notification: TrackingNotificationDto) async -> ApiResult<String> {
        do {
            let result = try await trackingApi.sendTrackingNotification(notification)
            return .success(result)
        } catch {
            return .error(error.localizedDescription)
        }
    }

    func editTimeEntry(_ request: EditTimeEntryDto) async -> ApiResult<String> {
        do {
            let result = try await trackingApi.editTimeEntry(request)
            return .success(result)
        } catch {
            return .error(error.localizedDescription)
        }
    }
}
