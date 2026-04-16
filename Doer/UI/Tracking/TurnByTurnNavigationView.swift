import SwiftUI
import UIKit
import GoogleMaps
import GoogleNavigation
import CoreLocation

struct TurnByTurnNavigationView: UIViewControllerRepresentable {
    let destinationLatitude: Double
    let destinationLongitude: Double
    let projectName: String
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> TurnByTurnNavigationViewController {
        let vc = TurnByTurnNavigationViewController()
        vc.destinationLatitude = destinationLatitude
        vc.destinationLongitude = destinationLongitude
        vc.projectName = projectName
        vc.onDismiss = onDismiss
        return vc
    }

    func updateUIViewController(_ uiViewController: TurnByTurnNavigationViewController, context: Context) {}
}

class TurnByTurnNavigationViewController: UIViewController, GMSNavigatorListener, CLLocationManagerDelegate {
    var destinationLatitude: Double = 0
    var destinationLongitude: Double = 0
    var projectName: String = ""
    var onDismiss: (() -> Void)?

    private var mapView: GMSMapView!
    private var navigator: GMSNavigator?
    private let locationManager = CLLocationManager()
    private var hasStartedNavigation = false
    private var autoCloseWorkItem: DispatchWorkItem?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Request location permission first
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()

        // Create navigation map view
        let camera = GMSCameraPosition.camera(withLatitude: destinationLatitude, longitude: destinationLongitude, zoom: 14)
        mapView = GMSMapView(frame: view.bounds, camera: camera)
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mapView.isNavigationEnabled = true
        mapView.isMyLocationEnabled = true
        mapView.settings.isNavigationHeaderEnabled = true
        mapView.settings.isNavigationFooterEnabled = true
        mapView.settings.myLocationButton = true
        view.addSubview(mapView)

        // Add close button on top
        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = .white
        closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        closeButton.layer.cornerRadius = 20
        closeButton.frame = CGRect(x: 16, y: 50, width: 40, height: 40)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        view.addSubview(closeButton)

        // Start location updates so the SDK can get a fix
        locationManager.startUpdatingLocation()
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard !hasStartedNavigation, locations.last != nil else { return }
        hasStartedNavigation = true
        // We have a location fix — now start navigation
        locationManager.stopUpdatingLocation()
        initializeNavigation()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
        // Try to start navigation anyway — the SDK might have its own location
        if !hasStartedNavigation {
            hasStartedNavigation = true
            initializeNavigation()
        }
    }

    // MARK: - Navigation

    private func initializeNavigation() {
        guard let navigator = mapView.navigator else {
            print("Navigator not available")
            showError("Navigator not available. Please accept Terms & Conditions and try again.")
            return
        }
        self.navigator = navigator
        navigator.add(self)

        // Enable voice guidance
        navigator.voiceGuidance = .alertsAndGuidance
        navigator.isGuidanceActive = true

        // Set destination
        guard let destination = GMSNavigationWaypoint(
            location: CLLocationCoordinate2D(latitude: destinationLatitude, longitude: destinationLongitude),
            title: projectName.isEmpty ? "Destination" : projectName
        ) else {
            showError("Invalid destination coordinates")
            return
        }

        navigator.setDestinations([destination]) { [weak self] routeStatus in
            switch routeStatus {
            case .OK:
                print("Route found to \(self?.projectName ?? "")")
                navigator.isGuidanceActive = true

                // Enable simulation in debug builds
                #if DEBUG
                self?.mapView.locationSimulator?.simulateLocationsAlongExistingRoute()
                self?.mapView.locationSimulator?.speedMultiplier = 5.0
                print("Simulation started at 5x speed")
                #endif

            case .noRouteFound:
                self?.showError("No route found to destination")
            case .networkError:
                self?.showError("Network error. Check your connection.")
            default:
                self?.showError("Could not calculate route (code \(routeStatus.rawValue)). Make sure location is set in Xcode: Debug → Simulate Location → Custom Location")
            }
        }
    }

    // MARK: - GMSNavigatorListener

    func navigator(_ navigator: GMSNavigator, didArriveAt waypoint: GMSNavigationWaypoint) {
        let alert = UIAlertController(
            title: "Arrived!",
            message: "You've arrived at \(projectName)",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.autoCloseWorkItem?.cancel()
            self?.autoCloseWorkItem = nil
            self?.closeTapped()
        })
        present(alert, animated: true)

        // Auto-close after 5 seconds if user hasn't tapped OK
        autoCloseWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self, weak alert] in
            guard let self = self else { return }
            if let alert = alert, alert.view.window != nil {
                alert.dismiss(animated: true) { [weak self] in
                    self?.closeTapped()
                }
            }
        }
        autoCloseWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: workItem)
    }

    @objc private func closeTapped() {
        stopNavigation()
        onDismiss?()
    }

    private func stopNavigation() {
        autoCloseWorkItem?.cancel()
        autoCloseWorkItem = nil

        #if DEBUG
        mapView?.locationSimulator?.stopSimulation()
        #endif

        navigator?.isGuidanceActive = false
        navigator?.voiceGuidance = .silent
        navigator?.clearDestinations()
        navigator?.remove(self)
        navigator = nil

        mapView?.isNavigationEnabled = false
        mapView?.isMyLocationEnabled = false

        locationManager.stopUpdatingLocation()
        locationManager.delegate = nil
    }

    deinit {
        stopNavigation()
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Navigation Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.closeTapped()
        })
        present(alert, animated: true)
    }
}
