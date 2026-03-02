//
//  LocationManager.swift
//  Departure Board
//
//  Created by Daniel Breslan on 12/02/2026.
//

import Combine
import CoreLocation

@MainActor
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {

    @Published var userLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyReduced
        // Only auto-request if permission was already granted (i.e. returning user).
        // First-time users are prompted via requestPermissionIfNeeded() after seeing the in-app prompt.
        let status = manager.authorizationStatus
        authorizationStatus = status
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.requestLocation()
        }
    }

    /// Returns true if we should show the in-app prompt before asking iOS.
    var shouldShowPermissionPrompt: Bool {
        manager.authorizationStatus == .notDetermined
    }

    /// Called after the user taps through the in-app explanation sheet.
    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func refresh() {
        manager.requestLocation()
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        SharedDefaults.shared.set(location.coordinate.latitude,  forKey: SharedDefaults.Keys.lastKnownLatitude)
        SharedDefaults.shared.set(location.coordinate.longitude, forKey: SharedDefaults.Keys.lastKnownLongitude)
        Task { @MainActor in
            userLocation = location
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error:", error.localizedDescription)
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            authorizationStatus = status
        }
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.requestLocation()
        }
    }
}
