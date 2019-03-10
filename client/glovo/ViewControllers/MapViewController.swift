import UIKit
import RealmSwift
import RxSwift
import MapKit
import SnapKit
import CoreLocation
import Polyline

extension UIColor {
    static let glovoOrange = UIColor(red: 254.0/255.0, green: 193.0/255.0, blue: 81.0/255.0, alpha: 1.0)
}

class CityAnnotation : NSObject, MKAnnotation {
    var coordinate: CLLocationCoordinate2D
    var code: String
    init(code: String, coordinate: CLLocationCoordinate2D) {
        self.code = code
        self.coordinate = coordinate
        super.init()
    }
}

final class MapViewController: UIViewController {

    // Constants
    private let annotationIdentifier = "CityAnnotation"

    // Outlets
    private let map = MKMapView()
    private let panel = PanelView()

    // Dependencies
    private var realmConfiguration : Realm.Configuration
    private var citySyncer : Syncer<CityObject>
    private var countrySyncer : Syncer<CountryObject>
    private var cityNetworkClient : CitiesNetworkClient

    // Internal
    private var disposeBag = DisposeBag()
    private let coreLocation = CoreLocationViewModel()
    private let mapViewModel : MapViewModel
    private var cityAnnotations = [MKAnnotation]()
    private var cityCenters = [String : CLLocationCoordinate2D]()
    private var cityPolygons = [String : [MKPolygon]]()
    private var cityRects = [String : MKMapRect]()
    private var cityAnnotationsActive = false
    private var cityWasSelected = false


