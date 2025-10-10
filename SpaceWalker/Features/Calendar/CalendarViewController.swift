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

    // Loading overlay for calendar image fetching
    private let loadingContainer: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.6)
        v.isHidden = true
        v.isUserInteractionEnabled = true // block taps while loading
        return v
    }()
    private let activityIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .large)
        ai.hidesWhenStopped = false
        ai.color = .secondaryLabel
        return ai
    }()
    private let uploadProgressView: UIProgressView = {
        let v = UIProgressView(progressViewStyle: .default)
        v.isHidden = true
        v.progress = 0
        return v
    }()

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

    // Added properties for mission submission flow
    private var isSubmittingMission: Bool = false
    private var currentUploadTask: Request?

    private var currentDailyMissionId: Int?
    // Holds extracted metadata for the current capture until upload completes
    private struct PendingPhotoMeta {
        let image: UIImage
        let capturedAt: Date
        let width: Int
        let height: Int
        let location: CLLocation?
        let spaceId: Int
        let missionId: Int?
        let missionTitle: String?
        let mimeType: String?
    }
    private var pendingPhotoMeta: PendingPhotoMeta?
    // Tracks the most recent local metadata row for the current capture
    private var lastSavedPhotoObjectId: ObjectId?

    // Full-screen overlay option during submission
    private var isLoadingFullScreen: Bool = false

    // Decoded image cache for the current app session (lightweight)
    private let imageCache = NSCache<NSString, UIImage>()

    /// 현재 페이지(월)의 날짜별 썸네일 + 게시물 식별자
    private struct DayPhoto {
        let image: UIImage
        let postId: Int
    }
    private var photos: [Date: DayPhoto] = [:]
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

        // Loading overlay on calendar
        view.addSubview(loadingContainer)
        loadingContainer.addSubview(activityIndicator)
        loadingContainer.addSubview(uploadProgressView)
        loadingContainer.snp.makeConstraints { make in
            make.edges.equalTo(calendar)
        }
        activityIndicator.snp.makeConstraints { make in
            make.center.equalTo(loadingContainer)
        }
        uploadProgressView.snp.makeConstraints { make in
            make.top.equalTo(activityIndicator.snp.bottom).offset(12)
            make.leading.trailing.equalTo(loadingContainer).inset(40)
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
        
        // Show loading indicator for this fetch cycle
        self.showCalendarLoading(expectedKey: fetchKey)

        repository.fetchSpaceActivities(spaceId: spaceId, year: year, month: month, timezone: timezone)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] response in
                guard let self else { return }

                let elapsed = Date().timeIntervalSince(requestStart)
                self.logger.info("[Network] fetchSpaceActivities success — elapsed=\(elapsed, format: .fixed(precision: 2))s, dailyMission=\(response.dailyMission.title, privacy: .public), activitiesCount=\(response.activities.count, privacy: .public)")

                // 오늘의 미션
                self.missionLabel.text = response.dailyMission.title
                self.currentDailyMissionId = response.dailyMission.missionId

                // Check if there's an activity for 'today' in user's local timezone (Calendar.current)
                let todayLocalStart = self.cal.startOfDay(for: Date())
                var hasTodayActivity = false
                for activity in response.activities {
                    if let utcDate = self.parseActivityUTCDate(activity.date) {
                        // Date is absolute; compare using local Calendar to determine same local day
                        if self.cal.isDate(utcDate, inSameDayAs: todayLocalStart) {
                            hasTodayActivity = true
                            break
                        }
                    }
                }

                // Update mission button based on today's completion status
                var btnConfig = self.missionButton.configuration
                if hasTodayActivity {
                    self.missionButton.isEnabled = false
                    btnConfig?.title = "오늘 미션을 완료했어요"
                } else {
                    self.missionButton.isEnabled = true
                    btnConfig?.title = "미션하러 가기"
                }
                self.missionButton.configuration = btnConfig

                // 활동 날짜별 썸네일 맵핑 (병렬 다운로드 + 일괄 갱신)
                let expectedKey = fetchKey // 캡처: non-optional key
                let group = DispatchGroup()
                var resultMap: [Date: DayPhoto] = [:]
                let resultQueue = DispatchQueue(label: "calendar.photos.result", attributes: .concurrent)

                for activity in response.activities {
                    guard let utcDate = self.parseActivityUTCDate(activity.date) else { continue }
                    guard let url = URL(string: activity.photo) else { continue }

                    // Lightweight in-memory cache lookup (per local day using Calendar.current)
                    let dayKeyString = "space:\(spaceId)|day:\(self.dayString(for: self.cal.startOfDay(for: utcDate)))"
                    if let cached = self.imageCache.object(forKey: dayKeyString as NSString) {
                        // 캐시 적중: 결과에 즉시 반영하고 다운로드 생략
                        let localDay = self.cal.startOfDay(for: utcDate)
                        // 활동의 postId를 안전하게 언랩하여 DayPhoto로 저장 (캐시 이미지를 활용)
                        resultQueue.async(flags: .barrier) {
                            resultMap[localDay] = DayPhoto(image: cached, postId: activity.postId)
                        }
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
                            let localDay = self.cal.startOfDay(for: utcDate)
                            // 캐시에 저장 후 결과 반영 (동시 접근 보호)
                            let key = "space:\(spaceId)|day:\(self.dayString(for: localDay))"
                            self.imageCache.setObject(image, forKey: key as NSString)
                            // 활동의 postId를 안전하게 언랩하여 DayPhoto로 저장
                            resultQueue.async(flags: .barrier) {
                                resultMap[localDay] = DayPhoto(image: image, postId: activity.postId)
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
                    self.hideCalendarLoading(expectedKey: expectedKey)
                    self.photos = resultMap
                    self.calendar.reloadData()
                    self.logger.info("[Image] all downloads completed — count=\(resultMap.count, privacy: .public)")
                }

            }, onFailure: { error in
                let elapsed = Date().timeIntervalSince(requestStart)
                self.hideCalendarLoading(expectedKey: self.currentFetchKey ?? "")
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

    // MARK: - Loading Indicator
    private func showCalendarLoading(expectedKey: String) {
        // Only show if this request is still current
        guard expectedKey == currentFetchKey else { return }
        loadingContainer.isHidden = false
        activityIndicator.startAnimating()
    }

    private func hideCalendarLoading(expectedKey: String) {
        // Only hide if this request is still current
        guard expectedKey == currentFetchKey else { return }
        activityIndicator.stopAnimating()
        loadingContainer.isHidden = true
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
        guard joinedSpaces.indices.contains(selectedChipIndex) else {
            showAlert(title: "스페이스 선택 필요", message: "미션 제출을 위해 먼저 스페이스를 선택하세요.")
            return
        }
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
        guard joinedSpaces.indices.contains(selectedChipIndex) else {
            showAlert(title: "스페이스 선택 필요", message: "미션 제출을 위해 먼저 스페이스를 선택하세요.")
            return
        }
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
                photos[date] = DayPhoto(image: colorImage(color), postId: 0)
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
        let image = photos.first { cal.isDate($0.key, inSameDayAs: date) }?.value.image
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

        // 1) 해당 날짜에 사진이 있으면 → 상세 모달 표시 (실제 postId 사용)
        if let dayPhoto = photos.first(where: { cal.isDate($0.key, inSameDayAs: date) })?.value {
            let postId = dayPhoto.postId
            let spaceIdForDetail = (self.joinedSpaces.indices.contains(self.selectedChipIndex)) ? self.joinedSpaces[self.selectedChipIndex].id : 0
            let identifier = SpacePostIdentifier(spaceId: spaceIdForDetail, postId: postId)

            // Build a lightweight placeholder model to show immediately while fetching real detail
            let missionTitle = self.missionLabel.text ?? "오늘의 미션"
            let image = dayPhoto.image
            let pixelW = Int(image.size.width * image.scale)
            let pixelH = Int(image.size.height * image.scale)
            let resolutionText = "\(pixelW) × \(pixelH)"
            let timeDF = DateFormatter()
            timeDF.locale = Locale(identifier: "ko_KR")
            timeDF.dateFormat = "a h:mm"
            let shotTimeText = timeDF.string(from: date)
            let placeholder = SpacePhotoDetailModel(
                image: image,
                date: date,
                missionTitle: missionTitle,
                isPublic: true,
                likeCount: 0,
                authorName: "",
                locationName: nil,
                deviceName: UIDevice.current.model,
                resolutionText: resolutionText,
                fileSizeText: "알 수 없음",
                shotTimeText: shotTimeText
            )
            let vc = CalendarDetailViewController(identifier: identifier, placeholderModel: placeholder)

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
            
            // Extract and store metadata for later Realm persistence (after upload)
            let capturedAt = Date()
            let pixelW = Int(image.size.width * image.scale)
            let pixelH = Int(image.size.height * image.scale)
            let location = self.currentLocation // prefer current one-shot location
            let spaceId = (self.joinedSpaces.indices.contains(self.selectedChipIndex)) ? self.joinedSpaces[self.selectedChipIndex].id : 0
            let missionId = self.currentDailyMissionId
            let missionTitle = self.missionLabel.text
            // mimeType will be known when encoding for upload
            self.pendingPhotoMeta = PendingPhotoMeta(image: image,
                                                     capturedAt: capturedAt,
                                                     width: pixelW,
                                                     height: pixelH,
                                                     location: location,
                                                     spaceId: spaceId,
                                                     missionId: missionId,
                                                     missionTitle: missionTitle,
                                                     mimeType: nil)

            // 앨범 저장 권한 확인 후, 위치 포함 저장 시도
            self.requestPhotoAddPermission { granted in
                guard granted else {
                    DispatchQueue.main.async { self.showPhotoDeniedAlert() }
                    return
                }
                self.savePhotoWithLocation(image, metadata: metadata)   // [Location+Save] 위치 + 메타데이터 포함 저장
                
                // Begin transactional upload -> submit flow
                DispatchQueue.main.async {
                    guard self.joinedSpaces.indices.contains(self.selectedChipIndex) else { return }
                    let spaceId = self.joinedSpaces[self.selectedChipIndex].id
                    let missionTitle = self.missionLabel.text ?? "오늘의 미션"
                    // Encode a fresh image without embedded metadata (GPS removed) for upload
                    if let encoded = self.encodeImageForUpload(image, originalMetadata: metadata) {
                        self.startMissionSubmissionTransaction(spaceId: spaceId, image: image, imageData: encoded.data, mimeType: encoded.mimeType, missionTitle: missionTitle)
                    } else {
                        self.showAlert(title: "업로드 준비 실패", message: "이미지를 인코딩하지 못했습니다.")
                    }
                }
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
                    // Realm persistence is deferred until upload succeeds (we only save to Photos here)

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
    private func persistPhotoMetadata(image: UIImage, capturedAt: Date, location: CLLocation?, s3Key: String, mimeType: String? = nil) {
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
            if let mimeType { meta.mimeType = mimeType }
            
            // Attach optional context
            if self.joinedSpaces.indices.contains(self.selectedChipIndex) {
                meta.spaceId = self.joinedSpaces[self.selectedChipIndex].id
            } else {
                meta.spaceId = 0
            }
            meta.missionId = self.currentDailyMissionId
            meta.missionTitle = self.missionLabel.text
            
            try realm.write {
                realm.add(meta)
                self.lastSavedPhotoObjectId = meta.id
                
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

// MARK: - Mission Submission (Presigned URL -> S3 PUT -> Submit)
extension CalendarViewController {

    private func encodeImageForUpload(_ image: UIImage, originalMetadata: [String: Any]?) -> (data: Data, mimeType: String)? {
        // Build sanitized metadata: preserve non-sensitive fields and orientation, strip GPS and personal info
        let sanitized = sanitizedMetadata(for: image, original: originalMetadata)

        // Prefer HEIC with metadata
        if let heic = dataWithMetadata(image: image, uti: UTType.heic, quality: 0.9, metadata: sanitized) {
            return (heic, "image/heic")
        }
        // Fallback to JPEG with metadata
        if let jpeg = dataWithMetadata(image: image, uti: UTType.jpeg, quality: 0.9, metadata: sanitized) {
            return (jpeg, "image/jpeg")
        }
        // Last resort: PNG (metadata generally ignored)
        if let png = image.pngData() {
            return (png, "image/png")
        }
        return nil
    }

    /// Create image data of given UTI embedding provided metadata and compression quality (if applicable)
    private func dataWithMetadata(image: UIImage, uti: UTType, quality: CGFloat, metadata: [String: Any]) -> Data? {
        // Ensure we have a CGImage. If not, render one from UIImage.
        var cgImage: CGImage? = image.cgImage
        if cgImage == nil {
            let format = UIGraphicsImageRendererFormat.default()
            format.scale = image.scale
            let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
            let rendered = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: image.size)) }
            cgImage = rendered.cgImage
        }
        guard let cgImage else { return nil }

        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, uti.identifier as CFString, 1, nil) else { return nil }

        // Merge compression quality and provided metadata
        var props = metadata
        props[kCGImageDestinationLossyCompressionQuality as String] = quality

        CGImageDestinationAddImage(dest, cgImage, props as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return out as Data
    }

    /// Build sanitized metadata by merging original and defaults, removing sensitive info, and setting correct orientation
    private func sanitizedMetadata(for image: UIImage, original: [String: Any]?) -> [String: Any] {
        var meta = original ?? [:]

        // Remove GPS entirely
        meta.removeValue(forKey: kCGImagePropertyGPSDictionary as String)
        // Remove IPTC if present (can include identifying info)
        meta.removeValue(forKey: kCGImagePropertyIPTCDictionary as String)

        // Clean EXIF sensitive fields
        var exif = (meta[kCGImagePropertyExifDictionary as String] as? [String: Any]) ?? [:]
        let exifSensitiveKeys: [CFString] = [
            kCGImagePropertyExifUserComment,
            kCGImagePropertyExifCameraOwnerName,
            kCGImagePropertyExifBodySerialNumber,
            kCGImagePropertyExifLensSerialNumber,
            kCGImagePropertyExifMakerNote
        ]
        for key in exifSensitiveKeys { exif.removeValue(forKey: key as String) }
        // Keep benign defaults
        if exif[kCGImagePropertyExifLensMake as String] == nil { exif[kCGImagePropertyExifLensMake as String] = "Apple" }
        if exif[kCGImagePropertyExifLensModel as String] == nil { exif[kCGImagePropertyExifLensModel as String] = "Built-in Lens" }
        meta[kCGImagePropertyExifDictionary as String] = exif

        // Clean TIFF sensitive fields
        var tiff = (meta[kCGImagePropertyTIFFDictionary as String] as? [String: Any]) ?? [:]
        let tiffSensitiveKeys: [CFString] = [
            kCGImagePropertyTIFFArtist,
            kCGImagePropertyTIFFCopyright,
            kCGImagePropertyTIFFSoftware
        ]
        for key in tiffSensitiveKeys { tiff.removeValue(forKey: key as String) }
        if tiff[kCGImagePropertyTIFFMake as String] == nil { tiff[kCGImagePropertyTIFFMake as String] = "Apple" }
        if tiff[kCGImagePropertyTIFFModel as String] == nil { tiff[kCGImagePropertyTIFFModel as String] = UIDevice.current.model }
        meta[kCGImagePropertyTIFFDictionary as String] = tiff

        // Always set Orientation from UIImage to ensure correct display if reader honors EXIF
        let cgOrientation = CGImagePropertyOrientation(image.imageOrientation)
        meta[kCGImagePropertyOrientation as String] = cgOrientation.rawValue

        return meta
    }

    private func heicData(from image: UIImage, quality: CGFloat) -> Data? {
        guard let cgImage = image.cgImage else { return nil }
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, UTType.heic.identifier as CFString, 1, nil) else { return nil }
        let options: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: quality]
        CGImageDestinationAddImage(dest, cgImage, options as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return data as Data
    }

    private func startMissionSubmissionTransaction(spaceId: Int, image: UIImage, imageData: Data, mimeType: String, missionTitle: String) {
        if isSubmittingMission { return }
        isSubmittingMission = true
        logger.info("[Mission] start submission transaction — spaceId=\(spaceId, privacy: .public), mime=\(mimeType, privacy: .public)")

        // Record mimeType into pending meta for later Realm persistence
        if var pending = self.pendingPhotoMeta {
            self.pendingPhotoMeta = PendingPhotoMeta(image: pending.image,
                                                     capturedAt: pending.capturedAt,
                                                     width: pending.width,
                                                     height: pending.height,
                                                     location: pending.location,
                                                     spaceId: pending.spaceId,
                                                     missionId: pending.missionId,
                                                     missionTitle: pending.missionTitle,
                                                     mimeType: mimeType)
        }

        // Expand overlay to full screen during submission
        loadingContainer.snp.remakeConstraints { make in
            make.edges.equalTo(self.view)
        }
        self.view.layoutIfNeeded()
        isLoadingFullScreen = true
        uploadProgressView.isHidden = false
        uploadProgressView.progress = 0

        // Reuse loading overlay to block UI during submission
        loadingContainer.isHidden = false
        activityIndicator.startAnimating()

        let requestStart = Date()
        repository.requestPresignedUpload(spaceId: spaceId, mimeType: mimeType, timezone: TimeZone.current.identifier)
            .flatMap { [weak self] (resp: SpaceRepository.PresignedUploadResponse) -> Single<SpaceRepository.SubmitMissionResponse> in
                guard let self = self else { return .error(NSError(domain: "CalendarVC", code: -1)) }
                let uploadURLString = resp.mainImageUrl
                guard let uploadURL = URL(string: uploadURLString) else {
                    return .error(NSError(domain: "CalendarVC", code: -2, userInfo: [NSLocalizedDescriptionKey: "잘못된 업로드 URL"]))
                }

                // S3 PUT upload
                return Single<SpaceRepository.SubmitMissionResponse>.create { [weak self] single in
                    guard let self = self else { return Disposables.create() }
                    let headers: HTTPHeaders = ["Content-Type": mimeType]
                    let req = CalendarViewController.afSession.upload(imageData, to: uploadURL, method: .put, headers: headers)
                        .uploadProgress { prog in
                            DispatchQueue.main.async {
                                self.uploadProgressView.isHidden = false
                                self.uploadProgressView.progress = Float(prog.fractionCompleted)
                            }
                        }
                        .validate(statusCode: 200..<300)
                        .response { response in
                            if let err = response.error {
                                self.logger.error("[S3] upload failed — status=\(response.response?.statusCode ?? -1), error=\(err.localizedDescription, privacy: .public)")
                                if let data = response.data, let body = String(data: data, encoding: .utf8) {
                                    self.logger.error("[S3] upload error body — \(body, privacy: .public)")
                                }
                                single(.failure(err))
                                return
                            }
                            let status = response.response?.statusCode ?? -1
                            if 200..<300 ~= status {
                                self.logger.info("[S3] upload success — status=\(status)")
                                
                                // Persist metadata to Realm now with the real S3 key
                                if let pending = self.pendingPhotoMeta {
                                    self.persistPhotoMetadata(image: pending.image,
                                                              capturedAt: pending.capturedAt,
                                                              location: pending.location,
                                                              s3Key: resp.mainImageKey,
                                                              mimeType: mimeType)
                                }
                                
                                // Proceed to submit mission
                                let daily = SpaceRepository.DailyMissionSubmit(missionId: self.currentDailyMissionId ?? 1, title: missionTitle)
                                self.repository.submitMission(spaceId: spaceId, s3objectKey: resp.mainImageKey, dailyMission: daily, isPublic: true, timezone: TimeZone.current.identifier)
                                    .subscribe(onSuccess: { submitResp in
                                        single(.success(submitResp))
                                    }, onFailure: { err in
                                        single(.failure(err))
                                    })
                                    .disposed(by: self.disposeBag)
                            } else {
                                self.logger.error("[S3] upload non-200 — status=\(status)")
                                single(.failure(NSError(domain: "CalendarVC", code: status, userInfo: [NSLocalizedDescriptionKey: "S3 업로드 실패 (\(status))"])) )
                            }
                        }
                    self.currentUploadTask = req
                    return Disposables.create { [weak self] in
                        self?.currentUploadTask?.cancel()
                    }
                }
            }
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] (resp: SpaceRepository.SubmitMissionResponse) in
                guard let self = self else { return }
                let elapsed = Date().timeIntervalSince(requestStart)
                self.logger.info("[Mission] submit success — elapsed=\(elapsed, format: .fixed(precision: 2))s, success=\(resp.success)")
                self.activityIndicator.stopAnimating()
                self.loadingContainer.isHidden = true

                // Restore overlay to calendar area
                self.loadingContainer.snp.remakeConstraints { make in
                    make.edges.equalTo(self.calendar)
                }
                self.view.layoutIfNeeded()
                self.isLoadingFullScreen = false
                self.uploadProgressView.isHidden = true

                self.isSubmittingMission = false
                self.showAlert(title: "미션 제출 완료", message: "사진 업로드와 제출이 완료되었습니다.")
                
                // Refresh calendar by fetching latest activities for the current page/space
                if self.joinedSpaces.indices.contains(self.selectedChipIndex) {
                    let selected = self.joinedSpaces[self.selectedChipIndex]
                    self.fetchSpaceActivities(spaceId: selected.id)
                }
            }, onFailure: { [weak self] err in
                guard let self = self else { return }
                let elapsed = Date().timeIntervalSince(requestStart)
                self.logger.error("[Mission] submit failed — elapsed=\(elapsed, format: .fixed(precision: 2))s, error=\(err.localizedDescription, privacy: .public)")
                if let serverBody = self.extractServerErrorMessage(from: err) {
                    self.logger.error("[Mission] submit server error body — \(serverBody, privacy: .public)")
                }
                self.activityIndicator.stopAnimating()
                self.loadingContainer.isHidden = true

                // Restore overlay to calendar area
                self.loadingContainer.snp.remakeConstraints { make in
                    make.edges.equalTo(self.calendar)
                }
                self.view.layoutIfNeeded()
                self.isLoadingFullScreen = false
                self.uploadProgressView.isHidden = true

                let serverMsg = self.extractServerErrorMessage(from: err)
                let message = serverMsg ?? err.localizedDescription
                self.showAlert(title: "미션 제출 실패", message: message)
                self.isSubmittingMission = false
            })
            .disposed(by: disposeBag)
    }

    /// Try to extract server-provided error message from an Error produced by Alamofire/Network layer
    private func extractServerErrorMessage(from error: Error) -> String? {
        let nsErr = error as NSError
        // Common Alamofire userInfo key for response data
        let alamofireDataKey = "com.alamofire.serialization.response.error.data"
        if let data = nsErr.userInfo[alamofireDataKey] as? Data, let text = String(data: data, encoding: .utf8) {
            return text
        }
        // Fallback: sometimes other keys are used
        let altKeys = ["AFNetworkingOperationFailingURLResponseDataErrorKey", NSLocalizedDescriptionKey]
        for key in altKeys {
            if let data = nsErr.userInfo[key] as? Data, let text = String(data: data, encoding: .utf8) {
                return text
            }
            if let text = nsErr.userInfo[key] as? String, !text.isEmpty { return text }
        }
        // As a last resort, return the error's description
        let desc = nsErr.userInfo[NSLocalizedDescriptionKey] as? String
        return desc
    }

    private func showAlert(title: String, message: String) {
        DispatchQueue.main.async {
            let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "확인", style: .default))
            self.present(ac, animated: true)
        }
    }
}

