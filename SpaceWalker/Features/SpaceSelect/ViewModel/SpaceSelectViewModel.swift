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
        let proceedTap: Observable<Void>
    }

    struct Output {
        let items: Driver<[SpaceUIModel]>
        let selectedSpaces: Driver<[Space]>
        let joinSuccess: Signal<[JoinedSpace]>
        let joinFailure: Signal<(message: String, invalidIds: [Int])>
    }

    private let repository = SpaceRepository()
    private let spacesRelay = BehaviorRelay<[Space]>(value: [])
    private let selectedSpacesRelay = BehaviorRelay<[Space]>(value: [])
    private let disposeBag = DisposeBag()

    func transform(input: Input) -> Output {
        input.viewWillAppear
            .flatMapLatest { [repository] _ in
                repository.fetchSpaces()
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
        
        // 조인
        let joinResult = input.proceedTap
            .withLatestFrom(selectedSpacesRelay)
            .flatMapLatest { [repository] spaces -> Observable<Event<[JoinedSpace]>> in
                let ids = spaces.map(\.id)
                return repository.joinSpaces(spaceIds: ids)
                    .asObservable()
                    .materialize()
            }
            .share()

        let joinSuccess = joinResult
            .compactMap { $0.element }
            .asSignal(onErrorRecover: { _ in .empty() })

        let joinFailure = joinResult
            .compactMap { $0.error }
            .map { error -> (message: String, invalidIds: [Int]) in
                if case let JoinSpacesDomainError.invalidSpaceIds(invalidIds, message) = error {
                    return (message: message, invalidIds: invalidIds)
                } else if case let JoinSpacesDomainError.unknown(message) = error {
                    return (message: message, invalidIds: [])
                }
                return (message: "일시적인 오류가 발생했습니다. 잠시 후 다시 시도해주세요.", invalidIds: [])
            }
            .asSignal(onErrorRecover: { _ in .empty() })

        // UI용 아이템 변환
        let items = spacesRelay
            .map { $0.map(SpaceUIModel.init) }
            .asDriver(onErrorJustReturn: [])

        return Output(
            items: items,
            selectedSpaces: selectedSpacesRelay.asDriver(),
            joinSuccess: joinSuccess,
            joinFailure: joinFailure
        )
    }
}
