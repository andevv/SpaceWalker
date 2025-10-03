//
//  FeedViewController.swift
//  SpaceWalker
//
//  Created by andev on 9/30/25.
//

//  FeedViewController.swift
//  SpaceWalker

import UIKit
import SnapKit

struct FeedItem {
    let image: UIImage
    var isLiked: Bool
    let height: CGFloat
    var likeCount: Int
    let authorName: String
    let missionTitle: String
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
        // 2열 레이아웃
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
        // 단색 이미지 생성 유틸
        func colorImage(_ color: UIColor, size: CGSize) -> UIImage {
            let rect = CGRect(origin: .zero, size: size)
            UIGraphicsBeginImageContextWithOptions(rect.size, true, 0)
            color.setFill(); UIRectFill(rect)
            let img = UIGraphicsGetImageFromCurrentImageContext()!
            UIGraphicsEndImageContext()
            return img
        }

        let colors: [UIColor] = [.systemBlue, .systemTeal, .systemGreen, .systemOrange,
                                 .systemPink, .systemPurple, .systemRed, .brown]

        let heights: [CGFloat] = [160, 200, 140, 180, 210, 190, 220, 170]
        let authors = ["김철수", "이영희", "박민수", "최지훈", "김민지", "정다은", "오세훈", "장유나"]
        let missions = ["자연 풍경 감상하기", "업무 공간 정리", "독서 기록", "운동 루틴",
                        "아트 작품", "여행 추억", "요리 레시피", "개발 프로젝트"]

        items = (0..<8).map { i in
            let color = colors[i % colors.count]
            let h = heights[i % heights.count]
            return FeedItem(
                image: colorImage(color, size: CGSize(width: 200, height: Int(h))),
                isLiked: Bool.random(),
                height: h,
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
        // TODO: 실제 필터링
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

        // 좋아요 토글
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
            ac.addAction(UIAlertAction(title: "신고", style: .destructive, handler: { _ in
                // TODO: 신고 API 호출
            }))
            self?.present(ac, animated: true)
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

// MARK: - UICollectionViewDelegate (상세 진입)
extension FeedViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = items[indexPath.item]

        let detail = FeedDetailViewController(model: FeedDetailModel(
            image: item.image,
            likeCount: item.likeCount,
            authorName: item.authorName,
            missionTitle: item.missionTitle
        ))

        navigationController?.pushViewController(detail, animated: true)    }
}
