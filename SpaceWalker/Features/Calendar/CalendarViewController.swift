//
//  CalendarViewController.swift
//  SpaceWalker
//
//  Created by andev on 9/29/25.
//

import UIKit
import SnapKit
import FSCalendar

final class CalendarViewController: UIViewController {

    // MARK: - UI
    private let titleLabel: UILabel = {
        let lb = UILabel()
        lb.text = "오늘의 미션"
        lb.font = .systemFont(ofSize: 28, weight: .bold)
        lb.textColor = .label
        return lb
    }()

    private let missionLabel: UILabel = {
        let lb = UILabel()
        lb.text = "미션 텍스트"
        lb.font = .systemFont(ofSize: 15, weight: .regular)
        lb.textColor = .secondaryLabel
        return lb
    }()

    // 필터 칩 (최대 3개)
    private let chipContainer = UIView()
    private let chipStack = UIStackView()
    
    private var calendarHeightConstraint: Constraint?   // ← 높이 제약 핸들 저장

    private let calendar: FSCalendar = {
        let cal = FSCalendar()
        cal.locale = Locale(identifier: "ko_KR")
        cal.scrollEnabled = false
        cal.scope = .month
        cal.appearance.weekdayTextColor = .secondaryLabel
        cal.appearance.headerMinimumDissolvedAlpha = 0 // 좌우 흐림 제거
        cal.headerHeight = 0                           // 자체 헤더 숨김(커스텀 사용)
        cal.weekdayHeight = 22
        return cal
    }()

    // 커스텀 월 헤더
    private let monthBar = UIView()
    private let monthTitleLabel: UILabel = {
        let lb = UILabel()
        lb.font = .systemFont(ofSize: 18, weight: .semibold)
        lb.textAlignment = .center
        return lb
    }()
    private let prevButton = UIButton(type: .system)
    private let nextButton = UIButton(type: .system)

