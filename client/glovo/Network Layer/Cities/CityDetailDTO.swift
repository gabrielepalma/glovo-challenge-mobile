final class CityDetailDTO: Codable {
    var code: String
    var name: String
    var currency: String
    var countryCode: String
    var enabled: Bool
    var timeZone: String
    var busy: Bool
    var languageCode: String
    var workingArea: [String]

    enum CodingKeys: String, CodingKey {
        case languageCode = "language_code"
        case countryCode = "country_code"
        case timeZone = "time_zone"
        case workingArea = "working_area"
        case code
        case name
        case currency
        case enabled
        case busy
    }
}
