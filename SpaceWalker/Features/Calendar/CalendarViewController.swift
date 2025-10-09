//
//  CalendarViewController.swift
//  SpaceWalker
//
//  Created by andev on 9/29/25.
//

import UIKit
import AVFoundation
import Photos
import CoreLocation
import SnapKit
import FSCalendar
import RxSwift
import ImageIO
import UniformTypeIdentifiers
import RealmSwift
import os
import Alamofire

final class CalendarViewController: UIViewController {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "SpaceWalker", category: "CalendarViewController")

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

    private var calendarHeightConstraint: Constraint?

    private let calendar: FSCalendar = {
        let cal = FSCalendar()
        cal.locale = Locale(identifier: "ko_KR")
        cal.scrollEnabled = false
        cal.scope = .month
        cal.appearance.weekdayTextColor = .secondaryLabel
        cal.appearance.headerMinimumDissolvedAlpha = 0
        cal.headerHeight = 0
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
    private var joinedSpaces: [JoinedSpace] = []
    private var spaces: [String] = []
    private var selectedChipIndex: Int = 0
    private var selectedDate: Date?
    private var currentFetchKey: String?

    // Decoded image cache for the current app session (lightweight)
    private let imageCache = NSCache<NSString, UIImage>()

    /// 현재 페이지(월)의 날짜별 썸네일
    private var photos: [Date: UIImage] = [:]
    private let cal = Calendar.current

    // [Location+Save] 위치 권한/값
    private let locationManager = CLLocationManager()
    private var currentLocation: CLLocation?
    private var pendingOneShotLocation: Bool = false
    private var pendingCameraPresentation: Bool = false

    // MARK: - Networking
    private let repository = SpaceRepository()
    private let disposeBag = DisposeBag()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        setupLayout()
        setupCalendar()
        refreshHeaderTitle()
        imageCache.countLimit = 150 // up to 150 thumbnails in memory

        // 칩을 서버(더미)에서 받아와 구성
        fetchMySpaces()
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
            self.calendarHeightConstraint = make.height.equalTo(320).constraint
            make.bottom.lessThanOrEqualTo(bottomBar.snp.top).offset(-20)
        }

        bottomBar.backgroundColor = .systemBackground
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

        // 기본 선택/오늘 원 숨김
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
    
    // 사용자의 특정 space 상태 상세 조회
    private func fetchSpaceActivities(spaceId: Int) {
        let requestStart = Date()
        logger.info("[Network] fetchSpaceActivities start — spaceId=\(spaceId, privacy: .public)")

        let visiblePage = calendar.currentPage
        let year = cal.component(.year, from: visiblePage)
        let month = cal.component(.month, from: visiblePage)
        let timezone = TimeZone.current.identifier
        // 새 요청 키 설정 및 기존 썸네일 초기화
        let fetchKey = "\(spaceId)-\(year)-\(month)"
        currentFetchKey = fetchKey
        photos.removeAll()
        calendar.reloadData()

        repository.fetchSpaceActivities(spaceId: spaceId, year: year, month: month, timezone: timezone)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] response in
                guard let self else { return }

                let elapsed = Date().timeIntervalSince(requestStart)
                self.logger.info("[Network] fetchSpaceActivities success — elapsed=\(elapsed, format: .fixed(precision: 2))s, dailyMission=\(response.dailyMission.title, privacy: .public), activitiesCount=\(response.activities.count, privacy: .public)")

                // 오늘의 미션
                self.missionLabel.text = response.dailyMission.title

                // 활동 날짜별 썸네일 맵핑 (병렬 다운로드 + 일괄 갱신)
                let expectedKey = self.currentFetchKey // 캡처
                let group = DispatchGroup()
                var resultMap: [Date: UIImage] = [:]
                let resultQueue = DispatchQueue(label: "calendar.photos.result", attributes: .concurrent)

                for activity in response.activities {
                    guard let utcDate = self.parseActivityUTCDate(activity.date) else { continue }
                    let localDate = utcDate.convertToLocal()
                    guard let url = URL(string: activity.photo) else { continue }

                    // Lightweight in-memory cache lookup (per local day)
                    let dayKeyString = "space:\(spaceId)|day:\(self.dayString(for: self.cal.startOfDay(for: localDate)))"
                    if let cached = self.imageCache.object(forKey: dayKeyString as NSString) {
                        // 캐시 적중: 결과에 즉시 반영하고 다운로드 생략
                        resultQueue.async(flags: .barrier) { resultMap[self.cal.startOfDay(for: localDate)] = cached }
                        self.logger.debug("[Cache] hit — key=\(dayKeyString, privacy: .public)")
                        continue
                    }

                    group.enter()
                    self.logger.debug("[Image] start download — date=\(activity.date, privacy: .public), url=\(activity.photo, privacy: .public)")
                    self.loadImage(from: url) { [weak self] image in
                        defer { group.leave() }
                        guard let self = self else { return }
                        // 요청 키가 바뀌었으면(월/칩 변경) 무시
                        guard expectedKey == self.currentFetchKey else { return }
                        if let image {
                            let localDay = self.cal.startOfDay(for: localDate)
                            // 캐시에 저장 후 결과 반영 (동시 접근 보호)
                            let key = "space:\(spaceId)|day:\(self.dayString(for: localDay))"
                            self.imageCache.setObject(image, forKey: key as NSString)
                            resultQueue.async(flags: .barrier) {
                                resultMap[localDay] = image
                            }
                            self.logger.debug("[Image] download success — mappedLocalDay=\(localDay as NSDate, privacy: .public), cacheKey=\(key, privacy: .public)")
                        } else {
                            self.logger.error("[Image] download failed — url=\(activity.photo, privacy: .public)")
                        }
                    }
                }

                group.notify(queue: .main) {
                    // 요청 키가 바뀌었으면(월/칩 변경) 무시
                    guard expectedKey == self.currentFetchKey else { return }
                    // 결과를 한 번에 반영하고 캘린더 갱신
                    self.photos = resultMap
                    self.calendar.reloadData()
                    self.logger.info("[Image] all downloads completed — count=\(resultMap.count, privacy: .public)")
                }

            }, onFailure: { error in
                let elapsed = Date().timeIntervalSince(requestStart)
                self.logger.error("[Network] fetchSpaceActivities failure — elapsed=\(elapsed, format: .fixed(precision: 2))s, error=\(error.localizedDescription, privacy: .public)")

                print("Space activities fetch failed:", error.localizedDescription)
            })
            .disposed(by: disposeBag)
    }

    // 서버에서 사용자가 속한 Space 목록을 불러와 칩 구성
    private func fetchMySpaces() {
        let requestStart = Date()
        logger.info("[Network] fetchMySpaces start")

        repository.fetchMySpaces() // 실제 API 호출
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] joinedSpaces in
                guard let self else { return }
                
                self.joinedSpaces = joinedSpaces

                let elapsed = Date().timeIntervalSince(requestStart)
                self.logger.info("[Network] fetchMySpaces success — elapsed=\(elapsed, format: .fixed(precision: 2))s, count=\(joinedSpaces.count, privacy: .public)")

                // 서버 응답 → 칩에 표시할 Space 이름만 추출
                self.spaces = joinedSpaces.map { $0.name }
                self.selectedChipIndex = 0
                self.setupChips()

                // 칩 반영 후 달력 갱신
