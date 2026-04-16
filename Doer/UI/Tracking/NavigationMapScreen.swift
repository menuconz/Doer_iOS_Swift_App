import SwiftUI
import MapKit

struct NavigationMapScreen: View {
    let onBack: () -> Void
    @State var viewModel: NavigationMapViewModel
    @State private var showTurnByTurn = false
    @State private var mapPosition: MapCameraPosition = .automatic

    var body: some View {
        ZStack(alignment: .bottom) {
            // Map
            Map(position: $mapPosition) {
                // Doer marker
                if viewModel.hasDoerLocation {
                    Annotation("You", coordinate: CLLocationCoordinate2D(
                        latitude: viewModel.doerLatitude, longitude: viewModel.doerLongitude
                    )) {
                        Image(systemName: "location.circle.fill")
                            .font(.title)
                            .foregroundStyle(viewModel.hasArrived ? .green : .blue)
                    }
                }

                // Site marker
                if viewModel.siteLatitude != 0 {
                    Annotation(viewModel.projectName.isEmpty ? "Site" : viewModel.projectName,
                               coordinate: CLLocationCoordinate2D(
                                   latitude: viewModel.siteLatitude, longitude: viewModel.siteLongitude
                               )) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.title)
                            .foregroundStyle(.red)
                    }
                }

                // Route polyline — dual render (outline + color) for visibility
                if let polyline = viewModel.routePolyline {
                    MapPolyline(polyline)
                        .stroke(Color(hex: "1A73E8"), lineWidth: 8)
                    MapPolyline(polyline)
                        .stroke(Color(hex: "4285F4"), lineWidth: 5)
                }
            }
            .mapControls {
                MapCompass()
                MapUserLocationButton()
            }
            .ignoresSafeArea(edges: .bottom)

            // Re-center button (top-right)
            if viewModel.hasDoerLocation {
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            mapPosition = .automatic
                        } label: {
                            Image(systemName: "location.viewfinder")
                                .font(.title3)
                                .foregroundStyle(Color(hex: "007AFF"))
                                .frame(width: 44, height: 44)
                                .background(.white)
                                .clipShape(Circle())
                                .shadow(radius: 3)
                        }
                        .padding(.trailing, 12)
                        .padding(.top, 12)
                    }
                    Spacer()
                }
            }

            // Loading overlay
            if viewModel.isLoading {
                Color.white.opacity(0.7)
                    .ignoresSafeArea()
                    .overlay {
                        VStack(spacing: 8) {
                            ProgressView()
                            Text("Getting your location...")
                                .foregroundStyle(.gray)
                        }
                    }
            }

            // Bottom cards
            VStack(spacing: 8) {
                // ETA card
                if !viewModel.eta.isEmpty || viewModel.hasArrived {
                    etaCard
                }

                // Navigate button — opens in-app Google Navigation
                if !viewModel.hasArrived && viewModel.siteLatitude != 0 {
                    Button {
                        showTurnByTurn = true
                    } label: {
                        Label("Start Turn-by-Turn Navigation", systemImage: "location.fill")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(hex: "00C875"))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .fullScreenCover(isPresented: $showTurnByTurn) {
                        TurnByTurnNavigationView(
                            destinationLatitude: viewModel.siteLatitude,
                            destinationLongitude: viewModel.siteLongitude,
                            projectName: viewModel.projectName,
                            onDismiss: { showTurnByTurn = false }
                        )
                        .ignoresSafeArea()
                    }
                }
            }
            .padding(16)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text(viewModel.projectName.isEmpty ? "Navigation" : viewModel.projectName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                    if !viewModel.siteAddress.isEmpty {
                        Text(viewModel.siteAddress)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                }
            }
        }
        .toolbarBackground(DoerTheme.primary, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .alert("Error", isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.clearError() } }
        )) {
            Button("OK") { viewModel.clearError() }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - ETA Card

    private var etaCard: some View {
        Group {
            if viewModel.hasArrived {
                HStack(spacing: 10) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.title2)
                        .foregroundStyle(.white)
                    VStack(alignment: .leading) {
                        Text("You've Arrived!")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                        Text(viewModel.projectName)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    Spacer()
                }
                .padding(20)
                .background(Color(hex: "00C875"))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(radius: 6)
            } else {
                HStack(spacing: 14) {
                    Circle()
                        .fill(Color(hex: "007AFF"))
                        .frame(width: 56, height: 56)
                        .overlay {
                            Image(systemName: "car.fill")
                                .font(.title3)
                                .foregroundStyle(.white)
                        }
                    VStack(alignment: .leading) {
                        Text(viewModel.eta)
                            .font(.title2.bold())
                            .foregroundStyle(Color(hex: "1F2937"))
                        Text(viewModel.distance)
                            .font(.subheadline)
                            .foregroundStyle(Color(hex: "6B7280"))
                    }
                    Spacer()
                    VStack(spacing: 4) {
                        Circle()
                            .fill(Color(hex: "00C875"))
                            .frame(width: 10, height: 10)
                        Text("LIVE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color(hex: "00C875"))
                    }
                }
                .padding(16)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(radius: 6)
            }
        }
    }
}
