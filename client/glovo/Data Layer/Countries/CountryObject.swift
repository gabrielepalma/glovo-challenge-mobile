import UIKit
import RealmSwift

final class CountryObject: Object, Syncable {
    override public class func ignoredProperties() -> [String] {
        return ["syncIdentifier"]
    }

    override public static func primaryKey() -> String? {
        return "localId"
    }

    override static func indexedProperties() -> [String] {
        return ["code"]
    }

    var syncIdentifier: String {
        return code
    }

    @objc dynamic var localId: String = UUID().uuidString

    @objc dynamic var name: String = ""
    @objc dynamic var code: String = ""

    convenience init(dto: SyncableDTO<CountryObject>) {
        self.init()
        code = dto.syncIdentifier()
        dto.update(object: self)
    }
}
