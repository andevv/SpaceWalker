//
//  SpaceCell.swift
//  SpaceWalker
//
//  Created by andev on 9/29/25.
//

import UIKit
import SnapKit

final class SpaceCell: UITableViewCell {
    static let reuseID = "SpaceCell"

    private let cardView: UIView = {
        let v = UIView()
        v.backgroundColor = .secondarySystemBackground
        v.layer.cornerRadius = 16
        v.layer.shadowColor = UIColor.black.withAlphaComponent(0.08).cgColor
        v.layer.shadowOpacity = 1
        v.layer.shadowRadius = 8
        v.layer.shadowOffset = CGSize(width: 0, height: 4)
        return v
    }()

    private let titleLabel: UILabel = {
        let lb = UILabel()
        lb.font = .systemFont(ofSize: 18, weight: .semibold)
        lb.textColor = .label
        lb.numberOfLines = 1
        return lb
    }()

    // 체크 아이콘
    private let checkmarkView: UIImageView = {
        let iv = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
        iv.contentMode = .scaleAspectFit
        iv.tintColor = .systemBlue
        iv.isHidden = true // 기본은 숨김
        return iv
    }()

    // 선택 테두리 효과용
    private let selectionBorder: CALayer = {
        let l = CALayer()
        l.borderWidth = 2
        l.borderColor = UIColor.systemBlue.cgColor
        l.cornerRadius = 16
        l.isHidden = true
        return l
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .systemBackground

        contentView.addSubview(cardView)
        cardView.addSubview(titleLabel)
        cardView.addSubview(checkmarkView)

        cardView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16))
            make.height.equalTo(88)
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(20)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(checkmarkView.snp.leading).offset(-12)
        }

        checkmarkView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(22)
        }

        // selectionBorder는 cardView 레이어 위에 추가
        cardView.layer.addSublayer(selectionBorder)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        checkmarkView.isHidden = true
        selectionBorder.isHidden = true
        cardView.backgroundColor = .secondarySystemBackground
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        selectionBorder.frame = cardView.bounds
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(with model: SpaceUIModel, selected: Bool = false) {
        titleLabel.text = model.title
        applySelectionStyle(selected)
    }

    private func applySelectionStyle(_ isSelected: Bool) {
        checkmarkView.isHidden = !isSelected
        selectionBorder.isHidden = !isSelected
        // 선택 시 살짝 배경 강조
        cardView.backgroundColor = isSelected ? UIColor.systemBlue.withAlphaComponent(0.08) : .secondarySystemBackground
    }
}