//                self.makeDummyPhotos(for: self.calendar.currentPage)
//                self.calendar.reloadData()
                
                // 첫 번째 Space의 활동 조회
                if let firstSpace = joinedSpaces.first {
                    self.fetchSpaceActivities(spaceId: firstSpace.id)
                }

            }, onFailure: { error in
                let elapsed = Date().timeIntervalSince(requestStart)
                self.logger.error("[Network] fetchMySpaces failure — elapsed=\(elapsed, format: .fixed(precision: 2))s, error=\(error.localizedDescription, privacy: .public)")

                print("MySpaces fetch failed:", error.localizedDescription)
            })
            .disposed(by: disposeBag)
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
        if joinedSpaces.indices.contains(selectedChipIndex) {
            let selected = joinedSpaces[selectedChipIndex]
            logger.info("[UI] chipTapped — index=\(self.selectedChipIndex, privacy: .public), spaceId=\(selected.id, privacy: .public), name=\(selected.name, privacy: .public)")
            fetchSpaceActivities(spaceId: selected.id)
        }
    }

    @objc private func prevMonth() {
        guard let newDate = cal.date(byAdding: .month, value: -1, to: calendar.currentPage) else { return }
        calendar.setCurrentPage(newDate, animated: true)
        refreshHeaderTitle()
        if joinedSpaces.indices.contains(selectedChipIndex) {
            let selected = joinedSpaces[selectedChipIndex]
            fetchSpaceActivities(spaceId: selected.id)
        }
    }

    @objc private func nextMonth() {
        guard let newDate = cal.date(byAdding: .month, value: 1, to: calendar.currentPage) else { return }
        calendar.setCurrentPage(newDate, animated: true)
        refreshHeaderTitle()
        if joinedSpaces.indices.contains(selectedChipIndex) {
            let selected = joinedSpaces[selectedChipIndex]
            fetchSpaceActivities(spaceId: selected.id)
        }
    }

    @objc private func didTapMission() {
        presentCamera()
    }

    // MARK: - Camera & Photo Library

    private func presentCamera() {
        // 카메라 사용 가능 여부 확인
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            let ac = UIAlertController(title: "카메라를 사용할 수 없습니다.",
                                       message: "이 기기에서는 카메라를 사용할 수 없어요. 대신 사진 보관함에서 선택할까요?",
                                       preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "사진 선택", style: .default, handler: { [weak self] _ in
                self?.presentPhotoLibrary()
            }))
            ac.addAction(UIAlertAction(title: "취소", style: .cancel))
            present(ac, animated: true)
            return
        }

        // 카메라 권한 확인 및 요청
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            self.showCameraPicker()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if granted {
                        self.showCameraPicker()
                    } else {
                        self.showCameraDeniedAlert()
                    }
                }
            }
        default:
            self.showCameraDeniedAlert()
        }
    }

    // MARK: - Camera & Photo Library

    /// 카메라 사용 시에만 1회 위치 요청
    private func prepareLocationForCapture() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            pendingOneShotLocation = false
            locationManager.requestLocation()
        case .notDetermined:
            pendingOneShotLocation = true
            locationManager.requestWhenInUseAuthorization()
        default:
            // 거부/제한 상태에서는 위치 없이 저장 진행
            break
        }
    }

    // 위치 권한 거부/제한 안내 알림 (카메라는 계속 진행 가능)
    private func showLocationDeniedAlert(continueHandler: @escaping () -> Void) {
        let ac = UIAlertController(title: "위치 접근 권한 안내",
                                   message: "촬영한 사진에 위치 정보를 포함하려면 설정에서 위치 접근을 허용해 주세요. 지금은 위치 없이 계속할 수 있어요.",
                                   preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "위치 없이 계속", style: .default, handler: { _ in
            continueHandler()
        }))
        ac.addAction(UIAlertAction(title: "설정 열기", style: .default, handler: { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }))
        ac.addAction(UIAlertAction(title: "취소", style: .cancel))
        present(ac, animated: true)
    }

    private func showCameraPicker() {
        let locStatus = locationManager.authorizationStatus
        switch locStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            // 이미 권한 허용 → 위치 1회 요청 후 즉시 카메라 표시
            prepareLocationForCapture()
            presentSystemCameraPicker()
        case .notDetermined:
            // 권한 결과를 기다렸다가 카메라 표시
            pendingCameraPresentation = true
            prepareLocationForCapture() // 내부에서 requestWhenInUseAuthorization()
            // 카메라는 locationManagerDidChangeAuthorization에서 표시됨
        default:
            // 거부/제한 상태 → 안내 알림 후 사용자가 계속을 선택하면 카메라 표시
            showLocationDeniedAlert { [weak self] in
                self?.presentSystemCameraPicker()
            }
        }
    }

    private func presentSystemCameraPicker() {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.allowsEditing = false
        picker.delegate = self
        present(picker, animated: true)
    }

    private func presentPhotoLibrary() {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.allowsEditing = false
        picker.delegate = self
        present(picker, animated: true)
    }

    // MARK: - Permissions
    private func requestPhotoReadPermission(_ completion: @escaping (Bool) -> Void) {
        if #available(iOS 14, *) {
            let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            switch status {
            case .authorized, .limited: completion(true)
            case .notDetermined:
                PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                    completion(newStatus == .authorized || newStatus == .limited)
                }
            default: completion(false)
            }
        } else {
            let status = PHPhotoLibrary.authorizationStatus()
            switch status {
            case .authorized: completion(true)
            case .notDetermined:
                PHPhotoLibrary.requestAuthorization { newStatus in
                    completion(newStatus == .authorized)
                }
            default: completion(false)
            }
        }
    }

    private func requestPhotoAddPermission(_ completion: @escaping (Bool) -> Void) {
        if #available(iOS 14, *) {
            let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
            switch status {
            case .authorized: completion(true)
            case .notDetermined:
                PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                    completion(newStatus == .authorized)
                }
            default: completion(false)
            }
        } else {
            let status = PHPhotoLibrary.authorizationStatus()
            switch status {
            case .authorized: completion(true)
            case .notDetermined:
                PHPhotoLibrary.requestAuthorization { newStatus in
                    completion(newStatus == .authorized)
                }
            default: completion(false)
            }
        }
    }

    // MARK: - Alerts
    private func showCameraDeniedAlert() {
        let ac = UIAlertController(title: "카메라 권한 필요",
                                   message: "설정 > SpaceWalker > 카메라에서 권한을 허용해 주세요.",
                                   preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "취소", style: .cancel))
        ac.addAction(UIAlertAction(title: "설정 열기", style: .default, handler: { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }))
        present(ac, animated: true)
    }

    private func showPhotoDeniedAlert() {
        let ac = UIAlertController(title: "사진 접근 권한 필요",
                                   message: "설정 > SpaceWalker > 사진에서 권한을 허용해 주세요.",
                                   preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "확인", style: .default))
        present(ac, animated: true)
    }

    private func refreshHeaderTitle() {
        let y = cal.component(.year, from: calendar.currentPage)
        let m = cal.component(.month, from: calendar.currentPage)
        monthTitleLabel.text = String(format: "%d년 %d월", y, m)
    }

    // MARK: - Chip helpers
    private func makeChipButton(title: String, selected: Bool) -> UIButton {
        var config = UIButton.Configuration.plain()
        config.title = title
        config.baseForegroundColor = .label
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14)

        let b = UIButton(configuration: config)
        b.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
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
        for d in [1,3,5,8,12,15,18,20,22,25,27,30] {
            if let date = dateFor(day: d, in: page) {
                photos[date] = colorImage(color)
            }
        }
    }

    private func dateFor(day: Int, in page: Date) -> Date? {
        let y = cal.component(.year, from: page)
        let m = cal.component(.month, from: page)
        var comps = DateComponents(year: y, month: m, day: day)
        return cal.date(from: comps)
    }
    
    private func dayString(for date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = .current
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: date)
    }
}

