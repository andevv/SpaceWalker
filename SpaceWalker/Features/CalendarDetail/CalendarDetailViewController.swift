//
//  CalendarDetailViewController.swift
//  SpaceWalker
//
//  Created by andev on 10/3/25.
//

import UIKit
import SnapKit

struct SpacePhotoDetailModel {
    let image: UIImage
    let date: Date
    let missionTitle: String       // 예: "자연 풍경 감상하기"
    var isPublic: Bool
    let likeCount: Int
    let authorName: String         // 예: "김철수"
    let locationName: String?      // 예: "북한산"
    let deviceName: String         // 예: "iPhone 15 Pro"
    let resolutionText: String     // 예: "4032 × 3024"
    let fileSizeText: String       // 예: "3.2 MB"
    let shotTimeText: String       // 예: "오후 2:34"
}

final class CalendarDetailViewController: UIViewController {

    // MARK: - Dependencies
    private var model: SpacePhotoDetailModel
    var onDelete: (() -> Void)?

    // MARK: - UI
    private let scrollView = UIScrollView()
    private let contentView = UIView()

    // 이미지
    private let imageView = UIImageView()

    // 날짜 / 미션
    private let dateRow = UIStackView()
    private let dateIcon = UIImageView(image: UIImage(systemName: "calendar"))
    private let dateLabel = UILabel()
    private let missionCaption = UILabel()
    private let missionTitleLabel = UILabel()
    private let divider1 = UIView()

    // 좋아요
    private let likeRow = UIStackView()
    private let likeIcon = UIImageView(image: UIImage(systemName: "heart.fill"))
    private let likeLabel = UILabel()

    // 공개 토글 카드
    private let visibilityCard = UIView()
    private let visibilityIcon = UIImageView(image: UIImage(systemName: "lock.open"))
    private let visibilityTitle = UILabel()
    private let visibilitySwitch = UISwitch()
    private let visibilitySubtitle = UILabel()

    // 촬영자 (아이콘+텍스트 직접 제약)
    private let shooterIcon = UIImageView(image: UIImage(systemName: "person.crop.circle"))
    private let shooterName = UILabel()

    // 촬영 위치 (아이콘+텍스트 직접 제약)
    private let locationIcon = UIImageView(image: UIImage(systemName: "mappin.and.ellipse"))
    private let locationName = UILabel()

    // 사진 정보
    private let infoGrid = UIStackView()

    // 삭제 버튼
    private let deleteButton: UIButton = {
        var cfg = UIButton.Configuration.bordered()
        cfg.title = "사진 삭제"
        cfg.baseForegroundColor = .systemRed
        cfg.image = UIImage(systemName: "trash")
        cfg.imagePadding = 8
        cfg.cornerStyle = .large
        let b = UIButton(configuration: cfg)
        b.layer.borderWidth = 1
        b.layer.cornerRadius = 16
        b.layer.borderColor = UIColor.systemRed.withAlphaComponent(0.3).cgColor
        return b
    }()

    // MARK: - Constraint Handles (likeRow 숨김 시 위로 당기기용)
    private var visibilityTopConstraint: Constraint?

    // MARK: - Init
    init(model: SpacePhotoDetailModel) {
        self.model = model
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.selectedDetentIdentifier = .large     // 처음부터 상단까지
            sheet.prefersScrollingExpandsWhenScrolledToEdge = true
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 16
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
        bindData()
        bindActions()
    }

    // MARK: - Setup
    private func setupUI() {
        // Scroll base
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalTo(scrollView.snp.width)
        }

