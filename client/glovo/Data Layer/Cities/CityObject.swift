import UIKit
import RealmSwift

final class CityObject: Object, Syncable {
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

    @objc dynamic var workingArea: String = ""
    @objc dynamic var workingAreaProper: String = ""
    @objc dynamic var code: String = ""
    @objc dynamic var name: String = ""
    @objc dynamic var countryCode: String = ""

    convenience init(dto: SyncableDTO<CityObject>) {
        self.init()
        code = dto.syncIdentifier()
        dto.update(object: self)
    }
}