// MARK: - FSCalendar DataSource / Delegate
extension CalendarViewController: FSCalendarDataSource, FSCalendarDelegate, FSCalendarDelegateAppearance {

    func calendar(_ calendar: FSCalendar, cellFor date: Date, at position: FSCalendarMonthPosition) -> FSCalendarCell {
        let cell = calendar.dequeueReusableCell(withIdentifier: ThumbnailCalendarCell.reuseID, for: date, at: position) as! ThumbnailCalendarCell
        let day = cal.component(.day, from: date)

        let dimmed = (position != .current)
        let selected = (selectedDate != nil) && cal.isDate(selectedDate!, inSameDayAs: date)
        let image = photos.first { cal.isDate($0.key, inSameDayAs: date) }?.value
        cell.configure(day: day, image: image, selected: selected, dimmed: dimmed)
        return cell
    }

    func calendar(_ calendar: FSCalendar, didSelect date: Date, at monthPosition: FSCalendarMonthPosition) {
        selectedDate = date

        // 다른 달의 셀을 탭했을 때는 먼저 페이지 이동
        if monthPosition != .current {
            calendar.setCurrentPage(date, animated: true)
            refreshHeaderTitle()
            if joinedSpaces.indices.contains(selectedChipIndex) {
                let selected = joinedSpaces[selectedChipIndex]
                fetchSpaceActivities(spaceId: selected.id)
            }
        }

        // 1) 해당 날짜에 사진이 있으면 → 상세 모달 표시
        if let image = photos.first(where: { cal.isDate($0.key, inSameDayAs: date) })?.value {

            // 해상도(픽셀 단위) 계산
            let pixelW = Int(image.size.width * image.scale)
            let pixelH = Int(image.size.height * image.scale)
            let resolutionText = "\(pixelW) × \(pixelH)"

            // 시간 텍스트
            let tf = DateFormatter()
            tf.locale = Locale(identifier: "ko_KR")
            tf.dateFormat = "a h:mm"
            let shotTime = tf.string(from: date)

            // 상세 모델 구성 (데모 값)
            let model = SpacePhotoDetailModel(
                image: image,
                date: date,
                missionTitle: "자연 풍경 감상하기",
                isPublic: true,
                likeCount: 42,
                authorName: "김철수",
                locationName: "북한산",
                deviceName: UIDevice.current.name,
                resolutionText: resolutionText,
                fileSizeText: "—",
                shotTimeText: shotTime
            )

            let vc = CalendarDetailViewController(model: model)

            // 삭제 시 달력 썸네일 제거 후 갱신
            vc.onDelete = { [weak self] in
                guard let self = self else { return }
                if let key = self.photos.first(where: { self.cal.isDate($0.key, inSameDayAs: date) })?.key {
                    self.photos.removeValue(forKey: key)
                    self.calendar.reloadData()
                }
            }

            present(vc, animated: true)
            return
        }

        // 2) 사진이 없으면 기존 동작 유지
        calendar.reloadData()
    }

