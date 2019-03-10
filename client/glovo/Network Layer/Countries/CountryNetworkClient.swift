import UIKit
import PromiseKit

final class CountriesNetworkClient: NetworkClient<CountryObject> {
    var networkManager : NetworkManagerProtocol

    init(networkManager : NetworkManagerProtocol) {
        self.networkManager = networkManager
    }

    override func fetchAll() -> Promise<[SyncableDTO<CountryObject>]> {
        let request = Request(method: .GET, contentType: .JSON, path: "api/countries")
        return Promise<[SyncableDTO<CountryObject>]>(resolver: { (resolver) in
            networkManager.makeRequest(request: request, responseType: [CountrySyncableDTO.self]).done({ (response) in
                resolver.fulfill(response)
            }).catch({ (error) in
                resolver.reject(error)
            })
        })
    }
}
