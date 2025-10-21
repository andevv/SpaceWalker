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
import RxSwift

final class MapViewController: UIViewController {

    private let mapView = MKMapView()
    private let locationManager = CLLocationManager()
    private var realmToken: NotificationToken?
    private var didPerformInitialZoom = false

    // MARK: - Chips & Filtering
    private let chipScrollView = UIScrollView()
    private let chipStack = UIStackView()
    private var joinedSpaces: [JoinedSpace] = []
    private var selectedSpaceId: Int? = nil // nil = 전체

    // MARK: - Data
    private let repository = SpaceRepository()
    private let disposeBag = DisposeBag()

    // Floating button to move camera to user's current location
    private lazy var locateButton: UIButton = {
        let b = UIButton(type: .system)
        b.backgroundColor = .systemBackground
        b.tintColor = .label
        b.layer.cornerRadius = 24
        b.layer.cornerCurve = .continuous
        b.layer.shadowColor = UIColor.black.cgColor
        b.layer.shadowOpacity = 0.15
        b.layer.shadowRadius = 6
        b.layer.shadowOffset = CGSize(width: 0, height: 2)
        b.layer.masksToBounds = false
        let img = UIImage(systemName: "scope")
        b.setImage(img, for: .normal)
        b.imageView?.contentMode = .scaleAspectFit
        b.contentEdgeInsets = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        b.addTarget(self, action: #selector(didTapLocate), for: .touchUpInside)
        return b
    }()

    #if DEBUG
    /// [DEBUG] 지도 테스트용 더미 데이터 사용 여부
    /// - true: Realm이 비어 있을 때 더미 핀을 1회 추가합니다.
    /// - false: 더미를 사용하지 않습니다.
    private let enableMapDummyData: Bool = true

    /// [DEBUG] 더미 핀을 이미 추가했는지 여부(중복 추가 방지)
    private var didAddMapDummyAnnotations: Bool = false
    #endif

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
        fetchMySpacesForMap()
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
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Ensure the locate button's shadow follows its rounded shape
        let radius: CGFloat = 24
        locateButton.layer.shadowPath = UIBezierPath(roundedRect: locateButton.bounds, cornerRadius: radius).cgPath
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

        // Add top chip bar (horizontal scroll)
        view.addSubview(chipScrollView)
        // Style chip container: transparent (chips themselves will have background + shadow)
        chipScrollView.backgroundColor = .clear
        chipScrollView.layer.cornerRadius = 0
        chipScrollView.layer.cornerCurve = .continuous
        chipScrollView.layer.shadowOpacity = 0
        chipScrollView.layer.shadowRadius = 0
        chipScrollView.layer.shadowOffset = .zero
        chipScrollView.clipsToBounds = false
        chipScrollView.layer.masksToBounds = false
        
        chipScrollView.showsHorizontalScrollIndicator = false
        chipScrollView.alwaysBounceHorizontal = true
        chipScrollView.alwaysBounceVertical = false

        chipScrollView.addSubview(chipStack)
        chipStack.axis = .horizontal
        chipStack.spacing = 8
        chipStack.alignment = .fill
        chipStack.distribution = .fill
        // Add content insets so chips don't touch edges
        chipStack.layoutMargins = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
        chipStack.isLayoutMarginsRelativeArrangement = true

        chipScrollView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).inset(12)
            make.leading.trailing.equalToSuperview().inset(12)
            make.height.equalTo(36)
        }
        chipStack.snp.makeConstraints { make in
            make.edges.equalTo(chipScrollView.contentLayoutGuide)
            make.height.equalTo(chipScrollView.frameLayoutGuide)
        }

        // Register annotation views for pins and clusters
        mapView.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: "PhotoPin")
        mapView.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: "PhotoCluster")
        
        // Add locate (current location) floating button
        view.addSubview(locateButton)
        locateButton.snp.makeConstraints { make in
            make.trailing.equalTo(view.safeAreaLayoutGuide).inset(16)
            make.bottom.equalTo(view.safeAreaLayoutGuide).inset(16)
            make.width.height.equalTo(48)
        }
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
            
            #if DEBUG
            // We cleared annotations above; allow dummy annotations to be added again
            didAddMapDummyAnnotations = false
            #endif

            let realm = try Realm()
            var results = realm.objects(PhotoMetadata.self).filter("latitude != 0 AND longitude != 0")
            if let sid = selectedSpaceId {
                results = results.filter("spaceId == %@", sid)
            }

            let df = DateFormatter()
            df.locale = Locale(identifier: "ko_KR")
            df.dateFormat = "yyyy-MM-dd"

            let anns: [MKPointAnnotation] = results.map { meta in
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

            // [DEBUG] Realm 데이터 유무와 관계없이 더미 핀도 함께 추가 (테스트 용도)
            #if DEBUG
            // Add dummies only when no space filter is selected (전체)
            if enableMapDummyData && selectedSpaceId == nil {
                addDummyAnnotationsIfNeeded()
            }
            #endif

            // Perform initial zoom once after annotations are added
            if !didPerformInitialZoom {
                self.zoomToAllAnnotations(animated: false)
                didPerformInitialZoom = true
            }
        } catch {
            print("Realm open failed: \(error)")
        }
    }

    #if DEBUG
    /// [DEBUG] 지도 더미 핀을 1회 추가합니다. (나중에 제거하기 쉽게 별도 메서드로 분리)
    /// - 이 메서드는 Realm에 좌표 데이터가 없을 때 테스트 용도로 호출됩니다.
    /// - 더미 위치: 서울/부산/대구/대전/광주/인천/제주 등 주요 도시 및 몇 개의 근접 포인트(클러스터링 확인용)
    private func addDummyAnnotationsIfNeeded() {
        guard enableMapDummyData, didAddMapDummyAnnotations == false else { return }

        // 더미 데이터: (위도, 경도, 타이틀)
        let base: [(Double, Double, String)] = [
            (37.5665, 126.9780, "서울 시청"),
            (37.5651, 126.9896, "서울 종로(클러스터 테스트)") ,
            (37.5700, 126.9769, "경복궁(클러스터 테스트)"),
            (35.1796, 129.0756, "부산"),
            (35.1667, 129.0720, "부산 서면(클러스터 테스트)"),
            (35.8714, 128.6014, "대구"),
            (36.3504, 127.3845, "대전"),
            (35.1595, 126.8526, "광주"),
            (37.4563, 126.7052, "인천"),
            (33.4996, 126.5312, "제주")
        ]

        // 근접 포인트 추가 (서울 주변에 몇 개 더 — 클러스터링이 잘 묶이는지 확인)
        let nearSeoul: [(Double, Double, String)] = [
            (37.5670, 126.9785, "광화문 근처 1"),
            (37.5675, 126.9790, "광화문 근처 2"),
            (37.5680, 126.9795, "광화문 근처 3")
        ]

        let all = base + nearSeoul

        var anns: [MKPointAnnotation] = []
        for (lat, lon, title) in all {
            let ann = MKPointAnnotation()
            ann.coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            ann.title = title
            ann.subtitle = String(format: "%.5f, %.5f", lat, lon)
            anns.append(ann)
        }

        mapView.addAnnotations(anns)
        didAddMapDummyAnnotations = true

        // 더미 추가 직후 초기 줌이 아직 수행되지 않았다면 전체 핀 보이기
        if !didPerformInitialZoom {
            zoomToAllAnnotations(animated: false)
            didPerformInitialZoom = true
        }
    }
    #endif

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

    // MARK: - Chips
    private func reloadChips() {
        // Remove previous chips
        for sub in chipStack.arrangedSubviews { chipStack.removeArrangedSubview(sub); sub.removeFromSuperview() }

        // "전체" chip
        let all = makeChipButton(title: "전체", selected: selectedSpaceId == nil)
        all.tag = -1 // 전체
        all.addTarget(self, action: #selector(chipTapped(_:)), for: .touchUpInside)
        chipStack.addArrangedSubview(all)

        // Space chips
        for space in joinedSpaces {
            let b = makeChipButton(title: space.name, selected: selectedSpaceId == space.id)
            b.tag = space.id
            b.addTarget(self, action: #selector(chipTapped(_:)), for: .touchUpInside)
            chipStack.addArrangedSubview(b)
        }
    }

    private func makeChipButton(title: String, selected: Bool) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        b.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        b.layer.cornerRadius = 16
        b.layer.cornerCurve = .continuous
        b.layer.borderWidth = 1
        b.layer.borderColor = UIColor.systemGray4.cgColor
        // Each chip as a floating white pill with shadow
        b.backgroundColor = .white
        b.layer.shadowColor = UIColor.black.cgColor
        b.layer.shadowOpacity = 0.12
        b.layer.shadowRadius = 6
        b.layer.shadowOffset = CGSize(width: 0, height: 2)
        b.clipsToBounds = false
        b.layer.masksToBounds = false
        styleChip(b, selected: selected)
        return b
    }

    private func styleChip(_ b: UIButton, selected: Bool) {
        let accent = UIColor(named: "AccentColor_066985") ?? .systemBlue
        // Keep white background for both states
        b.backgroundColor = .white
        if selected {
            b.setTitleColor(accent, for: .normal)
            b.layer.borderColor = accent.cgColor
        } else {
            b.setTitleColor(.label, for: .normal)
            b.layer.borderColor = UIColor.systemGray4.cgColor
        }
        // Ensure shadow remains applied (in case of state updates)
        b.layer.shadowColor = UIColor.black.cgColor
        b.layer.shadowOpacity = 0.12
        b.layer.shadowRadius = 6
        b.layer.shadowOffset = CGSize(width: 0, height: 2)
    }

    @objc private func chipTapped(_ sender: UIButton) {
        // Update selection
        selectedSpaceId = (sender.tag == -1) ? nil : sender.tag

        // Refresh chip styles
        for case let btn as UIButton in chipStack.arrangedSubviews {
            let isSelected = (btn.tag == (selectedSpaceId ?? -1))
            styleChip(btn, selected: isSelected)
        }

        // Reset initial zoom so the new filter starts with full view
        didPerformInitialZoom = false

        // Refresh annotations with new filter
        addPinsFromRealm()
    }

    // MARK: - Fetch spaces (Rx)
    private func fetchMySpacesForMap() {
        repository.fetchMySpaces()
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] joined in
                guard let self = self else { return }
                self.joinedSpaces = joined
                self.reloadChips()
            }, onFailure: { error in
                print("fetchMySpacesForMap failed: \(error.localizedDescription)")
            })
            .disposed(by: disposeBag)
    }

    @objc private func didTapLocate() {
        let status = locationManager.authorizationStatus
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            if let coord = mapView.userLocation.location?.coordinate {
                let region = MKCoordinateRegion(center: coord, latitudinalMeters: 1200, longitudinalMeters: 1200)
                mapView.setRegion(region, animated: false)
            } else {
                // If location not yet available, request and try again shortly
                locationManager.requestLocation()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                    guard let self = self, let coord = self.mapView.userLocation.location?.coordinate else { return }
                    let region = MKCoordinateRegion(center: coord, latitudinalMeters: 1200, longitudinalMeters: 1200)
                    self.mapView.setRegion(region, animated: true)
                }
            }
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        default:
            // Show a friendly alert guiding user to Settings when permission is denied/restricted
            let ac = UIAlertController(title: "위치 권한 필요",
                                       message: "현재 위치로 이동하려면 위치 접근 권한이 필요합니다.",
                                       preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "설정 열기", style: .default, handler: { _ in
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }))
            ac.addAction(UIAlertAction(title: "취소", style: .cancel))
            present(ac, animated: true)
        }
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
        // Keep default view for user location
        if annotation is MKUserLocation { return nil }

        // Customize cluster annotation view
        if let cluster = annotation as? MKClusterAnnotation {
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: "PhotoCluster") as? MKMarkerAnnotationView
                ?? MKMarkerAnnotationView(annotation: cluster, reuseIdentifier: "PhotoCluster")
            view.annotation = cluster
            view.markerTintColor = .systemBlue
            view.glyphText = "\(cluster.memberAnnotations.count)"
            view.titleVisibility = .hidden
            view.subtitleVisibility = .hidden
            view.displayPriority = .defaultHigh
            return view
        }

        // Customize individual pin annotation view and enable clustering
        let view = mapView.dequeueReusableAnnotationView(withIdentifier: "PhotoPin") as? MKMarkerAnnotationView
            ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "PhotoPin")
        view.annotation = annotation
        view.clusteringIdentifier = "photo" // Enable clustering by assigning a common identifier
        view.canShowCallout = true
        view.markerTintColor = .systemGreen
        view.glyphImage = UIImage(systemName: "photo")
        view.displayPriority = .defaultLow // Prefer clusters when zoomed out
        return view
    }

    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        guard let cluster = view.annotation as? MKClusterAnnotation else { return }
        var rect = MKMapRect.null
        for member in cluster.memberAnnotations {
            let point = MKMapPoint(member.coordinate)
            rect = rect.union(MKMapRect(x: point.x, y: point.y, width: 0, height: 0))
        }
        let padding = UIEdgeInsets(top: 60, left: 40, bottom: 60, right: 40)
        mapView.setVisibleMapRect(rect, edgePadding: padding, animated: true)
    }
}