    func calendar(_ calendar: FSCalendar, boundingRectWillChange bounds: CGRect, animated: Bool) {
        calendar.snp.updateConstraints { _ in
            self.calendarHeightConstraint?.update(offset: bounds.height)
        }
        UIView.animate(withDuration: animated ? 0.25 : 0.0) {
            self.view.layoutIfNeeded()
        }
    }

    func calendarCurrentPageDidChange(_ calendar: FSCalendar) {
        refreshHeaderTitle()
        if joinedSpaces.indices.contains(selectedChipIndex) {
            let selected = joinedSpaces[selectedChipIndex]
            fetchSpaceActivities(spaceId: selected.id)
        }
    }

    func calendar(_ calendar: FSCalendar, appearance: FSCalendarAppearance, titleDefaultColorFor date: Date) -> UIColor? { .clear }
    func calendar(_ calendar: FSCalendar, appearance: FSCalendarAppearance, titleSelectionColorFor date: Date) -> UIColor? { .clear }
}

// MARK: - UIImagePickerControllerDelegate
extension CalendarViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {

        // 카메라 촬영/포토 라이브러리 선택 공통
        let image = info[.originalImage] as? UIImage
        let metadata = info[.mediaMetadata] as? [String: Any]
        picker.dismiss(animated: true) { [weak self] in
            guard let self, let image else { return }

            // 앨범 저장 권한 확인 후, 위치 포함 저장 시도
            self.requestPhotoAddPermission { granted in
                guard granted else {
                    DispatchQueue.main.async { self.showPhotoDeniedAlert() }
                    return
                }
                self.savePhotoWithLocation(image, metadata: metadata)   // [Location+Save] 위치 + 메타데이터 포함 저장
            }
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}

// MARK: - Image Loading
extension CalendarViewController {
    // Alamofire 전용 세션 (URLCache 설정)
    private static let afSession: Session = {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.urlCache = URLCache(
            memoryCapacity: 50 * 1024 * 1024, // 50MB
            diskCapacity: 200 * 1024 * 1024,  // 200MB
            diskPath: "calendar.image.cache"
        )
        return Session(configuration: config)
    }()

