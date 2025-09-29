import Foundation
import RxSwift
import RxCocoa

final class SignUpViewModel: BaseViewModel {

    struct Input {
        let googleTap: Observable<Void>
        let appleTap: Observable<Void>
        let signupTap: Observable<Void>
    }

    struct Output {
        let showGoogleLogin: Signal<Void>
        let showAppleLogin: Signal<Void>
        let showSignUp: Signal<Void>
    }

    private let disposeBag = DisposeBag()

    func transform(input: Input) -> Output {
        let googleRelay = PublishRelay<Void>()
        let appleRelay = PublishRelay<Void>()
        let signupRelay = PublishRelay<Void>()

        input.googleTap
            .bind(to: googleRelay)
            .disposed(by: disposeBag)

        input.appleTap
            .bind(to: appleRelay)
            .disposed(by: disposeBag)

        input.signupTap
            .bind(to: signupRelay)
            .disposed(by: disposeBag)

        return Output(
            showGoogleLogin: googleRelay.asSignal(),
            showAppleLogin: appleRelay.asSignal(),
            showSignUp: signupRelay.asSignal()
        )
    }
}
