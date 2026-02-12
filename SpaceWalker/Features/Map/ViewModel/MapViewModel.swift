//
//  MapViewModel.swift
//  SpaceWalker
//
//  Created by andev on 2/11/26.
//

import Foundation
import RealmSwift
import RxCocoa
import RxSwift

final class MapViewModel: BaseViewModel {

    struct Input {
        let viewDidLoad: Observable<Void>
        let spaceSelection: Observable<Int?>
    }

    struct Output {
        let chips: Driver<[MapSpaceChipModel]>
        let pins: Signal<[MapPinModel]>
        let errors: Signal<String>
    }

    private let repository = SpaceRepository()
    private let disposeBag = DisposeBag()

    private let joinedSpacesRelay = BehaviorRelay<[JoinedSpace]>(value: [])
    private let selectedSpaceIdRelay = BehaviorRelay<Int?>(value: nil)
    private let pinsRelay = BehaviorRelay<[MapPinModel]>(value: [])
    private let errorsRelay = PublishRelay<String>()

    private var realmToken: NotificationToken?

    #if DEBUG
    private let enableMapDummyData: Bool = true
    #endif

    func transform(input: Input) -> Output {
        input.viewDidLoad
            .subscribe(onNext: { [weak self] in
                self?.startObservingRealm()
                self?.reloadPinsFromRealm()
                self?.fetchMySpacesForMap()
            })
            .disposed(by: disposeBag)

        input.spaceSelection
            .distinctUntilChanged { $0 == $1 }
            .subscribe(onNext: { [weak self] selectedId in
                self?.selectedSpaceIdRelay.accept(selectedId)
                self?.reloadPinsFromRealm()
            })
            .disposed(by: disposeBag)

        let chips = Observable
            .combineLatest(joinedSpacesRelay.asObservable(), selectedSpaceIdRelay.asObservable())
            .map { joinedSpaces, selectedId in
                var models: [MapSpaceChipModel] = [
                    MapSpaceChipModel(id: nil, title: "전체", isSelected: selectedId == nil)
                ]
                models.append(contentsOf: joinedSpaces.map {
                    MapSpaceChipModel(id: $0.id, title: $0.name, isSelected: selectedId == $0.id)
                })
                return models
            }
            .asDriver(onErrorJustReturn: [MapSpaceChipModel(id: nil, title: "전체", isSelected: true)])

        return Output(
            chips: chips,
            pins: pinsRelay.asSignal(onErrorJustReturn: []),
            errors: errorsRelay.asSignal()
        )
    }

    private func fetchMySpacesForMap() {
        repository.fetchMySpaces()
            .subscribe(onSuccess: { [weak self] joined in
                self?.joinedSpacesRelay.accept(joined)
            }, onFailure: { [weak self] error in
                self?.errorsRelay.accept("fetchMySpacesForMap failed: \(error.localizedDescription)")
            })
            .disposed(by: disposeBag)
    }

    private func reloadPinsFromRealm() {
        do {
            let realm = try Realm()
            var results = realm.objects(PhotoMetadata.self).filter("latitude != 0 AND longitude != 0")
            if let sid = selectedSpaceIdRelay.value {
                results = results.filter("spaceId == %@", sid)
            }

            let df = DateFormatter()
            df.locale = Locale(identifier: "ko_KR")
            df.dateFormat = "yyyy-MM-dd"

            var pins: [MapPinModel] = results.map { meta in
                let title = (meta.missionTitle?.isEmpty == false)
                    ? meta.missionTitle!
                    : df.string(from: meta.capturedAt)
                return MapPinModel(
                    latitude: meta.latitude,
                    longitude: meta.longitude,
                    title: title,
                    subtitle: String(format: "%.5f, %.5f", meta.latitude, meta.longitude)
                )
            }

            #if DEBUG
            if enableMapDummyData, selectedSpaceIdRelay.value == nil {
                pins.append(contentsOf: makeDummyPins())
            }
            #endif

            pinsRelay.accept(pins)
        } catch {
            errorsRelay.accept("Realm open failed: \(error)")
        }
    }

    private func startObservingRealm() {
        do {
            let realm = try Realm()
            let results = realm.objects(PhotoMetadata.self).filter("latitude != 0 AND longitude != 0")
            realmToken = results.observe { [weak self] changes in
                guard let self = self else { return }
                switch changes {
                case .initial, .update:
                    DispatchQueue.main.async { self.reloadPinsFromRealm() }
                case .error(let error):
                    self.errorsRelay.accept("Realm observe error: \(error)")
                }
            }
        } catch {
            errorsRelay.accept("Realm open failed: \(error)")
        }
    }

    #if DEBUG
    private func makeDummyPins() -> [MapPinModel] {
        let base: [(Double, Double, String)] = [
            (37.5665, 126.9780, "서울 시청"),
            (37.5651, 126.9896, "서울 종로(클러스터 테스트)"),
            (37.5700, 126.9769, "경복궁(클러스터 테스트)"),
            (35.1796, 129.0756, "부산"),
            (35.1667, 129.0720, "부산 서면(클러스터 테스트)"),
            (35.8714, 128.6014, "대구"),
            (36.3504, 127.3845, "대전"),
            (35.1595, 126.8526, "광주"),
            (37.4563, 126.7052, "인천"),
            (33.4996, 126.5312, "제주")
        ]

        let nearSeoul: [(Double, Double, String)] = [
            (37.5670, 126.9785, "광화문 근처 1"),
            (37.5675, 126.9790, "광화문 근처 2"),
            (37.5680, 126.9795, "광화문 근처 3")
        ]

        return (base + nearSeoul).map { lat, lon, title in
            MapPinModel(
                latitude: lat,
                longitude: lon,
                title: title,
                subtitle: String(format: "%.5f, %.5f", lat, lon)
            )
        }
    }
    #endif

    deinit {
        realmToken = nil
    }
}
