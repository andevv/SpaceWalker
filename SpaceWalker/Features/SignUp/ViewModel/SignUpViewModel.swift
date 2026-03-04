//
//  SignUpViewModel.swift
//  SpaceWalker
//
//  Created by andev on 3/4/26.
//

import Foundation
import RxSwift
import RxCocoa

final class SignUpViewModel: BaseViewModel {

    struct Input {
        let appleLoginSuccess: Observable<SignUpAppleLoginPayload>
        let appleLoginFailure: Observable<String>
    }

    struct Output {
        let route: Signal<SignUpRoute>
        let alertMessage: Signal<String>
        let isLoading: Driver<Bool>
    }

    private let loginRepo = AppleLoginRepository()
    private let spaceRepo = SpaceRepository()
    private let disposeBag = DisposeBag()

    private let routeRelay = PublishRelay<SignUpRoute>()
    private let alertRelay = PublishRelay<String>()
    private let isLoadingRelay = BehaviorRelay<Bool>(value: false)

    func transform(input: Input) -> Output {
        input.appleLoginFailure
            .bind(to: alertRelay)
            .disposed(by: disposeBag)

        input.appleLoginSuccess
            .flatMapLatest { [weak self] payload -> Observable<Event<[JoinedSpace]>> in
                guard let self else { return .empty() }
                self.isLoadingRelay.accept(true)

                return self.loginAndFetchMySpaces(payload: payload)
                    .asObservable()
                    .materialize()
            }
            .subscribe(onNext: { [weak self] event in
                guard let self else { return }
                self.isLoadingRelay.accept(false)

                switch event {
                case .next(let joinedSpaces):
                    if joinedSpaces.isEmpty {
                        LogAuth("사용자가 속한 Space 없음 → SpaceSelectViewController로 이동")
                        self.routeRelay.accept(.spaceSelect)
                    } else {
                        LogAuth("사용자가 속한 Space 있음 → CalendarViewController로 이동")
                        self.routeRelay.accept(.mainTab)
                    }
                case .error(let error):
                    LogNetwork("로그인 or 스페이스 조회 실패: \(error.localizedDescription)")
                    self.alertRelay.accept(error.localizedDescription)
                case .completed:
                    break
                }
            })
            .disposed(by: disposeBag)

        return Output(
            route: routeRelay.asSignal(),
            alertMessage: alertRelay.asSignal(),
            isLoading: isLoadingRelay.asDriver()
        )
    }

    private func loginAndFetchMySpaces(payload: SignUpAppleLoginPayload) -> Single<[JoinedSpace]> {
        loginRepo.loginWithApple(idToken: payload.idToken, authCode: payload.authCode)
            .do(onSuccess: { response in
                UserSessionStore.shared.accessToken = response.accessToken
                UserSessionStore.shared.refreshToken = response.refreshToken
                LogAuth("서버 로그인 성공 — AccessToken 저장 완료")
            })
            .flatMap { [weak self] _ -> Single<[JoinedSpace]> in
                guard let self else { return .just([]) }
                LogNetwork("[API] 내 스페이스 목록 요청 시작")
                return self.spaceRepo.fetchMySpaces()
            }
            .do(onSuccess: { joinedSpaces in
                LogNetwork("[API] 내 스페이스 목록 응답 수신 — count: \(joinedSpaces.count)")
            })
    }
}
