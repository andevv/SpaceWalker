//
//  FeedCell.swift
//  SpaceWalker
//
//  Created by andev on 9/30/25.
//

import UIKit
import SnapKit
import Kingfisher

final class FeedCell: UICollectionViewCell {
    static let reuseID = "FeedCell"

    // Notifies controller when the remote image finishes loading (for layout updates)
    var onImageLoaded: ((CGSize) -> Void)?

    // MARK: - UI
    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 12
        return iv
    }()

    private let likeBackdrop: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.black.withAlphaComponent(0.25)
        v.layer.cornerRadius = 16
        v.isUserInteractionEnabled = false
        return v
    }()

    let likeButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6)
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        let btn = UIButton(configuration: config)
        btn.accessibilityLabel = "좋아요"
        return btn
    }()

    // 옵션(…) 버튼 + 메뉴
    private let optionsButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.contentInsets = .zero
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 18, weight: .regular)
        let btn = UIButton(configuration: config)
        btn.setImage(UIImage(systemName: "ellipsis"), for: .normal)
        btn.tintColor = .white
        btn.accessibilityLabel = "옵션"
        btn.showsMenuAsPrimaryAction = true // 탭 시 메뉴 표시
        return btn
    }()

    // MARK: - Callbacks
    var onLikeTapped: (() -> Void)?
    var onReportTapped: (() -> Void)?

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

        likeButton.addTarget(self, action: #selector(didTapLike), for: .touchUpInside)

        // 레이아웃: 옵션(우상단), 좋아요(우하단)
        optionsButton.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(8)
            make.trailing.equalToSuperview().inset(8)
            make.width.height.equalTo(28)
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

        configureOptionsMenu()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func prepareForReuse() {
        super.prepareForReuse()
        // Cancel any ongoing image download and clear image
        imageView.kf.cancelDownloadTask()
        imageView.image = nil
        // Reset like state
        setLiked(false)
        // Clear callbacks to avoid calling stale closures after reuse
        onLikeTapped = nil
        onReportTapped = nil
        onImageLoaded = nil
    }

    /// Configure cell with remote image URL using Kingfisher
    func configure(url: URL, liked: Bool, placeholder: UIImage? = nil) {
        imageView.kf.cancelDownloadTask()
        imageView.kf.setImage(with: url, placeholder: placeholder, options: nil) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let value):
                self.onImageLoaded?(value.image.size)
            case .failure:
                break
            }
        }
        setLiked(liked)
    }

    private func setLiked(_ liked: Bool) {
        let name = liked ? "heart.fill" : "heart"
        likeButton.setImage(UIImage(systemName: name), for: .normal)
        likeButton.tintColor = liked ? .systemRed : .white

        likeBackdrop.isHidden = false
        likeBackdrop.alpha = liked ? 0.35 : 0.25

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
}