    // 하단 버튼
    private let bottomBar = UIView()
    private let missionButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "미션하러 가기"
        config.baseBackgroundColor = .systemBlue
        config.baseForegroundColor = .white
        config.cornerStyle = .large
        let b = UIButton(configuration: config)
        return b
    }()

    // MARK: - State
    private var spaces: [String] = ["개인", "업무", "공부"]
    private var selectedChipIndex: Int = 0
    private var selectedDate: Date?

    /// 현재 페이지(월)의 날짜별 썸네일
    private var photos: [Date: UIImage] = [:]
    private let cal = Calendar.current

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        setupLayout()
        setupCalendar()
        setupChips()
        refreshHeaderTitle()
        makeDummyPhotos(for: calendar.currentPage)
    }

    // MARK: - Layout
    private func setupLayout() {
        // 상단
        view.addSubview(titleLabel)
        view.addSubview(missionLabel)
        view.addSubview(chipContainer)
        chipContainer.addSubview(chipStack)

        // 월 헤더 + 캘린더
        view.addSubview(monthBar)
        monthBar.addSubview(prevButton)
        monthBar.addSubview(monthTitleLabel)
        monthBar.addSubview(nextButton)
        view.addSubview(calendar)

        // 하단
        view.addSubview(bottomBar)
        bottomBar.addSubview(missionButton)

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).inset(20)
            make.leading.trailing.equalToSuperview().inset(20)
        }
        missionLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
            make.leading.trailing.equalTo(titleLabel)
        }

        // 칩 스택 레이아웃
        chipStack.axis = .horizontal
        chipStack.spacing = 8
        chipStack.alignment = .fill
        chipStack.distribution = .fillProportionally

        chipContainer.snp.makeConstraints { make in
            make.top.equalTo(missionLabel.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(40)
        }
        chipStack.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(20)
            make.centerY.equalToSuperview()
            make.height.equalTo(40)
        }


        monthBar.snp.remakeConstraints { make in
            make.top.equalTo(chipContainer.snp.bottom).offset(32)
            make.leading.trailing.equalToSuperview().inset(20)
            make.height.equalTo(24)
        }

        prevButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        nextButton.setImage(UIImage(systemName: "chevron.right"), for: .normal)
        prevButton.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
            make.width.height.equalTo(24)
        }
        nextButton.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
            make.width.height.equalTo(24)
        }
        monthTitleLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        calendar.snp.makeConstraints { make in
            make.top.equalTo(monthBar.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(10)
            // 초기 높이는 임의값으로 잡고, 이후 delegate에서 실제 높이로 업데이트
            self.calendarHeightConstraint = make.height.equalTo(320).constraint
            make.bottom.lessThanOrEqualTo(bottomBar.snp.top).offset(-20)
        }

        bottomBar.backgroundColor = .systemBackground
        bottomBar.layer.shadowColor = UIColor.black.withAlphaComponent(0.08).cgColor
        bottomBar.layer.shadowOpacity = 1
        bottomBar.layer.shadowRadius = 8
        bottomBar.layer.shadowOffset = CGSize(width: 0, height: -2)
        bottomBar.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide)
        }
        missionButton.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(12)
            make.leading.trailing.equalToSuperview().inset(20)
            make.bottom.equalToSuperview().inset(12)
            make.height.equalTo(52)
        }

        prevButton.addTarget(self, action: #selector(prevMonth), for: .touchUpInside)
        nextButton.addTarget(self, action: #selector(nextMonth), for: .touchUpInside)
        missionButton.addTarget(self, action: #selector(didTapMission), for: .touchUpInside)
    }

    private func setupCalendar() {
        calendar.dataSource = self
        calendar.delegate = self
        calendar.scope = .month
        calendar.placeholderType = .none
        calendar.register(ThumbnailCalendarCell.self, forCellReuseIdentifier: ThumbnailCalendarCell.reuseID)

        // 선택/오늘 기본 원을 전부 투명 처리해서 내부 동그라미가 안 보이게
        calendar.appearance.selectionColor = .clear
        calendar.appearance.todaySelectionColor = .clear
        calendar.appearance.borderSelectionColor = .clear
        calendar.appearance.borderDefaultColor = .clear
        calendar.appearance.titleSelectionColor = .clear
        calendar.appearance.titleDefaultColor = .clear

        calendar.weekdayHeight = 22
        for (i, label) in calendar.calendarWeekdayView.weekdayLabels.enumerated() {
            if i == 0 { label.textColor = .systemRed }
            else if i == 6 { label.textColor = .systemBlue }
            else { label.textColor = .secondaryLabel }
            label.font = .systemFont(ofSize: 13, weight: .semibold)
        }
    }

    private func setupChips() {
        chipStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        // 최대 3개만
        for (idx, title) in spaces.prefix(3).enumerated() {
            let b = makeChipButton(title: title, selected: idx == selectedChipIndex)
            b.tag = idx
            b.addTarget(self, action: #selector(chipTapped(_:)), for: .touchUpInside)
            chipStack.addArrangedSubview(b)
        }
    }

    // MARK: - Actions
    @objc private func chipTapped(_ sender: UIButton) {
        selectedChipIndex = sender.tag
        for case let btn as UIButton in chipStack.arrangedSubviews {
            styleChip(btn, selected: btn.tag == selectedChipIndex)
        }
        // 실제 필터링: 선택된 칩에 맞게 photos 재구성 후 reload
        makeDummyPhotos(for: calendar.currentPage) // 데모는 색만 바꿈
        calendar.reloadData()
    }

    @objc private func prevMonth() {
        guard let newDate = cal.date(byAdding: .month, value: -1, to: calendar.currentPage) else { return }
        calendar.setCurrentPage(newDate, animated: true)
        refreshHeaderTitle()
        makeDummyPhotos(for: newDate)
        calendar.reloadData()
    }

    @objc private func nextMonth() {
        guard let newDate = cal.date(byAdding: .month, value: 1, to: calendar.currentPage) else { return }
        calendar.setCurrentPage(newDate, animated: true)
        refreshHeaderTitle()
        makeDummyPhotos(for: newDate)
        calendar.reloadData()
    }

    @objc private func didTapMission() {
        // TODO: 미션 화면 전환 연결
        let alert = UIAlertController(title: "미션", message: "미션 시작 로직을 연결하세요.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }

    private func refreshHeaderTitle() {
        let y = cal.component(.year, from: calendar.currentPage)
        let m = cal.component(.month, from: calendar.currentPage)
        monthTitleLabel.text = String(format: "%d년 %d월", y, m)
    }

    // MARK: - Chip helpers
    private func makeChipButton(title: String, selected: Bool) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        b.contentEdgeInsets = UIEdgeInsets(top: 8, left: 14, bottom: 8, right: 14)
        b.layer.cornerRadius = 16
        b.layer.borderWidth = 1
        b.layer.borderColor = UIColor.systemGray4.cgColor
        styleChip(b, selected: selected)
        return b
    }
    private func styleChip(_ b: UIButton, selected: Bool) {
        if selected {
            b.backgroundColor = .systemBlue
            b.setTitleColor(.white, for: .normal)
            b.layer.borderColor = UIColor.systemBlue.cgColor
        } else {
            b.backgroundColor = UIColor.systemGray6
            b.setTitleColor(.label, for: .normal)
            b.layer.borderColor = UIColor.systemGray4.cgColor
        }
    }

    // MARK: - Dummy Photos (데모용)
    private func makeDummyPhotos(for page: Date) {
        // 칩에 따라 다른 컬러로 더미 생성
        let color: UIColor = [UIColor.systemBlue, .systemOrange, .systemGreen][selectedChipIndex % 3]
        func colorImage(_ color: UIColor) -> UIImage {
            let r = CGRect(x: 0, y: 0, width: 100, height: 100)
            UIGraphicsBeginImageContextWithOptions(r.size, true, 0)
            color.setFill(); UIRectFill(r)
            let img = UIGraphicsGetImageFromCurrentImageContext()!
            UIGraphicsEndImageContext()
            return img
        }
        photos.removeAll()
        // 예시: 임의 날짜에 썸네일 배치
        for d in [1,3,5,8,12,15,18,20,22,25,27,30] {
            if let date = dateFor(day: d, in: page) {
                photos[date] = colorImage(color)
            }
        }
    }

    // day → 해당 month의 Date
    private func dateFor(day: Int, in page: Date) -> Date? {
        let y = cal.component(.year, from: page)
        let m = cal.component(.month, from: page)
        var comps = DateComponents(year: y, month: m, day: day)
        return cal.date(from: comps)
    }
}

// MARK: - FSCalendar DataSource / Delegate
extension CalendarViewController: FSCalendarDataSource, FSCalendarDelegate, FSCalendarDelegateAppearance {

    func calendar(_ calendar: FSCalendar, cellFor date: Date, at position: FSCalendarMonthPosition) -> FSCalendarCell {
        let cell = calendar.dequeueReusableCell(withIdentifier: ThumbnailCalendarCell.reuseID, for: date, at: position) as! ThumbnailCalendarCell
        let day = cal.component(.day, from: date)

        // 현재 달 여부 / 선택 여부
        let dimmed = (position != .current)
        let selected = (selectedDate != nil) && cal.isDate(selectedDate!, inSameDayAs: date)

        // 썸네일
        let image = photos.first { cal.isDate($0.key, inSameDayAs: date) }?.value
        cell.configure(day: day, image: image, selected: selected, dimmed: dimmed)
        return cell
    }

    func calendar(_ calendar: FSCalendar, didSelect date: Date, at monthPosition: FSCalendarMonthPosition) {
        selectedDate = date

        // 다른 달의 셀을 탭했을 때 페이지 이동
        if monthPosition != .current {
            calendar.setCurrentPage(date, animated: true)
            refreshHeaderTitle()
            makeDummyPhotos(for: date)
        }
        calendar.reloadData()
    }
    
    func calendar(_ calendar: FSCalendar, boundingRectWillChange bounds: CGRect, animated: Bool) {
        // 달마다 필요한 높이(4~6주)를 FSCalendar가 알려줌 → 제약 업데이트
        calendar.snp.updateConstraints { make in
            self.calendarHeightConstraint?.update(offset: bounds.height)
        }
        // 애니메이션 반영
        UIView.animate(withDuration: animated ? 0.25 : 0.0) {
            self.view.layoutIfNeeded()
        }
    }

    func calendarCurrentPageDidChange(_ calendar: FSCalendar) {
        refreshHeaderTitle()
        makeDummyPhotos(for: calendar.currentPage)
        calendar.reloadData()
    }

    // 날짜 타이틀을 숨기고(우린 뱃지를 쓰므로), 기본 폰트/색 영향 최소화
    func calendar(_ calendar: FSCalendar, appearance: FSCalendarAppearance, titleDefaultColorFor date: Date) -> UIColor? {
        .clear
    }
    func calendar(_ calendar: FSCalendar, appearance: FSCalendarAppearance, titleSelectionColorFor date: Date) -> UIColor? {
        .clear
    }
}