    /// 간단한 비동기 이미지 로더
    fileprivate func loadImage(from url: URL, completion: @escaping (UIImage?) -> Void) {
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 30)
        CalendarViewController.afSession.request(request)
            .validate(statusCode: 200..<400)
            .responseData(queue: .global(qos: .userInitiated)) { [weak self] response in
                switch response.result {
                case .success(let data):
                    let image = UIImage(data: data)
                    DispatchQueue.main.async { completion(image) }
                case .failure(let error):
                    // Optionally log using logger if available
                    self?.logger.error("[AF] image request failed — url=\(url.absoluteString, privacy: .public), error=\(error.localizedDescription, privacy: .public)")
                    DispatchQueue.main.async { completion(nil) }
                }
            }
    }
}

// MARK: - Date Parsing (UTC -> Date)
extension CalendarViewController {
    /// 서버에서 오는 UTC 문자열(타임존 표기 없을 수 있음)을 Date로 파싱
    fileprivate func parseActivityUTCDate(_ string: String) -> Date? {
        // 1) ISO8601 with fractional seconds (UTC)
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        iso.timeZone = TimeZone(secondsFromGMT: 0)
        if let d = iso.date(from: string) { return d }

        // 2) ISO8601 without fractional seconds (UTC)
        let iso2 = ISO8601DateFormatter()
        iso2.formatOptions = [.withInternetDateTime]
        iso2.timeZone = TimeZone(secondsFromGMT: 0)
        if let d = iso2.date(from: string) { return d }

        // 3) Explicit formats assuming UTC
        let fmts = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
            "yyyy-MM-dd'T'HH:mm:ss.SSS",
            "yyyy-MM-dd'T'HH:mm:ss"
        ]
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        for f in fmts {
            df.dateFormat = f
            if let d = df.date(from: string) { return d }
        }

