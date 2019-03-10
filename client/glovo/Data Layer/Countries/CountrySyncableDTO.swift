final class CountrySyncableDTO: SyncableDTO<CountryObject>, Codable {
    public var dto : CountryDTO

    override func syncIdentifier() -> String {
        return dto.code
    }

    public init(from decoder: Decoder) throws {
        self.dto = try CountryDTO(from : decoder)
        super.init()
    }

    public func encode(to encoder: Encoder) throws {
        try dto.encode(to: encoder)
    }

    override func update(object: CountryObject) {
        if object.code != self.dto.code {
            object.code = self.dto.code
        }
        if object.name != self.dto.name {
            object.name = self.dto.name
        }
    }
}
