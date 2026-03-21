import Foundation
import CoreLocation

class LocationTrackingService: NSObject, CLLocationManagerDelegate {
    static let shared = LocationTrackingService()

    private let locationManager = CLLocationManager()
    private let locationRepo = DIContainer.shared.locationTrackingRepository
    private var isTracking = false

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
    }

    func startTracking() {
        guard !isTracking else { return }
        locationManager.requestAlwaysAuthorization()
        locationManager.startUpdatingLocation()
        isTracking = true
        print("LocationTrackingService started")
    }

    func stopTracking() {
        guard isTracking else { return }
        locationManager.stopUpdatingLocation()
        isTracking = false
        print("LocationTrackingService stopped")
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task {
            _ = await locationRepo.updateCaregiverLocation(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
}
