//
//  SpaceSelectViewModel.swift
//  SpaceWalker
//
//  Created by andev on 9/29/25.
//

import Foundation
import RxSwift
import RxCocoa
import UIKit

final class SpaceSelectViewModel: BaseViewModel {

    struct Input {
        let viewWillAppear: Observable<Void>
        let itemSelected: Observable<IndexPath>
    }

    struct Output {
        let items: Driver<[SpaceUIModel]>
        let selectedSpaces: Driver<[Space]>
    }

    private let repository = SpaceRepository()
    private let spacesRelay = BehaviorRelay<[Space]>(value: [])
    private let selectedSpacesRelay = BehaviorRelay<[Space]>(value: [])
    private let disposeBag = DisposeBag()

    func transform(input: Input) -> Output {
        input.viewWillAppear
            .flatMapLatest { [repository] _ in
                //repository.fetchSpaces()
                repository.fetchDummySpaces() //TODO: - 서버 API로 변경 필요
                    .asObservable()
                    .catchAndReturn([]) // 실패 시 빈 배열
            }
            .bind(to: spacesRelay)
            .disposed(by: disposeBag)

        // 선택/해제 로직
        input.itemSelected
            .withLatestFrom(spacesRelay) { indexPath, spaces in
                spaces[indexPath.row]
            }
            .withLatestFrom(selectedSpacesRelay) { tapped, current -> [Space] in
                var new = current
                if let idx = new.firstIndex(of: tapped) {
                    new.remove(at: idx)
                } else if new.count < 3 {
                    new.append(tapped)
                }
                return new
            }
            .bind(to: selectedSpacesRelay)
            .disposed(by: disposeBag)

        // UI 표시용 SpaceUIModel 변환
        let items = spacesRelay
            .observe(on: MainScheduler.instance)
            .map { $0.map(SpaceUIModel.init) }
            .asDriver(onErrorJustReturn: [])

        return Output(
            items: items,
            selectedSpaces: selectedSpacesRelay.asDriver()
        )
    }
}
