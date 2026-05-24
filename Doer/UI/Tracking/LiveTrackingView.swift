import SwiftUI
import MapKit

struct LiveTrackingView: View {
    @StateObject private var viewModel = LiveTrackingViewModel()
    let onOpenDrawer: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Top Bar
            HStack {
                Button(action: onOpenDrawer) {
                    Image(systemName: "line.3.horizontal")
                        .foregroundColor(.white)
                        .font(.title2)
                }
                VStack(alignment: .leading) {
                    Text("Live Tracking")
                        .font(.headline)
                        .foregroundColor(.white)
                    if !viewModel.lastUpdated.isEmpty {
                        Text("Updated: \(viewModel.lastUpdated)")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                Spacer()
                // Polling indicator
                if viewModel.isPolling {
                    Circle()
                        .fill(.green)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(.white, lineWidth: 1))
                }
                Button(action: { viewModel.refresh() }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(DoerTheme.primary)

            // Stats Bar
            HStack(spacing: 16) {
                StatChip(label: "Active", count: viewModel.totalActive, color: .blue)
                StatChip(label: "En Route", count: viewModel.enRouteCount, color: .orange)
                StatChip(label: "Arrived", count: viewModel.arrivedCount, color: .cyan)
                StatChip(label: "On Site", count: viewModel.onSiteCount, color: .green)
            }
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(Color.white)

            if viewModel.isLoading && viewModel.activeDoers.isEmpty {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                // Map
                LiveMapView(
                    doers: viewModel.activeDoers,
                    routePoints: viewModel.selectedDoerRoute,
                    selectedUserId: viewModel.selectedDoerUserId
                )
                .frame(height: UIScreen.main.bounds.height * 0.4)

                // Doer List
                HStack {
                    Text("Active Doers").font(.headline).foregroundColor(DoerTheme.primary)
                    Spacer()
                    Text("\(viewModel.totalActive) active").font(.caption).foregroundColor(.gray)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Color.white)

                if viewModel.activeDoers.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "location.slash")
                            .font(.system(size: 40)).foregroundColor(.gray.opacity(0.4))
                        Text("No active Doers right now").foregroundColor(.gray)
                        Text("Doers will appear here when they clock in")
                            .font(.caption).foregroundColor(.gray.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(viewModel.activeDoers) { doer in
                                DoerCardView(
                                    doer: doer,
                                    isSelected: viewModel.selectedDoerUserId == doer.userId
                                ) {
                                    viewModel.selectDoer(doer)
                                }
                            }
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                    }
                }
            }
        }
        .background(Color(hex: "F8F9FA"))
        .onAppear { viewModel.startPolling() }
        .onDisappear { viewModel.stopPolling() }
        .navigationBarHidden(true)
    }
}

// MARK: - Map View

// Annotation that carries the doer's tracking state so the delegate can color the marker.
final class DoerAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    let trackingState: DoerTrackingState
    let isSite: Bool

    init(coordinate: CLLocationCoordinate2D, title: String?, subtitle: String?,
         trackingState: DoerTrackingState, isSite: Bool = false) {
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
        self.trackingState = trackingState
        self.isSite = isSite
    }
}

private func markerColor(for state: DoerTrackingState) -> UIColor {
    // Mirrors the Android LiveTrackingScreen marker hue palette.
    switch state {
    case .enRoute:   return .systemOrange
    case .arrived:   return .systemGreen
    case .onSite:    return .systemGreen
    case .leaving:   return .systemYellow
    case .clockedIn: return .systemBlue
    default:         return .systemRed
    }
}

struct LiveMapView: UIViewRepresentable {
    let doers: [ActiveDoerUi]
    let routePoints: [CLLocationCoordinate2D]
    let selectedUserId: String?

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.showsUserLocation = false
        map.delegate = context.coordinator
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        map.removeAnnotations(map.annotations)
        map.removeOverlays(map.overlays)

        let validDoers = doers.filter { $0.latitude != 0 && $0.longitude != 0 }
        let selectedDoer = selectedUserId.flatMap { id in validDoers.first(where: { $0.userId == id }) }
        let isSelectedTravelling: Bool = {
            guard let d = selectedDoer else { return false }
            return d.trackingState == .enRoute || d.trackingState == .clockedIn
        }()

        // Site marker shown only for the currently selected, still-travelling doer
        // (once on-site, the doer pin already covers the site location).
        if let d = selectedDoer, isSelectedTravelling,
           let lat = d.siteLatitude, let lng = d.siteLongitude, lat != 0, lng != 0 {
            let site = DoerAnnotation(
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                title: d.projectName.isEmpty ? (d.siteName.isEmpty ? "Site" : d.siteName) : d.projectName,
                subtitle: (d.siteName.isEmpty || d.siteName == d.projectName) ? "Shift location" : d.siteName,
                trackingState: .idle,
                isSite: true
            )
            map.addAnnotation(site)
        }

