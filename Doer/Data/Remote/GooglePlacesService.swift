import Foundation

struct PlacePrediction: Codable {
    var description: String = ""
    var placeId: String = ""

    enum CodingKeys: String, CodingKey {
        case description
        case placeId = "place_id"
    }
}

struct PlaceAutoCompleteResponse: Codable {
    var predictions: [PlacePrediction] = []
    var status: String = ""
}

struct PlaceLocation: Codable {
    var lat: Double = 0.0
    var lng: Double = 0.0
}

struct PlaceGeometry: Codable {
    var location: PlaceLocation = PlaceLocation()
}

struct PlaceDetailResult: Codable {
    var formattedAddress: String = ""
    var geometry: PlaceGeometry = PlaceGeometry()

    enum CodingKeys: String, CodingKey {
        case formattedAddress = "formatted_address"
        case geometry
    }
}

struct PlaceDetailsResponse: Codable {
    var result: PlaceDetailResult = PlaceDetailResult()
    var status: String = ""
}

struct GooglePlace {
    let address: String
    let latitude: Double
    let longitude: Double
}

class GooglePlacesService {
    static let shared = GooglePlacesService()

    // Resolves MAPS_API_KEY from Info.plist; falls back to the SDK key from
    // DoerApp.swift if the build setting wasn't substituted (the literal
    // "$(MAPS_API_KEY)" leaks through and Google rejects the request).
    private let apiKey: String = {
        let fallback = "AIzaSyDCmj86d3XA-GvAonJowP1ujnzCf7TDKAE"
        guard let key = Bundle.main.object(forInfoDictionaryKey: "MAPS_API_KEY") as? String,
              !key.isEmpty,
              !key.hasPrefix("$(") else {
            return fallback
        }
        return key
    }()

    private let baseUrl = "https://maps.googleapis.com/maps/api/place"

    func getPlacesByText(searchText: String) async -> [PlacePrediction] {
        guard let encoded = searchText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseUrl)/autocomplete/json?input=\(encoded)&key=\(apiKey)") else {
            return []
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            let result = try decoder.decode(PlaceAutoCompleteResponse.self, from: data)
            if result.status != "OK" && result.status != "ZERO_RESULTS" {
                let body = String(data: data, encoding: .utf8) ?? ""
                print("GooglePlacesService autocomplete failed: status=\(result.status) body=\(body)")
            }
            return result.predictions
        } catch {
            if (error as NSError).code != NSURLErrorCancelled {
                print("GooglePlacesService autocomplete error: \(error)")
            }
            return []
        }
    }

    func getPlaceDetails(placeId: String) async -> GooglePlace? {
        guard let url = URL(string: "\(baseUrl)/details/json?placeid=\(placeId)&key=\(apiKey)") else {
            return nil
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            let result = try decoder.decode(PlaceDetailsResponse.self, from: data)
            if result.status != "OK" {
                let body = String(data: data, encoding: .utf8) ?? ""
                print("GooglePlacesService details failed: status=\(result.status) body=\(body)")
                return nil
            }
            return GooglePlace(
                address: result.result.formattedAddress,
                latitude: result.result.geometry.location.lat,
                longitude: result.result.geometry.location.lng
            )
        } catch {
            if (error as NSError).code != NSURLErrorCancelled {
                print("GooglePlacesService details error: \(error)")
            }
            return nil
        }
    }
}
