//
//  CalendarViewController.swift
//  SpaceWalker
//
//  Created by andev on 9/29/25.
//

import UIKit
import SnapKit
import RxSwift
import RxCocoa

final class CalendarViewController: UIViewController {

    // MARK: - UI
    private let calendarView: UICalendarView = {
        let v = UICalendarView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.locale = .current
        v.calendar = Calendar.current
        v.timeZone = .current
        return v
    }()

    private lazy var selectionBehavior: UICalendarSelectionSingleDate = {
        let selection = UICalendarSelectionSingleDate(delegate: self)
        return selection
    }()

    // MARK: - MVVM
    private let viewModel = CalendarViewModel()
    private let disposeBag = DisposeBag()

    // Bridge delegate callbacks to Rx input
    private let selectedDateRelay = PublishRelay<DateComponents?>()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        setupViews()
        setupConstraints()
        bindViewModel()
    }

    // MARK: - Setup
    private func setupViews() {
        view.addSubview(calendarView)
        calendarView.selectionBehavior = selectionBehavior
    }

    private func setupConstraints() {
        calendarView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.greaterThanOrEqualTo(view.safeAreaLayoutGuide).offset(16)
            make.trailing.lessThanOrEqualTo(view.safeAreaLayoutGuide).inset(16)
            make.width.lessThanOrEqualTo(380)
        }
    }

    private func bindViewModel() {
        let input = CalendarViewModel.Input(
            viewDidLoad: Observable.just(()),
            dateSelected: selectedDateRelay.asObservable()
        )
        let output = viewModel.transform(input: input)

        output.selectedDate
            .emit(onNext: { [weak self] comps in
                guard let comps = comps, let date = comps.date else { return }
                print("선택된 날짜: \(date)")
                // TODO: 필요 시 다른 화면으로 전달하거나 상태 업데이트
            })
            .disposed(by: disposeBag)
    }
}

extension CalendarViewController: UICalendarSelectionSingleDateDelegate {
    func dateSelection(_ selection: UICalendarSelectionSingleDate, didSelectDate dateComponents: DateComponents?) {
        selectedDateRelay.accept(dateComponents)
    }

    func dateSelection(_ selection: UICalendarSelectionSingleDate, canSelectDate dateComponents: DateComponents?) -> Bool {
        return true
    }
}
