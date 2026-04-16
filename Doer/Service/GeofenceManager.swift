import Foundation
import CoreLocation

class GeofenceManager: NSObject, CLLocationManagerDelegate {
    static let shared = GeofenceManager()

    private let locationManager = CLLocationManager()
    var onGeofenceEnter: ((Int, Double, Double) -> Void)?
    var onGeofenceExit: ((Int, Double, Double) -> Void)?

    static let defaultRadius: CLLocationDistance = 100 // 100 meters
    static let dwellDelay: TimeInterval = 120 // 2 minutes

    override init() {
        super.init()
        locationManager.delegate = self
    }

    func registerSiteGeofence(shiftId: Int, latitude: Double, longitude: Double, radius: CLLocationDistance = defaultRadius) {
        let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let region = CLCircularRegion(center: center, radius: radius, identifier: "doer_site_\(shiftId)")
        region.notifyOnEntry = true
        region.notifyOnExit = true

        locationManager.startMonitoring(for: region)
        print("GeofenceManager: Registered geofence for shift \(shiftId) at (\(latitude), \(longitude)) radius=\(radius)m")
    }

    func removeGeofence(shiftId: Int) {
        let identifier = "doer_site_\(shiftId)"
        for region in locationManager.monitoredRegions {
            if region.identifier == identifier {
                locationManager.stopMonitoring(for: region)
                print("GeofenceManager: Removed geofence for shift \(shiftId)")
            }
        }
    }

    func removeAllGeofences() {
        for region in locationManager.monitoredRegions {
            if region.identifier.hasPrefix("doer_site_") {
                locationManager.stopMonitoring(for: region)
            }
        }
        print("GeofenceManager: All geofences removed")
    }

    static func extractShiftId(from identifier: String) -> Int? {
        let prefix = "doer_site_"
        guard identifier.hasPrefix(prefix) else { return nil }
        return Int(identifier.dropFirst(prefix.count))
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let shiftId = GeofenceManager.extractShiftId(from: region.identifier) else { return }
        let location = manager.location
        print("GeofenceManager: ENTER for shift \(shiftId)")
        onGeofenceEnter?(shiftId, location?.coordinate.latitude ?? 0, location?.coordinate.longitude ?? 0)
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard let shiftId = GeofenceManager.extractShiftId(from: region.identifier) else { return }
        let location = manager.location
        print("GeofenceManager: EXIT for shift \(shiftId)")
        onGeofenceExit?(shiftId, location?.coordinate.latitude ?? 0, location?.coordinate.longitude ?? 0)
    }

    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print("GeofenceManager: Monitoring failed: \(error.localizedDescription)")
    }
}
