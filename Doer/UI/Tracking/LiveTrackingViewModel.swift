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

    // Last non-zero position per doer (prevents a transient 0,0 poll from dropping the pin),
    // and the breadcrumb trail of positions actually observed for each doer this session.
    private var lastKnownCoords: [String: CLLocationCoordinate2D] = [:]
    private var doerTrails: [String: [CLLocationCoordinate2D]] = [:]

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
        updateSelectedRoute()
    }

    private func fetchActiveDoers() async {
        let result = await trackingRepo.getActiveDoers()
        switch result {
        case .success(let data):
            let doers = data.map { dto -> ActiveDoerUi in
                let state = DoerTrackingState(rawValue: dto.trackingState) ?? .idle
                let timeStr = (state == .onSite || state == .arrived) ? computeTimeOnSite(dto.timestamp) : ""

                // Carry forward the last-known position if this poll returned 0,0, so a
                // doer with a real position doesn't flicker off the map. Record real
                // positions into the breadcrumb trail.
                var lat = dto.latitude, lng = dto.longitude
                if lat == 0 && lng == 0, let prev = lastKnownCoords[dto.userId] {
                    lat = prev.latitude; lng = prev.longitude
                } else if lat != 0 || lng != 0 {
                    let coord = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                    lastKnownCoords[dto.userId] = coord
                    appendToTrail(userId: dto.userId, coord: coord)
                }

                return ActiveDoerUi(
                    userId: dto.userId, displayName: dto.displayName,
                    shiftId: dto.shiftId, trackingState: state,
                    latitude: lat, longitude: lng,
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

            // Keep the selected doer's drawn path (breadcrumb trail) in sync with the
            // latest poll so the polyline reflects where they have actually moved.
            updateSelectedRoute()

        case .error(let msg, _):
            isLoading = false
            errorMessage = msg
        case .loading: break
        }
    }

    /// Appends a freshly-observed position to a doer's breadcrumb trail, ignoring jitter
    /// (< 20 m moves) and capping the stored length so memory stays bounded.
    private func appendToTrail(userId: String, coord: CLLocationCoordinate2D) {
        var trail = doerTrails[userId] ?? []
        if let last = trail.last {
            let moved = CLLocation(latitude: last.latitude, longitude: last.longitude)
                .distance(from: CLLocation(latitude: coord.latitude, longitude: coord.longitude))
            if moved < 20 { return }
        }
        trail.append(coord)
        if trail.count > 500 { trail.removeFirst(trail.count - 500) }
        doerTrails[userId] = trail
    }

    /// Sets the drawn polyline to the selected doer's actual observed path (breadcrumb
    /// trail), so route movement reflects real device movement rather than a suggested route.
    private func updateSelectedRoute() {
        guard let id = selectedDoerUserId else { selectedDoerRoute = []; return }
        selectedDoerRoute = doerTrails[id] ?? []
    }

    private func computeTimeOnSite(_ timestamp: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        // Server timestamps are NZ time; interpret them as such so elapsed time-on-site
        // is correct even when the device is in a different timezone.
        formatter.timeZone = TimeZone(identifier: "Pacific/Auckland")
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
