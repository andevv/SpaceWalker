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
import RxSwift
import RxCocoa

final class MapViewController: UIViewController {

    private let mapView = MKMapView()
    private let locationManager = CLLocationManager()
    private var didPerformInitialZoom = false

    // MARK: - Chips
    private let chipScrollView = UIScrollView()
    private let chipStack = UIStackView()
    private var chipModels: [MapSpaceChipModel] = []

    // MARK: - ViewModel
    private let viewModel = MapViewModel()
    private let disposeBag = DisposeBag()
    private let viewDidLoadRelay = PublishRelay<Void>()
    private let spaceSelectionRelay = PublishRelay<Int?>()

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

    // Preserve previous tab bar appearance so changes are scoped to Map tab only
    private var previousTabBarStandardAppearance: UITabBarAppearance?
    private var previousTabBarScrollEdgeAppearance: UITabBarAppearance?
    private var previousTabBarIsTranslucent: Bool?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        setupMap()
        requestLocation()
        bindViewModel()
        viewDidLoadRelay.accept(())
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

    private func bindViewModel() {
        let input = MapViewModel.Input(
            viewDidLoad: viewDidLoadRelay.asObservable(),
            spaceSelection: spaceSelectionRelay.asObservable()
        )

        let output = viewModel.transform(input: input)

        output.chips
            .drive(onNext: { [weak self] chips in
                self?.chipModels = chips
                self?.reloadChips()
            })
            .disposed(by: disposeBag)

        output.pins
            .emit(onNext: { [weak self] pins in
                self?.applyPins(pins)
            })
            .disposed(by: disposeBag)

        output.errors
            .emit(onNext: { message in
                print(message)
            })
            .disposed(by: disposeBag)
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

    private func applyPins(_ pins: [MapPinModel]) {
        // Clear existing non-user annotations to avoid duplicates
        let existing = mapView.annotations.filter { !($0 is MKUserLocation) }
        if !existing.isEmpty { mapView.removeAnnotations(existing) }

        let annotations = pins.map { pin -> MKPointAnnotation in
            let ann = MKPointAnnotation()
            ann.coordinate = CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)
            ann.title = pin.title
            ann.subtitle = pin.subtitle
            return ann
        }
        mapView.addAnnotations(annotations)

        if !didPerformInitialZoom {
            zoomToAllAnnotations(animated: false)
            didPerformInitialZoom = true
        }
    }

    private func zoomToAllAnnotations(animated: Bool) {
        let ann = mapView.annotations.filter { !($0 is MKUserLocation) }
        guard !ann.isEmpty else { return }
        mapView.showAnnotations(ann, animated: animated)
    }

    // MARK: - Chips
    private func reloadChips() {
        for sub in chipStack.arrangedSubviews {
            chipStack.removeArrangedSubview(sub)
            sub.removeFromSuperview()
        }

        for chip in chipModels {
            let b = makeChipButton(title: chip.title, selected: chip.isSelected)
            b.tag = chip.id ?? -1
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
        b.backgroundColor = .white
        if selected {
            b.setTitleColor(accent, for: .normal)
            b.layer.borderColor = accent.cgColor
        } else {
            b.setTitleColor(.label, for: .normal)
            b.layer.borderColor = UIColor.systemGray4.cgColor
        }
        b.layer.shadowColor = UIColor.black.cgColor
        b.layer.shadowOpacity = 0.12
        b.layer.shadowRadius = 6
        b.layer.shadowOffset = CGSize(width: 0, height: 2)
    }

    @objc private func chipTapped(_ sender: UIButton) {
        let selectedId = (sender.tag == -1) ? nil : sender.tag

        for case let btn as UIButton in chipStack.arrangedSubviews {
            let isSelected = (btn.tag == (selectedId ?? -1))
            styleChip(btn, selected: isSelected)
        }

        // Reset initial zoom so the new filter starts with full view
        didPerformInitialZoom = false
        spaceSelectionRelay.accept(selectedId)
    }

    @objc private func didTapLocate() {
        let status = locationManager.authorizationStatus
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            if let coord = mapView.userLocation.location?.coordinate {
                let region = MKCoordinateRegion(center: coord, latitudinalMeters: 1200, longitudinalMeters: 1200)
                mapView.setRegion(region, animated: false)
            } else {
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
}

// MARK: - MKMapViewDelegate
extension MapViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation { return nil }

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

        let view = mapView.dequeueReusableAnnotationView(withIdentifier: "PhotoPin") as? MKMarkerAnnotationView
            ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "PhotoPin")
        view.annotation = annotation
        view.clusteringIdentifier = "photo"
        view.canShowCallout = true
        view.markerTintColor = .systemGreen
        view.glyphImage = UIImage(systemName: "photo")
        view.displayPriority = .defaultLow
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
