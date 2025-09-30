//
//  FeedViewController.swift
//  SpaceWalker
//
//  Created by andev on 9/30/25.
//

import UIKit
import SnapKit

struct FeedItem {
    let color: UIColor
    var isLiked: Bool
    let height: CGFloat
}

final class FeedViewController: UIViewController {

    // MARK: - UI
    private let chipStack = UIStackView()
    private let collectionView: UICollectionView

    // MARK: - State
    private var items: [FeedItem] = []

    private let filters = ["전체", "개인", "업무", "공부", "운동"]
    private var selectedFilterIndex = 0

    // MARK: - Init
    init() {
        // Pinterest-like layout (2열)
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 12
        layout.minimumInteritemSpacing = 12
        self.collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)

        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Feed"
        view.backgroundColor = .systemBackground

        setupChips()
        setupCollectionView()
        makeDummyItems()
    }

    // MARK: - Setup
    private func setupChips() {
        view.addSubview(chipStack)
        chipStack.axis = .horizontal
        chipStack.spacing = 8
        chipStack.alignment = .fill
        chipStack.distribution = .fillProportionally

        chipStack.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).inset(12)
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(36)
        }

        filters.enumerated().forEach { idx, title in
            let b = makeChipButton(title: title, selected: idx == selectedFilterIndex)
            b.tag = idx
            b.addTarget(self, action: #selector(chipTapped(_:)), for: .touchUpInside)
            chipStack.addArrangedSubview(b)
        }
    }

    private func setupCollectionView() {
        view.addSubview(collectionView)
        collectionView.backgroundColor = .systemBackground
        collectionView.register(FeedCell.self, forCellWithReuseIdentifier: FeedCell.reuseID)
        collectionView.dataSource = self
        collectionView.delegate = self

        collectionView.snp.makeConstraints { make in
            make.top.equalTo(chipStack.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(12)
            make.bottom.equalTo(view.safeAreaLayoutGuide)
        }
    }

    // MARK: - Data
    private func makeDummyItems() {
        let colors: [UIColor] = [.systemBlue, .systemTeal, .systemGreen, .systemOrange,
                                 .systemPink, .systemPurple, .systemRed, .brown]
        items = [
            FeedItem(color: colors[0], isLiked: false, height: 160),
            FeedItem(color: colors[1], isLiked: false, height: 200),
            FeedItem(color: colors[2], isLiked: false, height: 140),
            FeedItem(color: colors[3], isLiked: false, height: 180),
            FeedItem(color: colors[4], isLiked: false, height: 210),
            FeedItem(color: colors[5], isLiked: false, height: 190),
            FeedItem(color: colors[6], isLiked: false, height: 220),
            FeedItem(color: colors[7], isLiked: false, height: 170),
        ]
        collectionView.reloadData()
    }

    // MARK: - Actions
    @objc private func chipTapped(_ sender: UIButton) {
        selectedFilterIndex = sender.tag
        for case let btn as UIButton in chipStack.arrangedSubviews {
            styleChip(btn, selected: btn.tag == selectedFilterIndex)
        }
        // TODO: 실제 필터링 로직 (지금은 전체 items 그대로)
        collectionView.reloadData()
    }

    private func makeChipButton(title: String, selected: Bool) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        b.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
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
            b.backgroundColor = .systemGray6
            b.setTitleColor(.label, for: .normal)
            b.layer.borderColor = UIColor.systemGray4.cgColor
        }
    }
}

// MARK: - DataSource / FlowLayout
extension FeedViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        items.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: FeedCell.reuseID,
            for: indexPath
        ) as! FeedCell
        let item = items[indexPath.item]
        cell.configure(with: item)

        // 좋아요 탭 콜백
        cell.onLikeTapped = { [weak self, weak cell] in
            guard let self = self else { return }
            self.items[indexPath.item].isLiked.toggle()
            // 해당 아이템만 업데이트
            if let c = cell {
                c.configure(with: self.items[indexPath.item])
            } else {
                self.collectionView.reloadItems(at: [indexPath])
            }
        }
        return cell
    }

    // 2열 워터폴 느낌
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = (collectionView.bounds.width - 12) / 2
        let item = items[indexPath.item]
        return CGSize(width: width, height: item.height)
    }
}
