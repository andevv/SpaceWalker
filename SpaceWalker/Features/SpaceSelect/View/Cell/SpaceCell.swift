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
        v.layer.borderWidth = 1
        v.layer.borderColor = UIColor.systemGray4.cgColor
        return v
    }()

    private let titleLabel: UILabel = {
        let lb = UILabel()
        lb.font = .systemFont(ofSize: 17, weight: .semibold)
        lb.textColor = .label
        return lb
    }()

    private let checkmarkView: UIImageView = {
        let iv = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
        iv.tintColor = .systemBlue
        iv.isHidden = true
        return iv
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
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 8, left: 20, bottom: 8, right: 20))
            make.height.equalTo(64)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
        }
        checkmarkView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(20)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {}
    override func setSelected(_ selected: Bool, animated: Bool) {}

    override func prepareForReuse() {
        super.prepareForReuse()
        checkmarkView.isHidden = true
        cardView.layer.borderColor = UIColor.systemGray4.cgColor
        cardView.backgroundColor = .secondarySystemBackground
    }

    func configure(with model: SpaceUIModel, selected: Bool = false) {
        titleLabel.text = model.title
        applySelectionStyle(selected)
    }

    private func applySelectionStyle(_ isSelected: Bool) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        checkmarkView.isHidden = !isSelected
        cardView.layer.borderColor = isSelected ? UIColor.systemBlue.cgColor : UIColor.systemGray4.cgColor
        CATransaction.commit()

        UIView.performWithoutAnimation {
            cardView.backgroundColor = isSelected
            ? UIColor.systemBlue.withAlphaComponent(0.07)
            : .secondarySystemBackground
            cardView.layoutIfNeeded()
        }
    }
}
