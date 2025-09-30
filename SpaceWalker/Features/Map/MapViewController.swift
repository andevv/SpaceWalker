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

final class MapViewController: UIViewController {

    private let mapView = MKMapView()
    private let locationManager = CLLocationManager()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Map"
        view.backgroundColor = .systemBackground

        setupMap()
        requestLocation()
        addDummyPhotoPins()
        zoomToAllAnnotations(animated: false)
    }

    private func setupMap() {
        view.addSubview(mapView)
        mapView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }

        mapView.delegate = self
        mapView.showsUserLocation = true
        mapView.pointOfInterestFilter = .includingAll

        // 클러스터링: 같은 identifier를 쓰는 annotationView가 자동 클러스터링됨
        mapView.register(PhotoAnnotationView.self,
                         forAnnotationViewWithReuseIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier)
        mapView.register(MKMarkerAnnotationView.self,
                         forAnnotationViewWithReuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier)
    }

    private func requestLocation() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.startUpdatingLocation()
    }

    // MARK: - Dummy data
    private func addDummyPhotoPins() {
        // 더미 좌표(서울/부산/인천/대전/광주 등)
        let samples: [(title: String, lat: Double, lon: Double, color: UIColor)] = [
            ("북촌", 37.5823, 126.9830, .systemGreen),
            ("성수", 37.5446, 127.0565, .systemOrange),
            ("해운대", 35.1587, 129.1604, .systemBlue),
            ("송도", 37.3826, 126.6561, .systemPink),
            ("대전역", 36.3324, 127.4347, .systemPurple),
            ("광안리", 35.1532, 129.1183, .systemTeal),
            ("한강", 37.5240, 126.9820, .systemIndigo),
            ("전주한옥마을", 35.8156, 127.1538, .systemRed),
        ]

        let annotations = samples.map { s -> PhotoAnnotation in
            let image = Self.makeColorThumb(color: s.color, size: CGSize(width: 80, height: 80))
            return PhotoAnnotation(title: s.title,
                                   coordinate: CLLocationCoordinate2D(latitude: s.lat, longitude: s.lon),
                                   thumbnail: image)
        }
        mapView.addAnnotations(annotations)
    }

    private func zoomToAllAnnotations(animated: Bool) {
        let ann = mapView.annotations.filter { !($0 is MKUserLocation) }
        guard !ann.isEmpty else { return }
        mapView.showAnnotations(ann, animated: animated)
    }

    // 단색 썸네일(라운드 처리용 원본)
    private static func makeColorThumb(color: UIColor, size: CGSize) -> UIImage {
        let rect = CGRect(origin: .zero, size: size)
        UIGraphicsBeginImageContextWithOptions(rect.size, true, 0)
        color.setFill()
        UIRectFill(rect)
        let img = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return img
    }
}

// MARK: - Annotation model
final class PhotoAnnotation: NSObject, MKAnnotation {
    let title: String?
    let coordinate: CLLocationCoordinate2D
    let thumbnail: UIImage

    init(title: String?, coordinate: CLLocationCoordinate2D, thumbnail: UIImage) {
        self.title = title
        self.coordinate = coordinate
        self.thumbnail = thumbnail
        super.init()
    }
}

// MARK: - Custom Annotation View
final class PhotoAnnotationView: MKAnnotationView {

    private let imageView = UIImageView()
    private let ringView = UIView()

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)

        // 클러스터링 활성화
        clusteringIdentifier = "photo"

        // 썸네일
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true

        // 외곽 링
        ringView.layer.borderWidth = 2
        ringView.layer.borderColor = UIColor.white.cgColor
        ringView.layer.shadowColor = UIColor.black.withAlphaComponent(0.2).cgColor
        ringView.layer.shadowOpacity = 1
        ringView.layer.shadowRadius = 3
        ringView.layer.shadowOffset = CGSize(width: 0, height: 1)

        addSubview(ringView)
        ringView.addSubview(imageView)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // 핀 크기(필요시 조절)
        let side: CGFloat = 44
        frame.size = CGSize(width: side, height: side)

        ringView.frame = bounds
        ringView.layer.cornerRadius = side / 2

        imageView.frame = ringView.bounds.insetBy(dx: 3, dy: 3)
        imageView.layer.cornerRadius = imageView.bounds.width / 2

        // 앵커(뾰족한 핀은 아니라서 가운데에 정렬)
        centerOffset = .zero
        calloutOffset = CGPoint(x: 0, y: -5)
        canShowCallout = true

        // 액세서리(미리보기 버튼 등)
        let info = UIButton(type: .detailDisclosure)
        rightCalloutAccessoryView = info
    }

    func configure(with annotation: PhotoAnnotation) {
        imageView.image = annotation.thumbnail
        accessibilityLabel = annotation.title
    }
}

// MARK: - MKMapViewDelegate
extension MapViewController: MKMapViewDelegate {

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        // 사용자 위치 기본 처리
        if annotation is MKUserLocation { return nil }

        // 클러스터 뷰: 수량 배지
        if let cluster = annotation as? MKClusterAnnotation {
            let id = MKMapViewDefaultClusterAnnotationViewReuseIdentifier
            let v = mapView.dequeueReusableAnnotationView(withIdentifier: id, for: cluster) as! MKMarkerAnnotationView
            v.markerTintColor = .systemBlue
            v.glyphText = "\(cluster.memberAnnotations.count)"
            v.titleVisibility = .hidden
            v.subtitleVisibility = .hidden
            return v
        }

        // 일반 사진 핀
        let id = MKMapViewDefaultAnnotationViewReuseIdentifier
        let view = mapView.dequeueReusableAnnotationView(withIdentifier: id, for: annotation) as! PhotoAnnotationView
        if let ann = annotation as? PhotoAnnotation {
            view.configure(with: ann)
        }
        return view
    }

    // 콜아웃 액세서리 탭 (추후 상세 화면 연결)
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView,
                 calloutAccessoryControlTapped control: UIControl) {
        guard let ann = view.annotation as? PhotoAnnotation else { return }
        let alert = UIAlertController(title: ann.title ?? "사진",
                                      message: "여기서 상세 화면으로 이동하세요.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
}
