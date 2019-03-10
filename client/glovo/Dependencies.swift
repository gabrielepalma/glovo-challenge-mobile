import UIKit
import RealmSwift
import Reachability
import Swinject

extension Container {
    static let glovo = Container()
}

extension AppDelegate {
    func initDependencies() {
        Container.glovo
            .register(Reachability.self){ r -> Reachability in
                let reachability = Reachability()!
                try! reachability.startNotifier()
                return reachability
            }
            .inObjectScope(.container)

        Container.glovo
            .register(NetworkConfigurationProtocol.self) { (r) -> NetworkConfigurationProtocol in
                return NetworkConfiguration()
            }
            .inObjectScope(.container)

        Container.glovo
            .register(NetworkManagerProtocol.self) { (r) -> NetworkManagerProtocol in
                return NetworkManager(
                    networkConfiguration: r.resolve(NetworkConfigurationProtocol.self)!)
            }
            .inObjectScope(.weak)

        Container.glovo
            .register(NetworkClient<CityObject>.self) { (r) -> NetworkClient<CityObject> in
                return CitiesNetworkClient(networkManager: r.resolve(NetworkManagerProtocol.self)!)
            }
            .inObjectScope(.weak)

        Container.glovo
            .register(NetworkClient<CountryObject>.self) { (r) -> NetworkClient<CountryObject> in
                return CountriesNetworkClient(networkManager: r.resolve(NetworkManagerProtocol.self)!)
            }
            .inObjectScope(.weak)

        Container.glovo
            .register(Syncer<CityObject>.self) { (r) -> Syncer<CityObject> in
                let syncer = Syncer<CityObject>(
                    networkClient: r.resolve(NetworkClient.self)!,
                    realmConfiguration: Realm.Configuration.forGlovo(),
                    reachability: r.resolve(Reachability.self)!)
                syncer.activate()
                return syncer
            }
            .inObjectScope(.weak)

        Container.glovo
            .register(Syncer<CountryObject>.self) { (r) -> Syncer<CountryObject> in
                let syncer = Syncer<CountryObject>(
                    networkClient: r.resolve(NetworkClient.self)!,
                    realmConfiguration: Realm.Configuration.forGlovo(),
                    reachability: r.resolve(Reachability.self)!)
                syncer.activate()
                return syncer
            }
            .inObjectScope(.weak)
    }
}

extension Realm.Configuration {
    static var glovoSchemaVersion : UInt64 = 10000
    static func forGlovo() -> Realm.Configuration {
        let fileURL = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("glovo.realm")
        var configuration = Realm.Configuration(fileURL: fileURL, objectTypes: [CityObject.self, CountryObject.self])
        configuration.schemaVersion = Realm.Configuration.glovoSchemaVersion
        configuration.migrationBlock = { migration, oldSchemaVersion in
        }
        return configuration
    }
}