        for doer in validDoers {
            let title = doer.displayName.isEmpty ? "Doer \(doer.userId.prefix(6))" : doer.displayName
            var subtitleParts: [String] = [doer.statusLabel]
            if !doer.timeOnSite.isEmpty { subtitleParts.append(doer.timeOnSite) }
            if let eta = doer.eta, !eta.isEmpty { subtitleParts.append("ETA: \(eta)") }
            if !doer.projectName.isEmpty { subtitleParts.append(doer.projectName) }
            let annotation = DoerAnnotation(
                coordinate: doer.coordinate,
                title: String(title),
                subtitle: subtitleParts.joined(separator: " | "),
                trackingState: doer.trackingState
            )
            map.addAnnotation(annotation)
        }

        // Route polyline (only set by viewmodel for travelling doers)
        if !routePoints.isEmpty {
            let polyline = MKPolyline(coordinates: routePoints, count: routePoints.count)
            map.addOverlay(polyline)
        }

        // Camera logic — mirrors the Android LaunchedEffect:
        // - one valid point → center+zoom on it
        // - multiple → fit bounds, optionally including the site when selected+travelling
        var pointsToFit: [CLLocationCoordinate2D] = []
        if let d = selectedDoer {
            pointsToFit.append(d.coordinate)
            if isSelectedTravelling,
               let lat = d.siteLatitude, let lng = d.siteLongitude, lat != 0, lng != 0 {
                pointsToFit.append(CLLocationCoordinate2D(latitude: lat, longitude: lng))
            }
            pointsToFit.append(contentsOf: routePoints)
        } else {
            pointsToFit = validDoers.map { $0.coordinate }
        }

        if pointsToFit.count == 1 {
            let region = MKCoordinateRegion(
                center: pointsToFit[0],
                latitudinalMeters: 4000, longitudinalMeters: 4000
            )
            map.setRegion(region, animated: true)
        } else if pointsToFit.count > 1 {
            map.setRegion(MKCoordinateRegion(coordinates: pointsToFit), animated: true)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor(red: 66/255, green: 133/255, blue: 244/255, alpha: 1)
                renderer.lineWidth = 6
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let doer = annotation as? DoerAnnotation else { return nil }
            let identifier = doer.isSite ? "site" : "doer"
            let view: MKMarkerAnnotationView
            if let dequeued = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView {
                dequeued.annotation = annotation
                view = dequeued
            } else {
                view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            }
            view.canShowCallout = true
            if doer.isSite {
                view.markerTintColor = .systemRed
                view.glyphImage = UIImage(systemName: "mappin.and.ellipse")
                view.displayPriority = .defaultLow
            } else {
                view.markerTintColor = markerColor(for: doer.trackingState)
                view.glyphImage = UIImage(systemName: "figure.walk")
                view.displayPriority = .required
            }
            return view
        }
    }
}

// MARK: - Helper to create region from coordinates
extension MKCoordinateRegion {
    init(coordinates: [CLLocationCoordinate2D]) {
        guard !coordinates.isEmpty else {
            self = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: -36.85, longitude: 174.76),
                                      span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1))
            return
        }
        let lats = coordinates.map { $0.latitude }
        let lngs = coordinates.map { $0.longitude }
        let center = CLLocationCoordinate2D(
            latitude: (lats.min()! + lats.max()!) / 2,
            longitude: (lngs.min()! + lngs.max()!) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.01, (lats.max()! - lats.min()!) * 1.5),
            longitudeDelta: max(0.01, (lngs.max()! - lngs.min()!) * 1.5)
        )
        self = MKCoordinateRegion(center: center, span: span)
    }
}

// MARK: - Doer Card

struct DoerCardView: View {
    let doer: ActiveDoerUi
    let isSelected: Bool
    let onClick: () -> Void

    var statusColor: Color {
        switch doer.trackingState {
        case .idle: return .gray
        case .clockedIn: return .blue
        case .enRoute: return .orange
        case .arrived, .onSite: return .green
        case .leaving: return .yellow
        case .clockedOut: return .gray
        }
    }

    var body: some View {
        Button(action: onClick) {
            HStack(spacing: 12) {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "location.fill")
                            .foregroundColor(statusColor)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(doer.displayName.isEmpty ? "Doer \(doer.userId.prefix(8))" : doer.displayName)
                        .font(.subheadline).fontWeight(.bold)
                        .foregroundColor(Color(hex: "1F2937"))
                    HStack(spacing: 4) {
                        if !doer.projectName.isEmpty {
                            Text(doer.projectName).font(.caption).foregroundColor(.gray)
                        }
                        if !doer.siteName.isEmpty {
                            Text("•").font(.caption2).foregroundColor(.gray)
                            Text(doer.siteName).font(.caption).foregroundColor(.gray).lineLimit(1)
                        }
                    }
                    if doer.trackingState == .enRoute, let eta = doer.eta {
                        Text("ETA: \(eta)").font(.caption).foregroundColor(.blue)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(doer.statusLabel)
                        .font(.caption2).fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(statusColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    if !doer.timeOnSite.isEmpty {
                        Text(doer.timeOnSite)
                            .font(.caption).fontWeight(.bold)
                            .foregroundColor(Color(hex: "1F2937"))
                    }
                }
            }
            .padding(12)
            .background(isSelected ? Color.blue.opacity(0.05) : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Stat Chip

struct StatChip: View {
    let label: String
    let count: Int
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Text("\(count)")
                .font(.caption).fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(color)
                .clipShape(Circle())
            Text(label).font(.caption).foregroundColor(.gray)
        }
    }
}
