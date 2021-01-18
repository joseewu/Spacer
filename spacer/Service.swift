import Foundation
import Combine

protocol Servicing {
    func fetch() -> AnyPublisher<NestedCollectionAPIModel<SpaceApiModel, SpaceApiModel.NestedCodingKey>, ServiceError>
}

/*
 https://images-api.nasa.gov/search
--data-urlencode "q=apollo 11"
--data-urlencode "description=moon landing"
--data-urlencode "media_type=image"
 */

//TODO: add http cache mechanism

final class Service: Servicing {
    var urlComponents:URLComponents {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "images-api.nasa.gov"
        components.path = "/search"
        components.queryItems = [URLQueryItem(name: "q", value: "apollo 19"),URLQueryItem(name: "description", value: "moon landing"),URLQueryItem(name: "media_type", value: "image")]
        return components
    }
    func fetch() -> AnyPublisher<NestedCollectionAPIModel<SpaceApiModel, SpaceApiModel.NestedCodingKey>, ServiceError> {
        
        guard let url = urlComponents.url else {
            return Future<NestedCollectionAPIModel<SpaceApiModel, SpaceApiModel.NestedCodingKey>, ServiceError> { $0(.failure(.unknown)) }.eraseToAnyPublisher()
        }
        return fetch(from: url)
    }
    
    private func fetch(from url:URL) -> AnyPublisher<NestedCollectionAPIModel<SpaceApiModel, SpaceApiModel.NestedCodingKey>, ServiceError>{
        return URLSession.shared.dataTaskPublisher(for: url)
            .tryMap { data, response in
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ServiceError.unknown
            }
            if (httpResponse.statusCode == 401) {
                throw ServiceError.serviceError(reason: "Unauthorized");
            }
            if (httpResponse.statusCode == 403) {
                throw ServiceError.serviceError(reason: "Resource forbidden");
            }
            if (httpResponse.statusCode == 404) {
                throw ServiceError.serviceError(reason: "Resource not found");
            }
            if (405..<500 ~= httpResponse.statusCode) {
                throw ServiceError.serviceError(reason: "client error");
            }
            if (500..<600 ~= httpResponse.statusCode) {
                throw ServiceError.serviceError(reason: "server error");
            }
            return data
        }
        .decode(type: NestedCollectionAPIModel<SpaceApiModel, SpaceApiModel.NestedCodingKey>.self, decoder: JSONDecoder())
        .mapError({ error -> ServiceError in
            if let error = error as? ServiceError {
                return error
            }
            return ServiceError.unknown
        })
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}

struct NestedCollection<T:Decodable>:Decodable {
    let collection:T
}

struct Items<T:Decodable>:Decodable {
    enum CodingKeys: String, CodingKey {
        case items
        case data
    }
    let datas:[T]
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let items = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .items)
        datas = try items.decode([T].self, forKey: .data)
    }
}

struct Space {
    let id:String
    let title:String
    let description:String
    let imageUrlString:String
}

struct SpaceApiModel: Codable,Equatable {
    let createDate:Date
    let title:String
    let id:String
    
    public enum CodingKeys: String, CodingKey {
        case id = "nasa_id"
        case createDate = "date_created"
        case title
    }
    
    public enum NestedCodingKey: String, CodingKey, CaseIterable {
        case data
    }
    
    
}



enum ServiceError: Error, LocalizedError {
    case unknown, serviceError(reason: String), parserError(reason: String), networkError(from: URLError)
    
    var errorDescription: String? {
        switch self {
        case .unknown:
            return "Unknown error"
        case .serviceError(let reason), .parserError(let reason):
            return reason
        case .networkError(let from):
            return from.localizedDescription
        }
    }
}
