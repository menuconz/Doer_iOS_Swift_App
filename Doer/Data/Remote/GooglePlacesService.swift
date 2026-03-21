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

    private let apiKey: String = {
        if let key = Bundle.main.object(forInfoDictionaryKey: "MAPS_API_KEY") as? String {
            return key
        }
        return ""
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
            return result.predictions
        } catch {
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
            return GooglePlace(
                address: result.result.formattedAddress,
                latitude: result.result.geometry.location.lat,
                longitude: result.result.geometry.location.lng
            )
        } catch {
            return nil
        }
    }
}
