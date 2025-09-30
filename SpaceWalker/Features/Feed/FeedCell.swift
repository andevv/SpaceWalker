//
//  FeedCell.swift
//  SpaceWalker
//
//  Created by andev on 9/30/25.
//

import UIKit
import SnapKit

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

    // 살짝 보이는 어두운 배경(가독성/터치 영역 확보용)
    private let likeBackdrop: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.black.withAlphaComponent(0.25)
        v.layer.cornerRadius = 16
        v.isUserInteractionEnabled = false
        return v
    }()

    let likeButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.imagePlacement = .all
        let btn = UIButton(configuration: config)
        btn.tintColor = .white
        btn.contentEdgeInsets = UIEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
        btn.accessibilityLabel = "좋아요"
        return btn
    }()

    // 외부에 이벤트 전달
    var onLikeTapped: (() -> Void)?

    // MARK: - Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(imageView)
        contentView.addSubview(likeBackdrop)
        contentView.addSubview(likeButton)

        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        likeButton.addTarget(self, action: #selector(didTapLike), for: .touchUpInside)

        // 우상단 배치
        likeButton.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(8)
            make.trailing.equalToSuperview().inset(8)
            make.width.height.equalTo(32)
        }
        likeBackdrop.snp.makeConstraints { make in
            make.center.equalTo(likeButton)
            make.width.height.equalTo(32)
        }
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
        likeBackdrop.isHidden = false // 항상 살짝 보이게
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