        // 4) Try appending 'Z' if missing
        if let d = iso.date(from: string + "Z") { return d }

        logger.error("[DateParse] failed to parse UTC date — string=\(string, privacy: .public)")
        return nil
    }
}

// MARK: - Save with Location (PHPhotoLibrary)
extension CalendarViewController {

    /// 현재 위치가 있으면 위치 메타데이터와 함께 저장, 없으면 위치 없이 저장
    private func savePhotoWithLocation(_ image: UIImage, metadata: [String: Any]?) {
        // JPEG 데이터 생성 (EXIF/TIFF 메타데이터 삽입)
        guard let data = jpegData(with: image, metadata: metadata) else { return }

        let location = currentLocation // 캡처

        PHPhotoLibrary.shared().performChanges({
            let req = PHAssetCreationRequest.forAsset()
            let options = PHAssetResourceCreationOptions()
            req.addResource(with: .photo, data: data, options: options)
            req.creationDate = Date()
            if let location { req.location = location }    // 위치 메타데이터 포함 (PHAsset)
        }, completionHandler: { success, error in
            DispatchQueue.main.async {
                if success {
                    // Realm에 사진 메타데이터 저장
                    let capturedAt = Date()
                    let s3Key = "pending-" + UUID().uuidString // TODO: S3 업로드 후 실제 키로 업데이트
                    self.persistPhotoMetadata(image: image, capturedAt: capturedAt, location: location, s3Key: s3Key)

                    let ac = UIAlertController(title: "저장 완료",
                                               message: location != nil ? "위치가 포함되었습니다." : "위치 없이 저장되었습니다.",
                                               preferredStyle: .alert)
                    ac.addAction(UIAlertAction(title: "확인", style: .default))
                    self.present(ac, animated: true)
                } else {
                    let ac = UIAlertController(title: "저장 실패",
                                               message: error?.localizedDescription ?? "사진을 저장하지 못했습니다.",
                                               preferredStyle: .alert)
                    ac.addAction(UIAlertAction(title: "확인", style: .default))
                    self.present(ac, animated: true)
                }
            }
        })
    }

