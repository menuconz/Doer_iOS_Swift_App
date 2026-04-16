import Foundation
import CoreLocation
import MapKit

@Observable
class NavigationMapViewModel: NSObject, CLLocationManagerDelegate {
    // Site info
    let siteLatitude: Double
    let siteLongitude: Double
    let siteAddress: String
    let projectName: String
    let shiftId: Int

    // Doer live location
    var doerLatitude: Double = 0
    var doerLongitude: Double = 0
    var hasDoerLocation: Bool = false

    // Route
    var routePolyline: MKPolyline?
    var hasRoute: Bool = false

    // ETA & Distance
    var eta: String = ""
    var distance: String = ""
    var hasArrived: Bool = false

    // Loading / Error
    var isLoading: Bool = true
    var errorMessage: String? = nil

    private let locationManager = CLLocationManager()
    private var lastRouteUpdateLocation: CLLocation?
    private var routeRefreshTimer: Timer?

    init(siteLatitude: Double, siteLongitude: Double, siteAddress: String, projectName: String, shiftId: Int) {
        self.siteLatitude = siteLatitude
        self.siteLongitude = siteLongitude
        self.siteAddress = siteAddress
        self.projectName = projectName
        self.shiftId = shiftId
        super.init()

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10
        startLocationUpdates()
        startPeriodicRouteRefresh()
    }

    deinit {
        locationManager.stopUpdatingLocation()
        routeRefreshTimer?.invalidate()
    }

    // MARK: - Location

    private func startLocationUpdates() {
        let status = locationManager.authorizationStatus
        guard status == .authorizedAlways || status == .authorizedWhenInUse else {
            isLoading = false
            errorMessage = "Location permission required"
            return
        }
        locationManager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        doerLatitude = location.coordinate.latitude
        doerLongitude = location.coordinate.longitude
        hasDoerLocation = true
        isLoading = false

        // Check arrived (within 100m)
        let siteLocation = CLLocation(latitude: siteLatitude, longitude: siteLongitude)
        let dist = location.distance(from: siteLocation)
        if dist <= 100 && !hasArrived {
            hasArrived = true
            eta = "Arrived"
            distance = "0 m"
        }

        // Refresh route if moved > 200m from last update
        if let last = lastRouteUpdateLocation {
            if location.distance(from: last) > 200 {
                fetchRoute(from: location.coordinate)
            }
        } else {
            fetchRoute(from: location.coordinate)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isLoading = false
        errorMessage = "Location error: \(error.localizedDescription)"
    }

    // MARK: - Routing

    private func fetchRoute(from origin: CLLocationCoordinate2D) {
        guard siteLatitude != 0, siteLongitude != 0, !hasArrived else { return }

        lastRouteUpdateLocation = CLLocation(latitude: origin.latitude, longitude: origin.longitude)

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        request.destination = MKMapItem(placemark: MKPlacemark(
            coordinate: CLLocationCoordinate2D(latitude: siteLatitude, longitude: siteLongitude)
        ))
        request.transportType = .automobile

        MKDirections(request: request).calculate { [weak self] response, error in
            guard let self, let route = response?.routes.first else { return }
            Task { @MainActor in
                self.routePolyline = route.polyline
                self.hasRoute = true
                self.eta = self.formatDuration(route.expectedTravelTime)
                self.distance = self.formatDistance(route.distance)
            }
        }
    }

    private func startPeriodicRouteRefresh() {
        routeRefreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self, hasDoerLocation, !hasArrived else { return }
            fetchRoute(from: CLLocationCoordinate2D(latitude: doerLatitude, longitude: doerLongitude))
        }
    }

    // MARK: - Open in Maps

    func openInMaps() {
        let destination = CLLocationCoordinate2D(latitude: siteLatitude, longitude: siteLongitude)
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        mapItem.name = projectName.isEmpty ? "Site" : projectName
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }

    // MARK: - Formatting

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60
        let mins = minutes % 60
        return mins > 0 ? "\(hours) hr \(mins) min" : "\(hours) hr"
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters < 1000 { return "\(Int(meters)) m" }
        return String(format: "%.1f km", meters / 1000)
    }

    func clearError() { errorMessage = nil }
}
