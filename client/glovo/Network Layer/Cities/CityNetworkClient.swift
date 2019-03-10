import UIKit
import PromiseKit

final class CitiesNetworkClient: NetworkClient<CityObject> {
    var networkManager : NetworkManagerProtocol

    init(networkManager : NetworkManagerProtocol) {
        self.networkManager = networkManager
    }

    override func fetchAll() -> Promise<[SyncableDTO<CityObject>]> {
        let request = Request(method: .GET, contentType: .JSON, path: "api/cities")
        return Promise<[SyncableDTO<CityObject>]>(resolver: { (resolver) in
            networkManager.makeRequest(request: request, responseType: [CitySyncableDTO.self]).done({ (response) in
                resolver.fulfill(response)
            }).catch({ (error) in
                resolver.reject(error)
            })
        })
    }

    func fetchOne(cityCode: String) -> Promise<CityDetailDTO> {
        let request = Request(method: .GET, contentType: .JSON, path: "api/cities/\(cityCode)")
        return Promise<CityDetailDTO>(resolver: { (resolver) in
            networkManager.makeRequest(request: request, responseType: CityDetailDTO.self).done({ (response) in
                resolver.fulfill(response)
            }).catch({ (error) in
                resolver.reject(error)
            })
        })
    }
}
