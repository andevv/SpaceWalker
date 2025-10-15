//
//  MapViewController.swift
//  SpaceWalker
//
//  Created by andev on 9/30/25.
//

import UIKit
import MapKit
import SnapKit
import CoreLocation
import RealmSwift

final class MapViewController: UIViewController {

    private let mapView = MKMapView()
    private let locationManager = CLLocationManager()
    private var realmToken: NotificationToken?

    // Preserve previous tab bar appearance so changes are scoped to Map tab only
    private var previousTabBarStandardAppearance: UITabBarAppearance?
    private var previousTabBarScrollEdgeAppearance: UITabBarAppearance?
    private var previousTabBarIsTranslucent: Bool?

    override func viewDidLoad() {
        super.viewDidLoad()
        //title = "Map"
        view.backgroundColor = .systemBackground

        setupMap()
        requestLocation()
        addPinsFromRealm()
        startObservingRealm()
        zoomToAllAnnotations(animated: false)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if #available(iOS 26, *) {
            // iOS 26+: keep existing behavior — no special tab bar appearance needed
        } else {
            // iOS 18 and below: apply opaque tab bar appearance while Map is visible
            if let tb = self.tabBarController?.tabBar {
                previousTabBarStandardAppearance = tb.standardAppearance
                previousTabBarScrollEdgeAppearance = tb.scrollEdgeAppearance
                previousTabBarIsTranslucent = tb.isTranslucent
            }
            configureTabBarAppearance()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if #available(iOS 26, *) {
            // iOS 26+: nothing to restore
        } else {
            // iOS 18 and below: restore previous appearance so other tabs aren't affected
            if let tb = self.tabBarController?.tabBar {
                if let prevStd = previousTabBarStandardAppearance { tb.standardAppearance = prevStd }
                if let prevScroll = previousTabBarScrollEdgeAppearance { tb.scrollEdgeAppearance = prevScroll }
                if let prevTranslucent = previousTabBarIsTranslucent { tb.isTranslucent = prevTranslucent }
            }
        }
    }
    
    private func configureTabBarAppearance() {
        guard let tb = self.tabBarController?.tabBar else { return }
        let appearance = UITabBarAppearance()
        // 기본 배경(불투명)으로 설정 — iOS 16~18에서 투명해지는 문제 방지
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .systemBackground

        tb.standardAppearance = appearance
        tb.scrollEdgeAppearance = appearance
        tb.isTranslucent = false // 추가 안전장치
    }

    private func setupMap() {
        view.addSubview(mapView)
        mapView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        mapView.delegate = self
        mapView.showsUserLocation = true
        mapView.pointOfInterestFilter = .includingAll
    }

    private func requestLocation() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.startUpdatingLocation()
    }

    private func addPinsFromRealm() {
        do {
            // Clear existing non-user annotations to avoid duplicates
            let existing = mapView.annotations.filter { !($0 is MKUserLocation) }
            if !existing.isEmpty { mapView.removeAnnotations(existing) }

            let realm = try Realm()
            let objects = realm.objects(PhotoMetadata.self).filter("latitude != 0 AND longitude != 0")

            let df = DateFormatter()
            df.locale = Locale(identifier: "ko_KR")
            df.dateFormat = "yyyy-MM-dd"

            let anns: [MKPointAnnotation] = objects.map { meta in
                let ann = MKPointAnnotation()
                ann.coordinate = CLLocationCoordinate2D(latitude: meta.latitude, longitude: meta.longitude)
                if let title = meta.missionTitle, !title.isEmpty {
                    ann.title = title
                } else {
                    ann.title = df.string(from: meta.capturedAt)
                }
                ann.subtitle = String(format: "%.5f, %.5f", meta.latitude, meta.longitude)
                return ann
            }
            mapView.addAnnotations(anns)
        } catch {
            print("Realm open failed: \(error)")
        }
    }

    private func startObservingRealm() {
        do {
            let realm = try Realm()
            let results = realm.objects(PhotoMetadata.self).filter("latitude != 0 AND longitude != 0")
            realmToken = results.observe { [weak self] changes in
                guard let self = self else { return }
                switch changes {
                case .initial:
                    // Initial data already loaded in viewDidLoad; ensure UI is in sync
                    DispatchQueue.main.async { self.addPinsFromRealm() }
                case .update:
                    // On insert/update/delete, refresh annotations
                    DispatchQueue.main.async { self.addPinsFromRealm() }
                case .error(let error):
                    print("Realm observe error: \(error)")
                }
            }
        } catch {
            print("Realm open failed: \(error)")
        }
    }

    private func zoomToAllAnnotations(animated: Bool) {
        let ann = mapView.annotations.filter { !($0 is MKUserLocation) }
        guard !ann.isEmpty else { return }
        mapView.showAnnotations(ann, animated: animated)
    }

    deinit {
        // Explicit invalidation can require importing the Objective-C module `Realm`.
        // Releasing the token is sufficient to stop observations.
        realmToken = nil
    }
}

// MARK: - MKMapViewDelegate
extension MapViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation { return nil }
        // 기본 시스템 핀 사용
        return nil
    }
}
