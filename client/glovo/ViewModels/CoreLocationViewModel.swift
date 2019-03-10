import UIKit
import RxSwift
import RxCocoa
import CoreLocation

enum LocationState {
    case undefined
    case askingPermission
    case userRefusedPermissions
    case isDeniedOrRestricted
    case hasLocation(location: CLLocation)
}

final class CoreLocationViewModel : NSObject, CLLocationManagerDelegate {
    private var manager = CLLocationManager()
    private var internalState = BehaviorRelay<LocationState>(value: .undefined)
    public var state: Driver<LocationState> {
        get {
            return internalState.asDriver()
        }
    }

    override init() {
        super.init()
        manager.delegate = self
    }

    public func askForLocation() {
        actOnAuthorizationStatus()
    }

    func actOnAuthorizationStatus() {
        if CLLocationManager.locationServicesEnabled() {
            switch CLLocationManager.authorizationStatus() {
            case .notDetermined:
                internalState.accept(.askingPermission)
                manager.requestWhenInUseAuthorization()
            case .authorizedAlways, .authorizedWhenInUse:
                manager.requestLocation()
            case .restricted, .denied:
                if case .askingPermission = internalState.value {
                    internalState.accept(.userRefusedPermissions)
                }
                internalState.accept(.isDeniedOrRestricted)
            }
        }
        else {
            internalState.accept(.isDeniedOrRestricted)
        }
    }

    // CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            internalState.accept(.hasLocation(location: location))
        }
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        actOnAuthorizationStatus()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    }
}
