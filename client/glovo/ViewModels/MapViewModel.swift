import UIKit
import RealmSwift
import MapKit
import Polyline
import RxSwift
import RxRealm
import RxCocoa

struct MapData {
    static func empty() -> MapData {
        return MapData(cityCenters: [String : CLLocationCoordinate2D](), cityPolygons: [String : [MKPolygon]](), cityRects: [String : MKMapRect]())
    }
    let cityCenters : [String : CLLocationCoordinate2D]
    let cityPolygons : [String : [MKPolygon]]
    let cityRects : [String : MKMapRect]
}

class MapViewModel {
    private let realmConfiguration: Realm.Configuration
    private var disposeBag = DisposeBag()

    private let internalDataIsReady = BehaviorRelay<MapData>(value: MapData.empty())
    public var dataIsReady: Driver<MapData> {
        get {
            return internalDataIsReady.asDriver(onErrorJustReturn: MapData.empty())
        }
    }

    init(realmConfiguration : Realm.Configuration) {
        self.realmConfiguration = realmConfiguration

        if let realm = try? Realm(configuration: realmConfiguration) {
            let cities = realm.objects(CityObject.self)
            Observable
                .changeset(from: cities, synchronousStart: false)
                .skip(1)
                .observeOn(ConcurrentDispatchQueueScheduler(qos: .background))
                .subscribe({ [weak self] (next) in
                    self?.setupDataSources()
                })
                .disposed(by: disposeBag)
        }

    }

    public func bootstrap() {
        DispatchQueue.global().async { [weak self] in
            self?.setupDataSources()
        }
    }

    private func setupDataSources() {
        if let realm = try? Realm(configuration: realmConfiguration) {
            let cities = realm.objects(CityObject.self)
            var cityCenters = [String : CLLocationCoordinate2D]()
            var cityPolygons = [String : [MKPolygon]]()
            var cityRects = [String : MKMapRect]()
            for city in cities {
                let polylines = city.workingArea.split(separator: " ").compactMap { substring -> Polyline? in
                    return Polyline(encodedPolyline: String(substring))
                }
                cityCenters[city.code] = centerCoordinate(with: polylines)
                cityPolygons[city.code] = polygons(from: polylines)
                var rect = MKMapRect.null
                for polygon in cityPolygons[city.code] ?? [] {
                    rect = rect.union(polygon.boundingMapRect)
                }
                cityRects[city.code] = rect
            }

            internalDataIsReady.accept(MapData(cityCenters: cityCenters, cityPolygons: cityPolygons, cityRects: cityRects))
        }
    }

    private func polygons(from polylines: [Polyline]) -> [MKPolygon] {
        return polylines.compactMap({ polyline -> MKPolygon? in
            if var coordinates = polyline.coordinates {
                return MKPolygon(coordinates: &coordinates, count: coordinates.count)
            }
            return nil
        })
    }

    private func centerCoordinate(with polylines: [Polyline]) -> CLLocationCoordinate2D? {
        var latitude = 0.0
        var longitude = 0.0
        var count = 0.0
        for polyline in polylines {
            for coordinate in polyline.coordinates ?? [] {
                latitude += coordinate.latitude
                longitude += coordinate.longitude
                count += 1
            }
        }
        return count > 0 ? CLLocationCoordinate2D(latitude: latitude/count, longitude: longitude/count) : nil
    }
}