    /// 이미지에 EXIF/TIFF 메타데이터를 삽입하여 JPEG Data 생성
    private func jpegData(with image: UIImage, metadata: [String: Any]?) -> Data? {
        var meta = metadata ?? [:]

        // TIFF 기본값 보완 (제조사/모델)
        var tiff = (meta[kCGImagePropertyTIFFDictionary as String] as? [String: Any]) ?? [:]
        if tiff[kCGImagePropertyTIFFMake as String] == nil { tiff[kCGImagePropertyTIFFMake as String] = "Apple" }
        if tiff[kCGImagePropertyTIFFModel as String] == nil { tiff[kCGImagePropertyTIFFModel as String] = UIDevice.current.model }
        meta[kCGImagePropertyTIFFDictionary as String] = tiff

        // EXIF 기본값 보완 (렌즈 정보 등)
        var exif = (meta[kCGImagePropertyExifDictionary as String] as? [String: Any]) ?? [:]
        if exif[kCGImagePropertyExifLensMake as String] == nil { exif[kCGImagePropertyExifLensMake as String] = "Apple" }
        if exif[kCGImagePropertyExifLensModel as String] == nil { exif[kCGImagePropertyExifLensModel as String] = "Built-in Lens" }
        meta[kCGImagePropertyExifDictionary as String] = exif

        // Orientation 보존
        let cgOrientation = CGImagePropertyOrientation(image.imageOrientation)
        meta[kCGImagePropertyOrientation as String] = cgOrientation.rawValue

        // CGImage 확보
        var cgImage: CGImage?
        if let base = image.cgImage {
            cgImage = base
        } else {
            // CIImage 기반이거나 CGImage가 없는 경우 렌더링해서 생성
            let format = UIGraphicsImageRendererFormat.default()
            format.scale = image.scale
            let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
            let rendered = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: image.size))
            }
            cgImage = rendered.cgImage
        }
        guard let cgImage else { return image.jpegData(compressionQuality: 0.95) }

        let mutableData = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(mutableData, UTType.jpeg.identifier as CFString, 1, nil) else {
            return image.jpegData(compressionQuality: 0.95)
        }
        CGImageDestinationAddImage(dest, cgImage, meta as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return image.jpegData(compressionQuality: 0.95) }
        return mutableData as Data
    }
    
    /// Realm에 PhotoMetadata 저장
    private func persistPhotoMetadata(image: UIImage, capturedAt: Date, location: CLLocation?, s3Key: String) {
        // 픽셀 단위 해상도 계산
        let pixelWidth = Int(image.size.width * image.scale)
        let pixelHeight = Int(image.size.height * image.scale)

        // 위치 좌표 (없으면 0으로 저장)
        let lat = location?.coordinate.latitude ?? 0.0
        let lon = location?.coordinate.longitude ?? 0.0

        do {
            let realm = try Realm()
            let meta = PhotoMetadata()
            meta.s3Key = s3Key
            meta.capturedAt = capturedAt
            meta.width = pixelWidth
            meta.height = pixelHeight
            meta.latitude = lat
            meta.longitude = lon

            try realm.write {
                realm.add(meta)
                if let url = realm.configuration.fileURL {
                    #if targetEnvironment(simulator)
                    // 시뮬레이터: 이 경로는 macOS에서 직접 접근 가능 (Finder에서 열 수 있음)
                    print("Realm file (Finder accessible): \(url.path)")
                    print("Open in Finder with: open \"\(url.deletingLastPathComponent().path)\"")
                    #else
                    // 실기기: macOS Finder에서 직접 접근 불가. Files 앱 또는 Xcode > Devices and Simulators에서 컨테이너 다운로드 필요
                    print("Realm file (on iOS device): \(url.path)")
                    print("Tip: In Xcode, Window > Devices and Simulators > select device > Installed Apps > SpaceWalker > Download Container…")
                    #endif
                }
            }
        } catch {
            // 개발 중 로깅
            print("Realm write failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension CalendarViewController: CLLocationManagerDelegate {

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            if pendingOneShotLocation {
                pendingOneShotLocation = false
                manager.requestLocation()
            }
            if pendingCameraPresentation {
                pendingCameraPresentation = false
                presentSystemCameraPicker()
            }
        case .denied, .restricted:
            if pendingCameraPresentation {
                pendingCameraPresentation = false
                showLocationDeniedAlert { [weak self] in
                    self?.presentSystemCameraPicker()
                }
            }
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
}

private extension CGImagePropertyOrientation {
    init(_ ui: UIImage.Orientation) {
        switch ui {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}