        // Image
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        contentView.addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            // 화면 폭 기준 3:4 비율
            make.height.equalTo(imageView.snp.width).multipliedBy(4.0/3.0)
        }

        // Date row
        dateRow.axis = .horizontal
        dateRow.spacing = 8
        dateIcon.tintColor = .secondaryLabel
        dateIcon.contentMode = .scaleAspectFit
        dateLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        dateLabel.textColor = .label

        contentView.addSubview(dateRow)
        [dateIcon, dateLabel].forEach { dateRow.addArrangedSubview($0) }
        dateRow.snp.makeConstraints { make in
            make.top.equalTo(imageView.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(20)
        }

        // Mission captions
        missionCaption.text = "오늘의 미션"
        missionCaption.font = .systemFont(ofSize: 14, weight: .regular)
        missionCaption.textColor = .secondaryLabel

        missionTitleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        missionTitleLabel.textColor = .label
        missionTitleLabel.numberOfLines = 0

        contentView.addSubview(missionCaption)
        contentView.addSubview(missionTitleLabel)
        missionCaption.snp.makeConstraints { make in
            make.top.equalTo(dateRow.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(20)
        }
        missionTitleLabel.snp.makeConstraints { make in
            make.top.equalTo(missionCaption.snp.bottom).offset(6)
            make.leading.trailing.equalToSuperview().inset(20)
        }

        // Divider
        divider1.backgroundColor = .systemGray5
        contentView.addSubview(divider1)
        divider1.snp.makeConstraints { make in
            make.top.equalTo(missionTitleLabel.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(20)
            make.height.equalTo(1)
        }

        // Like row
        likeRow.axis = .horizontal
        likeRow.spacing = 8
        likeIcon.tintColor = .systemRed
        likeIcon.contentMode = .scaleAspectFit
        likeLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        likeLabel.textColor = .label

        contentView.addSubview(likeRow)
        [likeIcon, likeLabel].forEach { likeRow.addArrangedSubview($0) }
        likeRow.snp.makeConstraints { make in
            make.top.equalTo(divider1.snp.bottom).offset(14)
            make.leading.trailing.equalToSuperview().inset(20)
        }

        // Visibility Card
        visibilityCard.backgroundColor = .secondarySystemBackground
        visibilityCard.layer.cornerRadius = 14
        contentView.addSubview(visibilityCard)

        visibilityIcon.tintColor = .systemBlue
        visibilityIcon.contentMode = .scaleAspectFit

        visibilityTitle.text = "공개"
        visibilityTitle.font = .systemFont(ofSize: 16, weight: .semibold)
        visibilityTitle.textColor = .label

        visibilitySubtitle.text = "다른 사용자가 이 사진을 볼 수 있습니다."
        visibilitySubtitle.font = .systemFont(ofSize: 13, weight: .regular)
        visibilitySubtitle.textColor = .secondaryLabel
        visibilitySubtitle.numberOfLines = 0

        [visibilityIcon, visibilityTitle, visibilitySwitch, visibilitySubtitle].forEach {
            visibilityCard.addSubview($0)
        }

        // likeRow 아래/ divider1 아래 두 가지 top 제약을 준비하고 토글
        visibilityCard.snp.makeConstraints { make in
            // 초기: 공개(true)라고 가정해 likeRow 아래에 붙임
            self.visibilityTopConstraint = make.top.equalTo(likeRow.snp.bottom).offset(12).constraint
            make.leading.trailing.equalToSuperview().inset(20)
        }
        visibilityIcon.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(14)
            make.leading.equalToSuperview().inset(14)
            make.width.height.equalTo(22)
        }
        visibilityTitle.snp.makeConstraints { make in
            make.centerY.equalTo(visibilityIcon)
            make.leading.equalTo(visibilityIcon.snp.trailing).offset(8)
        }
        visibilitySwitch.snp.makeConstraints { make in
            make.centerY.equalTo(visibilityIcon)
            make.trailing.equalToSuperview().inset(14)
        }
        visibilitySubtitle.snp.makeConstraints { make in
            make.top.equalTo(visibilityIcon.snp.bottom).offset(8)
            make.leading.equalTo(visibilityIcon)
            make.trailing.equalToSuperview().inset(14)
            make.bottom.equalToSuperview().inset(12)
        }

        // Shooter (왼쪽 정렬: 아이콘+텍스트 직접 제약)
        let shooterTitle = sectionTitle("촬영자")
        contentView.addSubview(shooterTitle)
        shooterTitle.snp.makeConstraints { make in
            make.top.equalTo(visibilityCard.snp.bottom).offset(18)
            make.leading.trailing.equalToSuperview().inset(20)
        }

        contentView.addSubview(shooterIcon)
        contentView.addSubview(shooterName)

        shooterIcon.tintColor = .secondaryLabel
        shooterIcon.contentMode = .scaleAspectFit
        shooterName.font = .systemFont(ofSize: 16, weight: .semibold)
        shooterName.textColor = .label

        shooterIcon.snp.makeConstraints { make in
            make.top.equalTo(shooterTitle.snp.bottom).offset(10)
            make.leading.equalToSuperview().inset(20)     // 왼쪽 고정
            make.width.height.equalTo(20)
        }
        shooterName.snp.makeConstraints { make in
            make.centerY.equalTo(shooterIcon)
            make.leading.equalTo(shooterIcon.snp.trailing).offset(8) // 아이콘 오른쪽
            make.trailing.lessThanOrEqualToSuperview().inset(20)
        }

        let dividerAfterShooter = makeDivider()
        contentView.addSubview(dividerAfterShooter)
        dividerAfterShooter.snp.makeConstraints { make in
            make.top.equalTo(shooterIcon.snp.bottom).offset(14)
            make.leading.trailing.equalToSuperview().inset(20)
            make.height.equalTo(1)
        }

        // Location (왼쪽 정렬: 아이콘+텍스트 직접 제약)
        let locationTitle = sectionTitle("촬영 위치")
        contentView.addSubview(locationTitle)
        locationTitle.snp.makeConstraints { make in
            make.top.equalTo(dividerAfterShooter.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(20)
        }

        contentView.addSubview(locationIcon)
        contentView.addSubview(locationName)

        locationIcon.tintColor = .systemBlue
        locationIcon.contentMode = .scaleAspectFit
        locationName.font = .systemFont(ofSize: 16, weight: .regular)
        locationName.textColor = .label

        locationIcon.snp.makeConstraints { make in
            make.top.equalTo(locationTitle.snp.bottom).offset(10)
            make.leading.equalToSuperview().inset(20)             // 왼쪽 고정
            make.width.height.equalTo(20)
        }
        locationName.snp.makeConstraints { make in
            make.centerY.equalTo(locationIcon)
            make.leading.equalTo(locationIcon.snp.trailing).offset(8) // 아이콘 오른쪽
            make.trailing.lessThanOrEqualToSuperview().inset(20)
        }

        let dividerAfterLocation = makeDivider()
        contentView.addSubview(dividerAfterLocation)
        dividerAfterLocation.snp.makeConstraints { make in
            make.top.equalTo(locationIcon.snp.bottom).offset(14)
            make.leading.trailing.equalToSuperview().inset(20)
            make.height.equalTo(1)
        }

        // Photo Info
        let infoTitle = sectionTitle("사진 정보")
        contentView.addSubview(infoTitle)
        infoTitle.snp.makeConstraints { make in
            make.top.equalTo(dividerAfterLocation.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(20)
        }

        infoGrid.axis = .vertical
        infoGrid.spacing = 10
        contentView.addSubview(infoGrid)
        infoGrid.snp.makeConstraints { make in
            make.top.equalTo(infoTitle.snp.bottom).offset(10)
            make.leading.trailing.equalToSuperview().inset(20)
        }

        // Delete Button
        contentView.addSubview(deleteButton)
        deleteButton.snp.makeConstraints { make in
            make.top.equalTo(infoGrid.snp.bottom).offset(24)
            make.leading.trailing.equalToSuperview().inset(20)
            make.height.equalTo(52)
            make.bottom.equalToSuperview().inset(24) // scroll content bottom
        }
    }

    private func bindData() {
        // 이미지
        imageView.image = model.image

        // 날짜
        let df = DateFormatter()
        df.locale = Locale(identifier: "ko_KR")
        df.dateFormat = "yyyy년 M월 d일"
        dateLabel.text = df.string(from: model.date)

        // 미션
        missionTitleLabel.text = model.missionTitle

        // 좋아요
        likeLabel.text = "\(model.likeCount)개의 좋아요"
        likeIcon.tintColor = .systemRed

        // 공개/비공개 초기 반영
        visibilitySwitch.isOn = model.isPublic
        applyVisibility(isPublic: model.isPublic, animated: false)

        // 촬영자
        shooterName.text = model.authorName

        // 위치
        locationName.text = model.locationName ?? "위치 정보 없음"
        locationIcon.tintColor = model.locationName == nil ? .tertiaryLabel : .systemBlue
        locationName.textColor = model.locationName == nil ? .tertiaryLabel : .label

        // 사진 정보
        infoGrid.arrangedSubviews.forEach { $0.removeFromSuperview() }
        addInfoRow(icon: "camera", title: "기기", value: model.deviceName)
        addInfoRow(icon: "square.stack.3d.down.right", title: "해상도", value: model.resolutionText)
        addInfoRow(icon: "tray.full", title: "파일 크기", value: model.fileSizeText)
        addInfoRow(icon: "clock", title: "촬영 시간", value: model.shotTimeText)
    }

    private func bindActions() {
        visibilitySwitch.addTarget(self, action: #selector(toggleVisibility(_:)), for: .valueChanged)
        deleteButton.addTarget(self, action: #selector(didTapDelete), for: .touchUpInside)
    }

    // MARK: - Helpers
    private func sectionTitle(_ text: String) -> UILabel {
        let lb = UILabel()
        lb.text = text
        lb.font = .systemFont(ofSize: 15, weight: .semibold)
        lb.textColor = .secondaryLabel
        return lb
    }

    private func makeDivider() -> UIView {
        let v = UIView()
        v.backgroundColor = .systemGray5
        v.snp.makeConstraints { $0.height.equalTo(1) }
        return v
    }

    private func addInfoRow(icon: String, title: String, value: String) {
        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 8

        let iv = UIImageView(image: UIImage(systemName: icon))
        iv.tintColor = .secondaryLabel
        iv.contentMode = .scaleAspectFit
        iv.snp.makeConstraints { $0.width.height.equalTo(18) }

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 15, weight: .regular)
        titleLabel.textColor = .secondaryLabel

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        valueLabel.textColor = .label
        valueLabel.textAlignment = .right

        let spacer = UIView()

        row.addArrangedSubview(iv)
        row.addArrangedSubview(titleLabel)
        row.addArrangedSubview(spacer)
        row.addArrangedSubview(valueLabel)
        infoGrid.addArrangedSubview(row)
    }

    // 공개/비공개 적용: likeRow 숨김 + 카드 상단 제약 토글 + 텍스트/아이콘 변경
    private func applyVisibility(isPublic: Bool, animated: Bool) {
        likeRow.isHidden = !isPublic

        // top 제약 하나만 유지: 공개면 likeRow 아래, 비공개면 divider1 아래
        visibilityCard.snp.remakeConstraints { make in
            if isPublic {
                self.visibilityTopConstraint = make.top.equalTo(self.likeRow.snp.bottom).offset(12).constraint
            } else {
                self.visibilityTopConstraint = make.top.equalTo(self.divider1.snp.bottom).offset(12).constraint
            }
            make.leading.trailing.equalToSuperview().inset(20)
        }

        // 텍스트/아이콘 갱신
        if isPublic {
            visibilityTitle.text = "공개"
            visibilityIcon.image = UIImage(systemName: "lock.open")
            visibilitySubtitle.text = "다른 사용자가 이 사진을 볼 수 있습니다."
        } else {
            visibilityTitle.text = "비공개"
            visibilityIcon.image = UIImage(systemName: "lock.fill")
            visibilitySubtitle.text = "다른 사용자가 이 사진을 볼 수 없습니다."
        }

        let animations = { self.view.layoutIfNeeded() }
        animated ? UIView.animate(withDuration: 0.22, animations: animations) : animations()
    }

    // MARK: - Actions
    @objc private func toggleVisibility(_ sender: UISwitch) {
        model.isPublic = sender.isOn
        applyVisibility(isPublic: sender.isOn, animated: true)
    }

    @objc private func didTapDelete() {
        let ac = UIAlertController(title: "사진 삭제",
                                   message: "정말로 이 사진을 삭제하시겠습니까?",
                                   preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "취소", style: .cancel))
        ac.addAction(UIAlertAction(title: "삭제", style: .destructive, handler: { _ in
            self.dismiss(animated: true) {
                self.onDelete?()
            }
        }))
        present(ac, animated: true)
    }
}
