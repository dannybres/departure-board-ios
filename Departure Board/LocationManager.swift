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
    private var lastRefreshRequestAt: Date = .distantPast
    private var isBurstUpdating = false
    private var stopBurstTask: Task<Void, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 50
        if let seed = Self.lastKnownLocationFromDefaults() {
            userLocation = seed
        }
        // Only auto-request if permission was already granted (i.e. returning user).
        // First-time users are prompted via requestPermissionIfNeeded() after seeing the in-app prompt.
        let status = manager.authorizationStatus
        authorizationStatus = status
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            refresh(force: true)
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

    func refresh(force: Bool = false) {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else { return }
        if !force && Date().timeIntervalSince(lastRefreshRequestAt) < 8 {
            return
        }
        lastRefreshRequestAt = Date()
        manager.requestLocation()
        startBurstUpdate()
    }

    func refreshIfNeeded(minInterval: TimeInterval = 60) {
        guard Date().timeIntervalSince(lastRefreshRequestAt) >= minInterval else { return }
        refresh()
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations
            .filter({ $0.horizontalAccuracy >= 0 })
            .sorted(by: { lhs, rhs in
                if lhs.timestamp != rhs.timestamp {
                    return lhs.timestamp > rhs.timestamp
                }
                return lhs.horizontalAccuracy < rhs.horizontalAccuracy
            })
            .first else { return }
        SharedDefaults.shared.set(location.coordinate.latitude,  forKey: SharedDefaults.Keys.lastKnownLatitude)
        SharedDefaults.shared.set(location.coordinate.longitude, forKey: SharedDefaults.Keys.lastKnownLongitude)
        Task { @MainActor in
            userLocation = location
            // Stop early once we have a recent, usable fix.
            if isBurstUpdating && location.horizontalAccuracy <= 250 && abs(location.timestamp.timeIntervalSinceNow) <= 30 {
                stopBurstUpdate()
            }
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
            Task { @MainActor in
                refresh(force: true)
            }
        } else {
            Task { @MainActor in
                stopBurstUpdate()
            }
        }
    }

    private func startBurstUpdate() {
        guard !isBurstUpdating else { return }
        isBurstUpdating = true
        manager.startUpdatingLocation()
        stopBurstTask?.cancel()
        stopBurstTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(8))
            stopBurstUpdate()
        }
    }

    private func stopBurstUpdate() {
        guard isBurstUpdating else { return }
        manager.stopUpdatingLocation()
        isBurstUpdating = false
        stopBurstTask?.cancel()
        stopBurstTask = nil
    }

    private static func lastKnownLocationFromDefaults() -> CLLocation? {
        let defaults = SharedDefaults.shared
        guard defaults.object(forKey: SharedDefaults.Keys.lastKnownLatitude) != nil,
              defaults.object(forKey: SharedDefaults.Keys.lastKnownLongitude) != nil else { return nil }
        let lat = defaults.double(forKey: SharedDefaults.Keys.lastKnownLatitude)
        let lon = defaults.double(forKey: SharedDefaults.Keys.lastKnownLongitude)
        return CLLocation(latitude: lat, longitude: lon)
    }
}
