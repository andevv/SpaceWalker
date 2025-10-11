//
//  FeedDetailViewController.swift
//  SpaceWalker
//
//  Created by andev on 10/3/25.
//

import UIKit
import SnapKit
import RxSwift
import Kingfisher

struct FeedDetailModel {
    var image: UIImage?
    var imageURL: URL?
    var likeCount: Int
    var liked: Bool
    var authorName: String
    var missionTitle: String
    var authorProfileURL: URL?

    init(image: UIImage?, likeCount: Int, liked: Bool, authorName: String, missionTitle: String, imageURL: URL? = nil, authorProfileURL: URL? = nil) {
        self.image = image
        self.likeCount = likeCount
        self.liked = liked
        self.authorName = authorName
        self.missionTitle = missionTitle
        self.imageURL = imageURL
        self.authorProfileURL = authorProfileURL
    }
}

final class FeedDetailViewController: UIViewController {

    // MARK: - Dependencies
    private var model: FeedDetailModel
    private var apiPostId: Int64?
    private let feedRepository = FeedRepository()
    private let disposeBag = DisposeBag()

    // MARK: - UI
    private let scrollView = UIScrollView()
    private let contentView = UIView()

    private let imageView = UIImageView()

    private let likeRow = UIStackView()
    private let likeIcon = UIImageView(image: UIImage(systemName: "heart.fill"))
    private let likeLabel = UILabel()
    private let divider1 = UIView()

    private let shooterTitle = UILabel()
    private let shooterRow = UIStackView()
    private let shooterIcon = UIImageView(image: UIImage(systemName: "person.circle.fill"))
    private let shooterName = UILabel()
    private let divider2 = UIView()

    private let missionCaption = UILabel()
    private let missionTitleLabel = UILabel()

    // MARK: - Init
    init(model: FeedDetailModel) {
        self.model = model
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 16
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    convenience init(postId: Int) {
        let placeholder = FeedDetailModel(image: nil, likeCount: 0, liked: false, authorName: "", missionTitle: "")
        self.init(model: placeholder)
        self.apiPostId = Int64(postId)
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
        if let postId = apiPostId {
            fetchFeedDetail(postId: Int(postId))
        } else {
            bindData()
        }
    }

    // MARK: - Setup
    private func setupUI() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalTo(scrollView.snp.width)
        }

