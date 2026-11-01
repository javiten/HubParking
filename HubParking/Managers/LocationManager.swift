import CoreLocation
import MapKit

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationServicesEnabled = CLLocationManager.locationServicesEnabled()
    @Published var isUpdatingLocation = false
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone
        
        // Check initial states
        locationServicesEnabled = CLLocationManager.locationServicesEnabled()
        authorizationStatus = manager.authorizationStatus
        
        // Start periodic check for location services
        startLocationServicesCheck()
    }
    
    private func startLocationServicesCheck() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.global(qos: .background).async {
                let enabled = CLLocationManager.locationServicesEnabled()
                DispatchQueue.main.async {
                    if self?.locationServicesEnabled != enabled {
                        self?.locationServicesEnabled = enabled
                        if enabled {
                            self?.checkAuthorizationAndStartUpdating()
                        }
                    }
                }
            }
        }
    }
    
    func requestPermission() {
        guard locationServicesEnabled else {
            print("Location services are disabled")
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.manager.requestWhenInUseAuthorization()
        }
    }
    
    private func checkAuthorizationAndStartUpdating() {
        guard locationServicesEnabled else { return }
        
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            startUpdating()
        case .notDetermined:
            requestPermission()
        case .denied, .restricted:
            print("Location authorization denied or restricted")
        @unknown default:
            break
        }
    }
    
    func startUpdating() {
        guard !isUpdatingLocation else { return }
        
        DispatchQueue.main.async { [weak self] in
            self?.isUpdatingLocation = true
            self?.manager.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        DispatchQueue.main.async { [weak self] in
            self?.location = location
            print("Location updated: \(location.coordinate)")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            print("Authorization status changed to: \(status)")
            self.authorizationStatus = status
            self.checkAuthorizationAndStartUpdating()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            if let clError = error as? CLError {
                switch clError.code {
                case .denied:
                    print("Location access denied")
                    self?.authorizationStatus = .denied
                    self?.locationServicesEnabled = false
                    self?.isUpdatingLocation = false
                case .locationUnknown:
                    print("Location currently unavailable")
                case .network:
                    print("Network error occurred")
                default:
                    print("Other Core Location error: \(clError.code)")
                }
            } else {
                print("Location manager failed with error: \(error.localizedDescription)")
            }
        }
    }
    
    func getCurrentLocation() -> CLLocationCoordinate2D? {
        return location?.coordinate
    }
} 