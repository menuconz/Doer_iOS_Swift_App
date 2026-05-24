import Foundation
import MapKit
import Combine

struct ActiveDoerUi: Identifiable {
    var id: String { userId }
    let userId: String
    let displayName: String
    let shiftId: Int
    let trackingState: DoerTrackingState
    let latitude: Double
    let longitude: Double
    let eta: String?
    let distanceRemaining: Double?
    let siteName: String
    let projectName: String
    let siteLatitude: Double?
    let siteLongitude: Double?
    let timeOnSite: String
    let timestamp: String

    var statusLabel: String { trackingState.label }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

@MainActor
class LiveTrackingViewModel: ObservableObject {
    @Published var activeDoers: [ActiveDoerUi] = []
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var isPolling = false
    @Published var lastUpdated = ""
    @Published var totalActive = 0
    @Published var enRouteCount = 0
    @Published var onSiteCount = 0
    @Published var arrivedCount = 0
    @Published var selectedDoerUserId: String?
    @Published var selectedDoerRoute: [CLLocationCoordinate2D] = []

    private let trackingRepo = DIContainer.shared.trackingRepository
    private var pollingTask: Task<Void, Never>?

    func startPolling() {
        guard pollingTask == nil else { return }
        isPolling = true
        pollingTask = Task {
            while !Task.isCancelled {
                await fetchActiveDoers()
                try? await Task.sleep(nanoseconds: 15_000_000_000) // 15 seconds
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
        isPolling = false
    }

    func refresh() {
        Task { await fetchActiveDoers() }
    }

    func selectDoer(_ doer: ActiveDoerUi) {
        if selectedDoerUserId == doer.userId {
            selectedDoerUserId = nil
            selectedDoerRoute = []
            return
        }
        selectedDoerUserId = doer.userId
        selectedDoerRoute = []
        recomputeRouteFor(doer)
    }

    private func fetchActiveDoers() async {
        let result = await trackingRepo.getActiveDoers()
        switch result {
        case .success(let data):
            let doers = data.map { dto -> ActiveDoerUi in
                let state = DoerTrackingState(rawValue: dto.trackingState) ?? .idle
                let timeStr = (state == .onSite || state == .arrived) ? computeTimeOnSite(dto.timestamp) : ""
                return ActiveDoerUi(
                    userId: dto.userId, displayName: dto.displayName,
                    shiftId: dto.shiftId, trackingState: state,
                    latitude: dto.latitude, longitude: dto.longitude,
                    eta: dto.eta, distanceRemaining: dto.distanceRemaining,
                    siteName: dto.siteName, projectName: dto.projectName,
                    siteLatitude: dto.siteLatitude, siteLongitude: dto.siteLongitude,
                    timeOnSite: timeStr, timestamp: dto.timestamp
                )
            }
            let formatter = DateFormatter()
            formatter.dateFormat = "hh:mm:ss a"
            formatter.locale = Locale(identifier: "en_US_POSIX")

            activeDoers = doers
            isLoading = false
            lastUpdated = formatter.string(from: Date())
            totalActive = doers.count
            enRouteCount = doers.filter { $0.trackingState == .enRoute }.count
            // Matches Android: onSite count includes ARRIVED.
            onSiteCount = doers.filter { $0.trackingState == .onSite || $0.trackingState == .arrived }.count
            arrivedCount = doers.filter { $0.trackingState == .arrived }.count

            // If a doer is currently selected, recompute their route off the latest position
            // so the polyline tracks them as they move (parity with Android).
            if let selectedId = selectedDoerUserId,
               let updated = doers.first(where: { $0.userId == selectedId }) {
                recomputeRouteFor(updated)
            }

        case .error(let msg, _):
            isLoading = false
            errorMessage = msg
        case .loading: break
        }
    }

    private func recomputeRouteFor(_ doer: ActiveDoerUi) {
        guard let siteLat = doer.siteLatitude, let siteLng = doer.siteLongitude,
              siteLat != 0, siteLng != 0 else {
            selectedDoerRoute = []
            return
        }
        // Only show route while travelling — once on-site the doer pin already covers the site.
        guard doer.trackingState == .enRoute || doer.trackingState == .clockedIn else {
            selectedDoerRoute = []
            return
        }
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: doer.coordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: siteLat, longitude: siteLng)))
        request.transportType = .automobile
        Task {
            let directions = MKDirections(request: request)
            if let response = try? await directions.calculate(),
               let route = response.routes.first {
                selectedDoerRoute = route.polyline.coordinates
            }
        }
    }

    private func computeTimeOnSite(_ timestamp: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        guard let date = formatter.date(from: timestamp) else { return "" }
        let elapsed = Date().timeIntervalSince(date)
        let hours = Int(elapsed / 3600)
        let minutes = Int(elapsed.truncatingRemainder(dividingBy: 3600) / 60)
        return "\(hours)h \(minutes)m"
    }
}

// Helper to extract coordinates from MKPolyline
extension MKPolyline {
    var coordinates: [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: CLLocationCoordinate2D(), count: pointCount)
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
    }
}
