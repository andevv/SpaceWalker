//
//  FeedCell.swift
//  SpaceWalker
//
//  Created by andev on 9/30/25.
//

import UIKit
import SnapKit

final class FeedCell: UICollectionViewCell {
    static let reuseID = "FeedCell"

    // MARK: - UI
    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 12
        return iv
    }()

    // 좋아요 버튼 배경 (가독성/터치 영역 확보용)
    private let likeBackdrop: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.black.withAlphaComponent(0.25)
        v.layer.cornerRadius = 16
        v.isUserInteractionEnabled = false
        return v
    }()

    // 하트 버튼 (우측 하단)
    let likeButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6)
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        let btn = UIButton(configuration: config)
        btn.accessibilityLabel = "좋아요"
        return btn
    }()

    // 옵션 버튼(우측 상단 •••)
    private let optionsButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6)
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        let btn = UIButton(configuration: config)
        btn.setImage(UIImage(systemName: "ellipsis"), for: .normal)
        btn.tintColor = .white
        btn.accessibilityLabel = "옵션"
        btn.showsMenuAsPrimaryAction = true // 탭 시 메뉴 바로 표시
        return btn
    }()

    // 외부 이벤트 콜백
    var onLikeTapped: (() -> Void)?
    var onReportTapped: (() -> Void)?   // 신고하기 선택 시 콜백

    // MARK: - Init
    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.addSubview(imageView)
        contentView.addSubview(likeBackdrop)
        contentView.addSubview(likeButton)
        contentView.addSubview(optionsButton)

        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        // 좋아요 버튼 탭
        likeButton.addTarget(self, action: #selector(didTapLike), for: .touchUpInside)

        // 레이아웃: 옵션 버튼(우상단), 좋아요 버튼(우하단)
        optionsButton.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(8)
            make.trailing.equalToSuperview().inset(8)
            make.width.height.equalTo(32)
        }

        likeButton.snp.makeConstraints { make in
            make.bottom.equalToSuperview().inset(8)
            make.trailing.equalToSuperview().inset(8)
            make.width.height.equalTo(32)
        }

        likeBackdrop.snp.makeConstraints { make in
            make.center.equalTo(likeButton)
            make.width.height.equalTo(32)
        }

        // 옵션 버튼 메뉴 구성
        configureOptionsMenu()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        setLiked(false) // 기본 상태
    }

    // MARK: - Configure
    func configure(with item: FeedItem) {
        imageView.image = makeColorImage(color: item.color, size: CGSize(width: 200, height: Int(item.height)))
        setLiked(item.isLiked)
    }

    private func setLiked(_ liked: Bool) {
        let name = liked ? "heart.fill" : "heart"
        likeButton.setImage(UIImage(systemName: name), for: .normal)
        // 상태별 색상: false → 흰색, true → 빨간색
        likeButton.tintColor = liked ? .systemRed : .white

        likeBackdrop.isHidden = false
        likeBackdrop.alpha = liked ? 0.35 : 0.25

        // 약간의 팝 효과(선택적)
        if liked {
            UIView.animate(withDuration: 0.12, animations: {
                self.likeButton.transform = CGAffineTransform(scaleX: 1.15, y: 1.15)
            }, completion: { _ in
                UIView.animate(withDuration: 0.12) {
                    self.likeButton.transform = .identity
                }
            })
        }
    }

    // MARK: - Menu
    private func configureOptionsMenu() {
        let report = UIAction(title: "신고하기",
                              image: UIImage(systemName: "exclamationmark.triangle")) { [weak self] _ in
            self?.onReportTapped?()
        }
        optionsButton.menu = UIMenu(children: [report])
    }

    // MARK: - Actions
    @objc private func didTapLike() {
        onLikeTapped?()
    }

    // 단색 placeholder
    private func makeColorImage(color: UIColor, size: CGSize) -> UIImage {
        let rect = CGRect(origin: .zero, size: size)
        UIGraphicsBeginImageContextWithOptions(rect.size, true, 0)
        color.setFill(); UIRectFill(rect)
        let img = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return img
    }
}
