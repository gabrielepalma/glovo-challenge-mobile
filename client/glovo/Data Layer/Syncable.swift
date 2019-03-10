import Foundation
import RealmSwift
import PromiseKit

open class SyncableDTO<T> where T : Syncable {
    public init() {
    }

    public init(from object: T) {
    }

    open func update(object : T) {
    }

    open func syncIdentifier() -> String {
        return ""
    }
}

open class NetworkClient<T>  where T : Syncable {
    public init() {
    }
    
    open func fetchAll() -> Promise<[SyncableDTO<T>]> {
        return Promise(error: NSError(domain: "networkclient", code: 900, userInfo: ["reason" : "Unsupported operation"]))
    }

    
}

public protocol Syncable where Self : Object {
    var syncIdentifier : String { get }
}