        // 이미지
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        contentView.addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(imageView.snp.width).multipliedBy(4.0/3.0)
        }

        // 좋아요
        likeRow.axis = .horizontal
        likeRow.spacing = 8
        likeRow.alignment = .center

        // 하트 아이콘 찌그러짐 방지
        likeIcon.tintColor = .secondaryLabel
        likeIcon.contentMode = .scaleAspectFit
        likeIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        likeIcon.setContentHuggingPriority(.required, for: .horizontal)
        likeIcon.setContentCompressionResistancePriority(.required, for: .horizontal)

        contentView.addSubview(likeRow)
        [likeIcon, likeLabel].forEach { likeRow.addArrangedSubview($0) }
        likeRow.snp.makeConstraints { make in
            make.top.equalTo(imageView.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(20)
        }
        // 정사각 사이즈 고정
        likeIcon.snp.makeConstraints { make in
            make.width.height.equalTo(18)
        }

        likeLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        likeLabel.textColor = .label

        divider1.backgroundColor = .systemGray5
        contentView.addSubview(divider1)
        divider1.snp.makeConstraints { make in
            make.top.equalTo(likeRow.snp.bottom).offset(14)
            make.leading.trailing.equalToSuperview().inset(20)
            make.height.equalTo(1)
        }

        // 촬영자
        shooterTitle.text = "촬영자"
        shooterTitle.font = .systemFont(ofSize: 15, weight: .semibold)
        shooterTitle.textColor = .secondaryLabel
        contentView.addSubview(shooterTitle)
        shooterTitle.snp.makeConstraints { make in
            make.top.equalTo(divider1.snp.bottom).offset(14)
            make.leading.trailing.equalToSuperview().inset(20)
        }

        shooterRow.axis = .horizontal
        shooterRow.spacing = 10

        shooterIcon.layer.cornerRadius = 12
        shooterIcon.clipsToBounds = true
        shooterIcon.backgroundColor = .systemGray5
        shooterIcon.contentMode = .scaleAspectFill
        shooterIcon.snp.makeConstraints { $0.width.height.equalTo(24) }

        shooterName.font = .systemFont(ofSize: 16, weight: .semibold)

        contentView.addSubview(shooterRow)
        [shooterIcon, shooterName].forEach { shooterRow.addArrangedSubview($0) }
        shooterRow.snp.makeConstraints { make in
            make.top.equalTo(shooterTitle.snp.bottom).offset(10)
            make.leading.trailing.equalToSuperview().inset(20)
        }

        divider2.backgroundColor = .systemGray5
        contentView.addSubview(divider2)
        divider2.snp.makeConstraints { make in
            make.top.equalTo(shooterRow.snp.bottom).offset(14)
            make.leading.trailing.equalToSuperview().inset(20)
            make.height.equalTo(1)
        }

        // 미션
        missionCaption.text = "수행한 미션"
        missionCaption.font = .systemFont(ofSize: 14, weight: .regular)
        missionCaption.textColor = .secondaryLabel

        missionTitleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        missionTitleLabel.numberOfLines = 0

        contentView.addSubview(missionCaption)
        contentView.addSubview(missionTitleLabel)
        missionCaption.snp.makeConstraints { make in
            make.top.equalTo(divider2.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(20)
        }
        missionTitleLabel.snp.makeConstraints { make in
            make.top.equalTo(missionCaption.snp.bottom).offset(6)
            make.leading.trailing.equalToSuperview().inset(20)
            make.bottom.equalToSuperview().inset(24) // scroll 마지막
        }
    }

    private func updateLikeAppearance(liked: Bool) {
        if liked {
            likeIcon.image = UIImage(systemName: "heart.fill")
            likeIcon.tintColor = .systemRed
        } else {
            likeIcon.image = UIImage(systemName: "heart")
            likeIcon.tintColor = .secondaryLabel
        }
    }

    private func bindData() {
        imageView.image = model.image
        likeLabel.text = "\(model.likeCount)개의 좋아요"
        shooterName.text = model.authorName
        
        if let url = model.authorProfileURL {
            let placeholder = UIImage(systemName: "person.circle")?.withRenderingMode(.alwaysTemplate)
            shooterIcon.tintColor = .systemGray3
            shooterIcon.kf.setImage(with: url, placeholder: placeholder)
        } else {
            shooterIcon.image = UIImage(systemName: "person.circle.fill")
            shooterIcon.tintColor = .systemBlue
        }
        
        missionTitleLabel.text = model.missionTitle
        updateLikeAppearance(liked: model.liked)

        // Load image from URL if needed
        if model.image == nil, let url = model.imageURL {
            loadImage(from: url)
        }
    }

    private func fetchFeedDetail(postId: Int) {
        feedRepository.fetchFeedDetail(postId: postId)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] dto in
                guard let self = self else { return }
                let imageURL = URL(string: dto.photoUrl)
                let updated = FeedDetailModel(
                    image: nil,
                    likeCount: dto.likeCount,
                    liked: dto.liked,
                    authorName: dto.author.nickname,
                    missionTitle: dto.dailyMission.title,
                    imageURL: imageURL,
                    authorProfileURL: dto.author.profileImageUrl.flatMap(URL.init(string:))
                )
                self.model = updated
                self.bindData()
            }, onFailure: { [weak self] error in
                print("[FeedDetail] fetch error: \(error)")
                self?.bindData()
            })
            .disposed(by: disposeBag)
    }

    private func loadImage(from url: URL) {
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.model.image = image
                    self.imageView.image = image
                }
            }
        }
        task.resume()
    }
}

