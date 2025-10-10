//
//  FeedViewController.swift
//  SpaceWalker
//
//  Created by andev on 9/30/25.
//

import UIKit
import SnapKit
import RxSwift

struct FeedItem {
    let postId: Int
    let photoURL: URL
    var image: UIImage?
    var isLiked: Bool
}

final class FeedViewController: UIViewController {
    
    let accent = UIColor(named: "AccentColor_066985") ?? .systemBlue

    // MARK: - UI
    private let chipStack = UIStackView()
    private let chipScrollView = UIScrollView()
    private let collectionView: UICollectionView

    // MARK: - State
    private var items: [FeedItem] = []
    private var spaces: [Space] = []
    private var selectedChipIndex = 0 // 0 = 전체, 1... = spaces indices offset by +1
    
    private let repository = SpaceRepository()
    private let feedRepository = FeedRepository()
    private let disposeBag = DisposeBag()
    
    private var currentPage = 1
    private var totalPages = 1
    private var isLoading = false
    private let pageSize = 20

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
        fetchSpaces()
    }

    // MARK: - Setup
    private func setupChips() {
        // Configure scroll view for horizontal chips
        view.addSubview(chipScrollView)
        chipScrollView.showsHorizontalScrollIndicator = false
        chipScrollView.alwaysBounceHorizontal = true
        chipScrollView.alwaysBounceVertical = false

        // Add stack into scroll view
        chipScrollView.addSubview(chipStack)
        chipStack.axis = .horizontal
        chipStack.spacing = 8
        chipStack.alignment = .fill
        chipStack.distribution = .fill // let buttons size to content

        // Layout scrollView
        chipScrollView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).inset(12)
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(36)
        }

        // Layout stack inside scrollView using contentLayoutGuide/frameLayoutGuide for horizontal scrolling
        chipStack.snp.makeConstraints { make in
            make.edges.equalTo(chipScrollView.contentLayoutGuide).inset(0)
            make.height.equalTo(chipScrollView.frameLayoutGuide)
        }

        // Initial build (if spaces already loaded)
        reloadChips()
    }

    private func setupCollectionView() {
        view.addSubview(collectionView)
        collectionView.backgroundColor = .systemBackground
        collectionView.register(FeedCell.self, forCellWithReuseIdentifier: FeedCell.reuseID)
        collectionView.dataSource = self
        collectionView.delegate = self

        collectionView.snp.makeConstraints { make in
            make.top.equalTo(chipScrollView.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(12)
            make.bottom.equalTo(view.safeAreaLayoutGuide)
        }
    }

    private func reloadChips() {
        // Remove existing arranged subviews
        for sub in chipStack.arrangedSubviews { chipStack.removeArrangedSubview(sub); sub.removeFromSuperview() }

        // Build "전체" chip first
        let allButton = makeChipButton(title: "전체", selected: selectedChipIndex == 0)
        allButton.tag = 0
        allButton.addTarget(self, action: #selector(chipTapped(_:)), for: .touchUpInside)
        chipStack.addArrangedSubview(allButton)

        // Build chips for spaces
        for (idx, space) in spaces.enumerated() {
            let tag = idx + 1 // offset by 1 due to "전체"
            let b = makeChipButton(title: space.name, selected: selectedChipIndex == tag)
            b.tag = tag
            b.addTarget(self, action: #selector(chipTapped(_:)), for: .touchUpInside)
            chipStack.addArrangedSubview(b)
        }
        
        // Reload feed when chips are (re)built to reflect current selection
        loadFeed(reset: true)
    }

    // MARK: - Networking (Spaces)
    private func fetchSpaces() {
        repository.fetchSpaces()
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] spaces in
                guard let self = self else { return }
                self.spaces = spaces
                // Max selectable index is spaces.count (0 is "전체")
                self.selectedChipIndex = min(self.selectedChipIndex, self.spaces.count)
                self.reloadChips()
            }, onFailure: { [weak self] error in
                self?.presentErrorAlert(message: error.localizedDescription)
            })
            .disposed(by: disposeBag)
    }

    private func presentErrorAlert(message: String) {
        let ac = UIAlertController(title: "오류", message: message, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "확인", style: .default))
        present(ac, animated: true)
    }

    // MARK: - Networking (Feed)
    private func loadFeed(reset: Bool) {
        if isLoading { return }
        isLoading = true

        // Determine selected spaceId (0 = 전체)
        let selectedSpaceId: Int? = (selectedChipIndex == 0) ? nil : spaces[selectedChipIndex - 1].id
        let nextPage = reset ? 1 : (currentPage + 1)

        feedRepository.fetchFeed(spaceId: selectedSpaceId, page: nextPage, size: pageSize)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] resp in
                guard let self = self else { return }

                self.currentPage = resp.page
                self.totalPages = resp.totalPages

                if reset { self.items.removeAll() }

                let newItems: [FeedItem] = resp.posts.compactMap { dto in
                    guard let url = URL(string: dto.photoUrl) else { return nil }
                    return FeedItem(postId: dto.postId, photoURL: url, image: nil, isLiked: dto.liked)
                }
                self.items.append(contentsOf: newItems)
                self.collectionView.reloadData()

                // Prefetch images for newly added items
                self.prefetchImages(for: newItems, startingAt: self.items.count - newItems.count)

                self.isLoading = false
            }, onFailure: { [weak self] error in
                self?.isLoading = false
                self?.presentErrorAlert(message: error.localizedDescription)
            })
            .disposed(by: disposeBag)
    }

    private func prefetchImages(for items: [FeedItem], startingAt startIndex: Int) {
        let indices = (0..<items.count).map { startIndex + $0 }
        for i in indices {
            guard self.items.indices.contains(i) else { continue }
            if self.items[i].image != nil { continue }
            let url = self.items[i].photoURL
            URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
                guard let self = self else { return }
                if let data, let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        if self.items.indices.contains(i) {
                            self.items[i].image = image
                            // Reload just that item and invalidate layout to reflect correct aspect ratio
                            self.collectionView.reloadItems(at: [IndexPath(item: i, section: 0)])
                            self.collectionView.collectionViewLayout.invalidateLayout()
                        }
                    }
                }
            }.resume()
        }
    }

    // MARK: - Actions
    @objc private func chipTapped(_ sender: UIButton) {
        selectedChipIndex = sender.tag
        for case let btn as UIButton in chipStack.arrangedSubviews {
            styleChip(btn, selected: btn.tag == selectedChipIndex)
        }
        // Reset and load first page for the selected filter
        currentPage = 0
        totalPages = 1
        loadFeed(reset: true)
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
        if let image = item.image {
            cell.configure(with: FeedItem(postId: item.postId, photoURL: item.photoURL, image: image, isLiked: item.isLiked))
        } else {
            // lightweight placeholder while loading
            let placeholder = UIImage(systemName: "photo")!.withTintColor(.secondarySystemBackground, renderingMode: .alwaysOriginal)
            cell.configure(with: FeedItem(postId: item.postId, photoURL: item.photoURL, image: placeholder, isLiked: item.isLiked))
            // If near the end or image missing, ensure prefetch is active
            prefetchImages(for: [item], startingAt: indexPath.item)
        }

        cell.onLikeTapped = { [weak self, weak cell] in
            guard let self = self else { return }
            self.items[indexPath.item].isLiked.toggle()
            if let c = cell {
                let updated = self.items[indexPath.item]
                c.configure(with: FeedItem(postId: updated.postId, photoURL: updated.photoURL, image: updated.image, isLiked: updated.isLiked))
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
        let item = items[indexPath.item]
        if let img = item.image {
            let size = img.size
            guard size.width > 0 else { return width * (4.0/3.0) }
            let aspect = size.height / size.width
            return width * aspect
        } else {
            // Placeholder ratio until image loads
            return width * (4.0/3.0)
        }
    }
}

// MARK: - Navigation (상세 push)
extension FeedViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = items[indexPath.item]
        let detail = FeedDetailViewController(model: FeedDetailModel(
            image: item.image ?? UIImage(),
            likeCount: 0,
            authorName: "",
            missionTitle: ""
        ))
        navigationController?.pushViewController(detail, animated: true)
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offsetY = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        let height = scrollView.bounds.size.height
        // Trigger when user scrolls near bottom and there are more pages
        if offsetY > contentHeight - height * 1.5, !isLoading, currentPage < totalPages {
            loadFeed(reset: false)
        }
    }
}
