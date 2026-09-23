import Foundation
import CoreLocation
import Observation

/// Asks once, remembers the answer, falls back to Fitzroy so the app always has a "near you".
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    static let fallback = CLLocationCoordinate2D(latitude: -37.7986, longitude: 144.9784) // Fitzroy

    private let manager = CLLocationManager()
    var coordinate: CLLocationCoordinate2D = LocationService.fallback
    var status: CLAuthorizationStatus = .notDetermined
    var isUsingRealLocation = false
    var suburbGuess: String = "Fitzroy"

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        status = manager.authorizationStatus
    }

    var hasAsked: Bool { status != .notDetermined }
    var isAllowed: Bool { status == .authorizedWhenInUse || status == .authorizedAlways }

    func request() {
        if status == .notDetermined { manager.requestWhenInUseAuthorization() } else if isAllowed { manager.requestLocation() }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        status = manager.authorizationStatus
        if isAllowed { manager.requestLocation() }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        coordinate = loc.coordinate
        isUsingRealLocation = true
        CLGeocoder().reverseGeocodeLocation(loc) { [weak self] marks, _ in
            if let s = marks?.first?.locality ?? marks?.first?.subLocality { self?.suburbGuess = s }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) { }
}