    init(realmConfiguration: Realm.Configuration,
         citySyncer: Syncer<CityObject>,
         countrySyncer: Syncer<CountryObject>,
         cityNetworkClient: CitiesNetworkClient)
    {
        self.realmConfiguration = realmConfiguration
        self.cityNetworkClient = cityNetworkClient
        self.citySyncer = citySyncer
        self.countrySyncer = countrySyncer
        self.mapViewModel = MapViewModel(realmConfiguration: realmConfiguration)
        super.init(nibName: nil, bundle: nil)
        self.map.delegate = self
        self.mapViewModel.dataIsReady.drive(onNext: { [weak self] (data) in
            if  let self = self, let realm = try? Realm(configuration: realmConfiguration) {
                let cities = Array(realm.objects(CityObject.self))
                self.cityRects = data.cityRects

                // Annotations
                self.map.removeAnnotations(self.cityAnnotations)
                self.cityCenters = data.cityCenters
                self.cityAnnotations = cities.compactMap({ obj -> MKAnnotation? in
                    if let coord = self.cityCenters[obj.code] {
                        return CityAnnotation(code: obj.code, coordinate: coord)
                    }
                    return nil
                })
                if self.cityAnnotationsActive {
                    self.map.addAnnotations(self.cityAnnotations)
                }

                // Overlays
                for city in cities {
                    self.map.removeOverlays(self.cityPolygons[city.code] ?? [])
                }
                self.cityPolygons = data.cityPolygons
                for city in cities {
                    self.map.addOverlays(self.cityPolygons[city.code] ?? [])
                }
            }
        }).disposed(by: disposeBag)
        self.mapViewModel.bootstrap()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Glovo"
        setupLayout()

        coreLocation.state.drive(onNext: { [weak self] (state) in
            guard let self = self, self.cityWasSelected == false else {
                return
            }
            if case let .hasLocation(location) = state {
                let viewRegion = MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 20000, longitudinalMeters: 20000)
                let adjustedRegion = self.map.regionThatFits(viewRegion)
                self.map.setRegion(adjustedRegion, animated: true)
            }
            else if case .userRefusedPermissions = state {
                self.searchTapped()
            }
        }).disposed(by: disposeBag)
        coreLocation.askForLocation()

    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        citySyncer.scheduleSyncronization()
        countrySyncer.scheduleSyncronization()
    }

    func setupLayout() {
        view.addSubview(map)
        view.addSubview(panel)

        map.snp.makeConstraints { make in
            make.top.equalTo(view)
            make.left.equalTo(view)
            make.right.equalTo(view)
            make.bottom.equalTo(view).offset(-PanelView.minimumHeight)
        }

        panel.snp.makeConstraints { make in
            make.right.equalTo(view)
            make.left.equalTo(view)
            make.bottom.equalTo(view)
        }

        panel.searchCallback = searchTapped
        panel.configureInternalConstraints()
    }

    func searchTapped() {
        let selectionController = ListViewController(realmConfiguration: realmConfiguration, citySyncer: citySyncer, countrySyncer: countrySyncer)
        selectionController.selectionConfirmed = { [weak self] selected in
            if let self = self {
                self.navigationController?.popViewController(animated: true)
                self.cityWasSelected = true
                self.centerOnCity(withCode: selected)
            }
        }
        navigationController?.pushViewController(selectionController, animated: true)
    }

    func centerOnCity(withCode: String) {
        if let rect = cityRects[withCode] {
            self.map.setVisibleMapRect(rect, edgePadding: UIEdgeInsets(top: 30, left: 30, bottom: 30, right: 30), animated: true)
        }
    }

    func updatePanel(for cityCode: String) {
        
        // To avoid unnecessary network calls
        switch panel.state.value {
        case .outOfBounds:
            break
        case .cityInfo(let code, _, _, _), .cityDetail(let code, _, _, _, _, _, _, _):
            if cityCode == code {
                return
            }
            break
        }

        guard let realm = try? Realm(configuration: realmConfiguration),
              let city = realm.object(ofType: CityObject.self, forSynchronizationId: cityCode) else {
                return
        }

        let country = realm.object(ofType: CountryObject.self, forSynchronizationId: city.countryCode)
        let cityName = city.name
        let countryName = country?.name ?? city.countryCode

        panel.state.accept(.cityInfo(code: cityCode, name: cityName, country: countryName, loadingData: true))
        DispatchQueue.global().async { [panel, cityNetworkClient] in
            cityNetworkClient.fetchOne(cityCode: cityCode)
                .done { [panel] dto in
                    panel.state.accept(.cityDetail(code: dto.code, name: dto.name, country: countryName, currency: dto.currency, timeZone: dto.timeZone, language: dto.languageCode, enabled: dto.enabled, busy: dto.busy))
                }.catch { [panel] error in
                    panel.state.accept(.cityInfo(code: cityCode, name: cityName, country: countryName, loadingData: false))
                    print("Error loading city details")
            }
        }
    }

    func updatePanel(for location: CLLocationCoordinate2D) {
        var found = false
        for city in cityRects {
            if city.value.contains(MKMapPoint(location)) {
                updatePanel(for: city.key)
                found = true
                break
            }
        }
        if !found {
            panel.state.accept(.outOfBounds)
        }
    }
}

extension MapViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {

        let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: annotationIdentifier) ?? MKAnnotationView(annotation:annotation, reuseIdentifier:annotationIdentifier)

        annotationView.annotation = annotation
        annotationView.isEnabled = true
        annotationView.snp.makeConstraints { (maker) in
            maker.height.equalTo(50)
            maker.width.equalTo(50)
        }
        annotationView.image = UIImage(named: "CityIcon")

        return annotationView
    }

    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        if let annotation = view.annotation as? CityAnnotation {
            centerOnCity(withCode: annotation.code)
        }
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let polygon = overlay as? MKPolygon {
            let renderer = MKPolygonRenderer(polygon: polygon)
            renderer.fillColor = UIColor.glovoOrange.withAlphaComponent(0.4)
            renderer.strokeColor = nil
            return renderer
        }
        return MKOverlayRenderer()
    }

    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        if mapView.region.span.latitudeDelta < 1.3 && cityAnnotationsActive {
            cityAnnotationsActive = false
            mapView.removeAnnotations(self.cityAnnotations)
        } else if mapView.region.span.latitudeDelta >= 1.3 && !cityAnnotationsActive {
            cityAnnotationsActive = true
            mapView.addAnnotations(self.cityAnnotations)
        }
        self.updatePanel(for: mapView.centerCoordinate)
    }
}
