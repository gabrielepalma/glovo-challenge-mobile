final class CitySyncableDTO: SyncableDTO<CityObject>, Codable {
    private var dto : CityDTO

    override func syncIdentifier() -> String {
        return dto.code
    }

    public init(from decoder: Decoder) throws {
        self.dto = try CityDTO(from : decoder)
        super.init()
    }

    public func encode(to encoder: Encoder) throws {
        try dto.encode(to: encoder)
    }

    public override func update(object: CityObject) {
        if object.code != self.dto.code {
            object.code = self.dto.code
        }
        if object.name != self.dto.name {
            object.name = self.dto.name
        }
        if object.countryCode != self.dto.countryCode {
            object.countryCode = self.dto.countryCode
        }
        let workingArea = self.dto.workingArea.joined(separator: " ")
        if object.workingArea != workingArea {
            object.workingArea = workingArea
            object.workingAreaProper = workingArea
        }

    }
}
