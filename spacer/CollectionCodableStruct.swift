import Foundation


public typealias NestedCodingKeys = CodingKey & CaseIterable

public enum EmptyCodingKeys: NestedCodingKeys {}

public typealias CollectionAPIModel<T: Decodable & Equatable> = NestedCollectionAPIModel<T, EmptyCodingKeys>

public struct NestedCollectionAPIModel<T: Decodable & Equatable, NK: NestedCodingKeys>: Decodable, Equatable {

    public let items: [T]
//    public let links: LinksAPIModel

    public init(items: [T]) {
        self.items = items
//        self.links = links
    }

    public enum CodingKeys: String, CodingKey {
        case collection
        case items
        case data
    }
//    enum NodeKeys: CodingKey { case data }
    
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let root = try values.nestedContainer(keyedBy: CodingKeys.self, forKey: .collection)
        
        var itemsNode = try root.nestedUnkeyedContainer(forKey: .items)

        var itemsArr: [FailableDecodable<T>] = []
        
//        var dataItems = try itemsNode.nestedUnkeyedContainer(forKey: .data)
        while !itemsNode.isAtEnd {
            if let element = try? itemsNode.decode(T.self) {
                itemsArr.append(FailableDecodable(element))
            } else {
                let nestedValue = try itemsNode.nestedContainer(keyedBy: NK.self)
                for key in NK.allCases {
                    if let element = try? nestedValue.decode(FailableDecodable<T>.self, forKey: key) {
                        itemsArr.append(element)
                    }
                }
            }
        }

        items = itemsArr.compactMap { $0.base }
    }
}
public struct FailableDecodable<Base: Decodable & Equatable>: Decodable {

    public let base: Base?

    public init(_ base: Base) {
        self.base = base
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        do {
            base = try container.decode(Base.self)
        } catch {
            base = nil
        }
    }
}

extension Array where Element == FailableDecodable<URL> {
    public var urls: [URL] {
        return compactMap { $0.base }
    }
}


public struct LinksAPIModel: Codable {

    typealias LinksDictionary = [String: [String: String]]
    public let links: [LinkModel]

    public init(links: [LinkModel]) {
        self.links = links
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.singleValueContainer()
        let linksDictionary = try values.decode(LinksDictionary.self)

        links = try linksDictionary.map { key, value in
            try LinkModel(key: key, value: value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        var linksDictionary: [String: [String: String]] = [:]
        for link in links {
            linksDictionary[link.name] = ["href": link.href.absoluteString]
        }
        try container.encode(linksDictionary)
    }
}

extension LinksAPIModel {
    public var count: Int {
        return links.count
    }
}

extension LinksAPIModel: Equatable {
    public static func == (lhs: LinksAPIModel, rhs: LinksAPIModel) -> Bool {
        return lhs.links == rhs.links
    }
}

public struct LinkModel: Equatable, Codable {
    public let name: String
    public let href: URL

    public init(name: String, href: URL) {
        self.name = name
        self.href = href
    }

    public init(key: String, value: [String: String]) throws {
        guard
            let hrefString = value["href"],
            let href = URL(string: hrefString) else { throw ServiceError.unknown }

        name = key
        self.href = href
    }

    public static func == (lhs: LinkModel, rhs: LinkModel) -> Bool {
        return lhs.name == rhs.name && lhs.href == rhs.href
    }
}
