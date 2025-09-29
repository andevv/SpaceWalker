import Foundation
import RxSwift
import RxCocoa

final class CalendarViewModel: BaseViewModel {

    struct Input {
        let viewDidLoad: Observable<Void>
        let dateSelected: Observable<DateComponents?>
    }

    struct Output {
        let selectedDate: Signal<DateComponents?>
    }

    private let disposeBag = DisposeBag()

    func transform(input: Input) -> Output {
        let selectedRelay = PublishRelay<DateComponents?>()

        input.viewDidLoad
            .map { _ in nil as DateComponents? }
            .bind(to: selectedRelay)
            .disposed(by: disposeBag)

        input.dateSelected
            .bind(to: selectedRelay)
            .disposed(by: disposeBag)

        return Output(
            selectedDate: selectedRelay.asSignal()
        )
    }
}

