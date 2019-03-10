import UIKit
import PromiseKit
import RxSwift
import Foundation

public class NetworkResponse<T> {
    public private(set) var meta: URLResponse
    public private(set) var body: T

    public init(meta: URLResponse, body: T) {
        self.meta = meta
        self.body = body
    }
}

public protocol NetworkConfigurationProtocol {
    var baseUrl : String { get }
}

public struct Request {
    public enum Method : String {
        case POST = "POST"
        case GET = "GET"
        case DELETE = "DELETE"
        case PUT = "PUT"
    }

    public enum ContentType : String {
        case JSON = "application/json"
    }

    public var method : Method = .GET
    public var contentType : ContentType = .JSON
    public var path : String
    public var body : Data?

    public init(method : Method = .GET, contentType : ContentType = .JSON, path : String, body : Data? = nil) {
        self.method = method
        self.contentType = contentType
        self.path = path
        self.body = body
    }
}

public protocol NetworkManagerProtocol {
    func makeRequest<T : Codable>(request : Request, responseType: [T.Type]) -> Promise<[T]>
    func makeRequest<T : Codable>(request : Request, responseType: T.Type) -> Promise<T>
}

public class NetworkManager : NetworkManagerProtocol {
    public var networkConfiguration : NetworkConfigurationProtocol

    public init(networkConfiguration : NetworkConfigurationProtocol) {
        self.networkConfiguration = networkConfiguration
    }

    public func makeRequest<T>(request: Request, responseType: T.Type) -> Promise<T> where T : Decodable, T : Encodable {

        return makeRequestInternal(request: request)
            .map({ (response) -> T in
                return try JSONDecoder().decode(T.self, from: response.body)
            })
    }

    public func makeRequest<T>(request: Request, responseType: [T.Type]) -> Promise<[T]> where T : Decodable, T : Encodable {

        return makeRequestInternal(request: request)
            .map({ (response) -> [T] in
                return try JSONDecoder().decode([T].self, from: response.body)
            })
    }

    private func makeRequestInternal(request : Request) -> Promise<NetworkResponse<Data>> {
        guard let base = URL(string: networkConfiguration.baseUrl) else {
            return Promise<NetworkResponse<Data>>(error: NSError(domain: "NetworkManager", code: 599, userInfo: ["reason" : "URL was invalid "] ))
        }

        let url = base.appendingPathComponent(request.path)
        var urlRequest = URLRequest(url: url)

        urlRequest.cachePolicy = .useProtocolCachePolicy
        urlRequest.setValue(request.contentType.rawValue, forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = request.body
        urlRequest.httpMethod = request.method.rawValue

        return URLSession.shared.dataTask(.promise, with: urlRequest)
            .validate()
            .map { (response : (data: Data, response: URLResponse)) -> NetworkResponse<Data> in
                NetworkResponse(meta: response.response, body: response.data)
        }
    }
}

public class NetworkConfiguration : NetworkConfigurationProtocol {
    public var environment : Environment = .local

    public enum Environment : String {
        case local = "http://localhost:3000"
        case ngrok = "http://89e66a5c.ngrok.io"
    }

    public var baseUrl: String {
        get {
            return environment.rawValue
        }
    }
}
