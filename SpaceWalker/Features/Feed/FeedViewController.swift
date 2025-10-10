//
//  FeedViewController.swift
//  SpaceWalker
//
//  Created by andev on 9/30/25.
//

import UIKit
import SnapKit

struct FeedItem {
    let image: UIImage
    var isLiked: Bool
    var likeCount: Int
    let authorName: String
    let missionTitle: String
}

final class FeedViewController: UIViewController {
    
    let accent = UIColor(named: "AccentColor_066985") ?? .systemBlue

    // MARK: - UI
    private let chipStack = UIStackView()
    private let collectionView: UICollectionView

    // MARK: - State
    private var items: [FeedItem] = []

    private let filters = ["전체", "개인", "업무", "공부", "운동"]
    private var selectedFilterIndex = 0

    // MARK: - Init
    init() {
        // MasonryLayout 사용
        let layout = MasonryLayout()
        layout.numberOfColumns = 2
        layout.columnSpacing = 12
        layout.rowSpacing = 12
        layout.contentInsets = .zero

        self.collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(nibName: nil, bundle: nil)

        layout.delegate = self // 델리게이트 연결
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
        // 다양한 비율의 단색 이미지 만들기
        func colorImage(_ color: UIColor, size: CGSize) -> UIImage {
            let rect = CGRect(origin: .zero, size: size)
            UIGraphicsBeginImageContextWithOptions(rect.size, true, 0)
            color.setFill(); UIRectFill(rect)
            let img = UIGraphicsGetImageFromCurrentImageContext()!
            UIGraphicsEndImageContext()
            return img
        }

        let sizes: [CGSize] = [
            CGSize(width: 300, height: 180),  // 가로형
            CGSize(width: 300, height: 420),  // 세로형
            CGSize(width: 300, height: 300),  // 정방형
            CGSize(width: 300, height: 220),
            CGSize(width: 300, height: 460),
            CGSize(width: 300, height: 260),
            CGSize(width: 300, height: 360),
            CGSize(width: 300, height: 190)
        ]
        let colors: [UIColor] = [.systemBlue, .systemTeal, .systemGreen, .systemOrange,
                                 .systemPink, .systemPurple, .systemRed, .brown]
        let authors = ["김철수", "이영희", "박민수", "최지훈", "김민지", "정다은", "오세훈", "장유나"]
        let missions = ["자연 풍경 감상하기", "업무 공간 정리", "독서 기록", "운동 루틴",
                        "아트 작품", "여행 추억", "요리 레시피", "개발 프로젝트"]

        items = (0..<8).map { i in
            let size = sizes[i % sizes.count]
            let color = colors[i % colors.count]
            return FeedItem(
                image: colorImage(color, size: size),
                isLiked: Bool.random(),
                likeCount: Int.random(in: 20...300),
                authorName: authors[i % authors.count],
                missionTitle: missions[i % missions.count]
            )
        }
        collectionView.reloadData()
    }

    // MARK: - Actions
    @objc private func chipTapped(_ sender: UIButton) {
        selectedFilterIndex = sender.tag
        for case let btn as UIButton in chipStack.arrangedSubviews {
            styleChip(btn, selected: btn.tag == selectedFilterIndex)
        }
        collectionView.reloadData()
        collectionView.collectionViewLayout.invalidateLayout() // 레이아웃 갱신
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
            b.backgroundColor = accent
            b.setTitleColor(.white, for: .normal)
            b.layer.borderColor = accent.cgColor
        } else {
            b.backgroundColor = .systemGray6
            b.setTitleColor(.label, for: .normal)
            b.layer.borderColor = UIColor.systemGray4.cgColor
        }
    }
}

// MARK: - DataSource
extension FeedViewController: UICollectionViewDataSource {
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

        cell.onLikeTapped = { [weak self, weak cell] in
            guard let self = self else { return }
            self.items[indexPath.item].isLiked.toggle()
            if let c = cell {
                c.configure(with: self.items[indexPath.item])
            } else {
                self.collectionView.reloadItems(at: [indexPath])
            }
        }
        cell.onReportTapped = { [weak self] in
            let ac = UIAlertController(title: "신고하기",
                                       message: "이 사진을 신고할까요?",
                                       preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "취소", style: .cancel))
            ac.addAction(UIAlertAction(title: "신고", style: .destructive))
            self?.present(ac, animated: true)
        }
        return cell
    }
}

// MARK: - MasonryLayoutDelegate
extension FeedViewController: MasonryLayoutDelegate {
    func collectionView(_ collectionView: UICollectionView,
                        heightForItemAt indexPath: IndexPath,
                        with width: CGFloat) -> CGFloat {
        // 이미지 비율대로 셀 높이 계산
        let item = items[indexPath.item]
        let size = item.image.size
        guard size.width > 0 else { return width } // fallback
        let aspect = size.height / size.width
        return width * aspect
    }
}

// MARK: - Navigation (상세 push)
extension FeedViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = items[indexPath.item]
        let detail = FeedDetailViewController(model: FeedDetailModel(
            image: item.image,
            likeCount: item.likeCount,
            authorName: item.authorName,
            missionTitle: item.missionTitle
        ))
        navigationController?.pushViewController(detail, animated: true)
    }
}
