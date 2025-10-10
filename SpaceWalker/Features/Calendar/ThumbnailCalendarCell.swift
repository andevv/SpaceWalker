//
//  ThumbnailCalendarCell.swift
//  SpaceWalker
//
//  Created by andev on 9/30/25.
//

import UIKit
import FSCalendar
import SnapKit

final class ThumbnailCalendarCell: FSCalendarCell {
    static let reuseID = "ThumbnailCalendarCell"

    private let thumbView: UIImageView = {
        let iv = UIImageView()
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 14
        iv.contentMode = .scaleAspectFill
        iv.backgroundColor = UIColor.secondarySystemFill
        return iv
    }()

    private let dayBadge: UILabel = {
        let lb = UILabel()
        lb.textAlignment = .center
        lb.font = .systemFont(ofSize: 12, weight: .semibold)
        lb.textColor = .label
        lb.backgroundColor = .systemBackground
        lb.layer.cornerRadius = 12
        lb.clipsToBounds = true
        lb.layer.borderWidth = 0.5
        lb.layer.borderColor = UIColor.systemGray4.cgColor
        return lb
    }()

    private let selectedRing: UIView = {
        let v = UIView()
        v.isUserInteractionEnabled = false
        v.layer.borderWidth = 2
        v.layer.borderColor = UIColor.systemBlue.cgColor
        v.layer.cornerRadius = 12
        v.isHidden = true
        return v
    }()

    override init!(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(thumbView)
        contentView.addSubview(dayBadge)
        contentView.addSubview(selectedRing)

        thumbView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().inset(4)
            make.width.height.equalTo(38)
        }
        dayBadge.snp.makeConstraints { make in
            make.center.equalTo(thumbView.snp.center)
            make.width.height.equalTo(24)
        }
        selectedRing.snp.makeConstraints { make in
            make.center.equalTo(thumbView.snp.center)
            make.width.height.equalTo(44)
        }
    }

    required init!(coder aDecoder: NSCoder!) { fatalError("init(coder:) has not been implemented") }

    override func prepareForReuse() {
        super.prepareForReuse()
        // 내부 도형 감추기
        self.shapeLayer.isHidden = true
        // 일부 버전에선 backgroundLayer가 있을 수 있음
        self.backgroundView?.isHidden = true

        thumbView.image = nil
        thumbView.backgroundColor = UIColor.secondarySystemFill
        dayBadge.text = nil
        dayBadge.backgroundColor = .systemBackground
        dayBadge.textColor = .label
        dayBadge.layer.borderColor = UIColor.systemGray4.cgColor
        selectedRing.isHidden = true
        setDimmed(false)
    }

    func configure(day: Int, image: UIImage?, selected: Bool, dimmed: Bool, date: Date? = nil) {
        // 내부 도형 감추기 (안전하게 한 번 더)
        self.shapeLayer.isHidden = true

        dayBadge.text = "\(day)"
        if let image = image {
            thumbView.image = image
            thumbView.backgroundColor = .clear
        } else {
            thumbView.image = nil
            thumbView.backgroundColor = UIColor.secondarySystemFill
        }
        selectedRing.isHidden = !selected
        setDimmed(dimmed)

        // Today badge styling – highlight only when the exact date is today
        let isToday: Bool = {
            if let date = date {
                return Calendar.current.isDateInToday(date)
            } else {
                return false // Require exact date; do not infer by day number
            }
        }()

        if isToday {
            dayBadge.backgroundColor = .systemBlue
            dayBadge.textColor = .white
            dayBadge.layer.borderColor = UIColor.clear.cgColor
        } else {
            dayBadge.backgroundColor = .systemBackground
            dayBadge.textColor = .label
            dayBadge.layer.borderColor = UIColor.systemGray4.cgColor
        }
    }

    private func setDimmed(_ dimmed: Bool) {
        let alpha: CGFloat = dimmed ? 0.35 : 1.0
        dayBadge.alpha = alpha
        thumbView.alpha = alpha
    }
}

