//
//  UserLocationViewModel.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/08/27.
//

import Foundation
import CoreLocation
import Combine

enum UserLocationStatus {
    case notDetermined
    case restricted
    case denied
    case authorizedWaitingLocation
    case available
}

class UserLocationViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    
    private var locationManager = CLLocationManager()
    private let logger = Logger.shared
    private var cancellables: Set<AnyCancellable> = []
    
    @Published var authorizationStatus: CLAuthorizationStatus?
    @Published var location: CLLocation? = nil
    @Published var status: UserLocationStatus = .notDetermined
    static let shared = UserLocationViewModel()
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.activityType = .fitness
        locationManager.distanceFilter = 100.0
        self.authorizationStatus = locationManager.authorizationStatus
        self.updateStatus(locationManager.authorizationStatus)
        locationManager.startUpdatingLocation()
    }

    private func updateStatus(_ authStatus: CLAuthorizationStatus) {
        switch authStatus {
        case .notDetermined:
            self.status = .notDetermined
        case .restricted:
            self.status = .restricted
        case .denied:
            self.status = .denied
        case .authorizedWhenInUse, .authorizedAlways:
            if self.location != nil {
                self.status = .available
            } else {
                self.status = .authorizedWaitingLocation
            }
        @unknown default:
            self.status = .denied
        }
    }
 
    public func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
            DispatchQueue.main.async {
                self.logger.info("autorization status of user location did change: \(self.authorizationStatus ?? .notDetermined) -> \(status)")
                
                self.authorizationStatus = status
                self.updateStatus(status)
                
                if status == .authorizedWhenInUse || status == .authorizedAlways {
                    self.locationManager.startUpdatingLocation()
                } else {
                    self.logger.warning("some functions of the service are not available because location permissions have not been granted.")
                }
            }
        }
        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            if let lastLocation = locations.last {
                DispatchQueue.main.async {
                    self.location = lastLocation
                    CoreDataStack.shared.save(UserLocation(
                        longitude: self.location?.coordinate.longitude ?? .zero,
                        latitude: self.location?.coordinate.latitude ?? .zero)
                    )
                    NotificationCenter.default.post(name: .sendLocationNotification, object: nil, userInfo: ["lastLocation": lastLocation])
                    
                    if self.status == .authorizedWaitingLocation {
                        self.status = .available
                    }
                }
                self.logger.info("updated location: (\(lastLocation.coordinate.latitude), \(lastLocation.coordinate.longitude))")
            }
        }
 
    func locationManager(_ managger: CLLocationManager, didFailWithError error: Error) {
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                logger.warning("denided access to user locatino. Please check your settings.: \(error.localizedDescription)")
            case .locationUnknown:
                logger.warning("location is currently unknown, but it may be available latter.:\(error.localizedDescription)")
            default:
                logger.warning("location menagaer failed.: \(error.localizedDescription)")
            }
        } else {
            logger.warning("failed tp get location: \(error.localizedDescription)")
        }
    }
}
