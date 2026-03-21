import Foundation

class LocationTrackingRepository {
    private let locationApi: LocationTrackingApi
    private let prefs: PreferencesManager

    init(locationApi: LocationTrackingApi = LocationTrackingApi(), prefs: PreferencesManager = .shared) {
        self.locationApi = locationApi
        self.prefs = prefs
    }

    func updateCaregiverLocation(latitude: Double, longitude: Double) async -> ApiResult<String> {
        return await safeApiCall {
            let location = UserLocationDto(
                latitude: latitude,
                longitude: longitude,
                timestamp: ISO8601DateFormatter().string(from: Date()),
                lId: Constants.lId,
                siteId: Constants.siteId,
                contactId: 0,
                userId: self.prefs.userId,
                basicAuthUid: self.prefs.basicAuthUid
            )
            return try await self.locationApi.updateCaregiverLocation(userLocation: location)
        }
    }
}
