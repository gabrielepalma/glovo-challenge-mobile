final class CityDTO: Codable {
    var workingArea: [String]
    var code: String
    var name: String
    var countryCode: String

    enum CodingKeys: String, CodingKey {
        case workingArea = "working_area"
        case countryCode = "country_code"
        case code
        case name
    }
}
