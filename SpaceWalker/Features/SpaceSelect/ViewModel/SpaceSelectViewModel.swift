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

    private let spacesRelay = BehaviorRelay<[Space]>(value: [])
    private let selectedSpacesRelay = BehaviorRelay<[Space]>(value: [])
    private let disposeBag = DisposeBag()

    private let dummySpaces: [Space] = [
        Space(id: .init(), name: "🌌 Deep Space"),
        Space(id: .init(), name: "🚀 Launch Day"),
        Space(id: .init(), name: "🛰️ Satellite Hunt"),
        Space(id: .init(), name: "🌙 Moonlight Shot"),
        Space(id: .init(), name: "✨ Star Trails")
    ]

    func transform(input: Input) -> Output {
        // 초기 더미 로드
        input.viewWillAppear
            .take(1)
            .map { [dummySpaces] in dummySpaces }
            .bind(to: spacesRelay)
            .disposed(by: disposeBag)

        // 선택/해제 처리
        input.itemSelected
            .withLatestFrom(spacesRelay) { indexPath, spaces in
                spaces[indexPath.row]
            }
            .withLatestFrom(selectedSpacesRelay) { tapped, current -> [Space] in
                var new = current
                if let idx = new.firstIndex(of: tapped) {
                    // 이미 선택됨 → 해제
                    new.remove(at: idx)
                } else if new.count < 3 {
                    // 아직 3개 미만일 때만 추가
                    new.append(tapped)
                }
                return new
            }
            .bind(to: selectedSpacesRelay)
            .disposed(by: disposeBag)

        let items = spacesRelay
            .map { $0.map(SpaceUIModel.init) }
            .asDriver(onErrorJustReturn: [])

        return Output(
            items: items,
            selectedSpaces: selectedSpacesRelay.asDriver()
        )
    }
}
