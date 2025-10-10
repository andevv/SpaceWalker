//
//  FeedViewController.swift
//  SpaceWalker
//
//  Created by andev on 9/30/25.
//

import UIKit
import SnapKit
import RxSwift
import Kingfisher
import OSLog

struct FeedItem {
    let postId: Int
    let photoURL: URL
    var isLiked: Bool
}

final class FeedViewController: UIViewController {
    
    let accent = UIColor(named: "AccentColor_066985") ?? .systemBlue
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "SpaceWalker", category: "FeedViewController")
    private var feedRequestCount: Int = 0

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
    private let pageSize = 10

    // Track in-flight like requests to prevent duplicate taps per postId
    private var likingPostIds: Set<Int> = []

    // Cache measured image sizes by postId to compute dynamic heights
    private var imageSizeCache: [Int: CGSize] = [:]
    // Only items in this range are allowed to trigger layout changes (latest page)
    private var mutableIndexRange: Range<Int>? = nil

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
        
        // Only load if items are empty to avoid double initial load
        if items.isEmpty { loadFeed(reset: true) }
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

        let requestStart = Date()

        // Determine selected spaceId (0 = 전체)
        let selectedSpaceId: Int? = (selectedChipIndex == 0) ? nil : spaces[selectedChipIndex - 1].id
        let nextPage = reset ? 1 : (currentPage + 1)

        feedRequestCount += 1
        logger.info("[Feed] request #\(self.feedRequestCount) start — spaceId=\(selectedSpaceId?.description ?? "all", privacy: .public), page=\(nextPage), reset=\(reset, privacy: .public)")

        feedRepository.fetchFeed(spaceId: selectedSpaceId, page: nextPage, size: pageSize)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] resp in
                guard let self = self else { return }

                self.currentPage = resp.page
                self.totalPages = resp.totalPages

                // Build a page payload (preserve order)
                let pageTuples: [(postId: Int, url: URL, liked: Bool)] = resp.posts.compactMap { dto in
                    guard let url = URL(string: dto.photoUrl) else { return nil }
                    return (postId: dto.postId, url: url, liked: dto.liked)
                }

                // Prefetch image sizes for this page (sequential or parallel with DispatchGroup)
                let group = DispatchGroup()
                var sizedTuples: [(postId: Int, url: URL, liked: Bool, size: CGSize)] = []
                let syncQueue = DispatchQueue(label: "feed.size.collect")

                for t in pageTuples {
                    group.enter()
                    // Use Kingfisher to retrieve image (will hit cache if available)
                    KingfisherManager.shared.retrieveImage(with: t.url, options: nil, progressBlock: nil) { result in
                        switch result {
                        case .success(let value):
                            let size = value.image.size
                            syncQueue.async {
                                sizedTuples.append((t.postId, t.url, t.liked, size))
                                group.leave()
                            }
                        case .failure:
                            // If failed to load, fallback to a reasonable default size to avoid stalling
                            let fallback = CGSize(width: 3, height: 4) // aspect 3:4 as last resort
                            syncQueue.async {
                                sizedTuples.append((t.postId, t.url, t.liked, fallback))
                                group.leave()
                            }
                        }
                    }
                }

                group.notify(queue: .main) {
                    // Maintain original order by mapping back using pageTuples order
                    let sizeMap = Dictionary(uniqueKeysWithValues: sizedTuples.map { ($0.postId, $0.size) })

                    if reset {
                        self.items.removeAll()
                        self.imageSizeCache.removeAll()
                        self.mutableIndexRange = nil
                    }

                    let startIndex = self.items.count
                    let newItems: [FeedItem] = pageTuples.map { t in
                        if let sz = sizeMap[t.postId] { self.imageSizeCache[t.postId] = sz }
                        return FeedItem(postId: t.postId, photoURL: t.url, isLiked: t.liked)
                    }

                    self.items.append(contentsOf: newItems)
                    self.mutableIndexRange = startIndex..<(startIndex + newItems.count)
                    self.collectionView.reloadData()

                    let elapsed = Date().timeIntervalSince(requestStart)
                    self.logger.info("[Feed] request #\(self.feedRequestCount) success — elapsed=\(elapsed, format: .fixed(precision: 2))s, page=\(self.currentPage), totalPages=\(self.totalPages), added=\(newItems.count), totalItems=\(self.items.count)")

                    self.isLoading = false
                }
            }, onFailure: { [weak self] error in
                let elapsed = Date().timeIntervalSince(requestStart)
                self?.logger.error("[Feed] request #\(self?.feedRequestCount ?? -1) failure — elapsed=\(elapsed, format: .fixed(precision: 2))s, error=\(error.localizedDescription, privacy: .public)")
                self?.isLoading = false
                self?.presentErrorAlert(message: error.localizedDescription)
            })
            .disposed(by: disposeBag)
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
        collectionView.setContentOffset(.zero, animated: false)
        mutableIndexRange = nil
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
        let placeholder = UIImage(systemName: "photo")?.withTintColor(.secondarySystemBackground, renderingMode: .alwaysOriginal)
        cell.configure(url: item.photoURL, liked: item.isLiked, placeholder: placeholder)

        cell.onImageLoaded = { [weak self] size in
            guard let self = self else { return }
            let postId = item.postId
            // Cache size
            if self.imageSizeCache[postId] != size {
                self.imageSizeCache[postId] = size
                // Only allow layout changes for the latest appended range
                if let range = self.mutableIndexRange, range.contains(indexPath.item) {
                    self.collectionView.collectionViewLayout.invalidateLayout()
                }
            }
        }

        cell.onLikeTapped = { [weak self, weak cell] in
            guard let self = self else { return }
            let idx = indexPath.item
            guard idx < self.items.count else { return }
            let postId = self.items[idx].postId

            // Prevent duplicate like requests for the same post
            if self.likingPostIds.contains(postId) { return }
            self.likingPostIds.insert(postId)

            // Optimistic update
            let previous = self.items[idx].isLiked
            self.items[idx].isLiked.toggle()

            // Reflect UI immediately
            if let c = cell {
                let updated = self.items[idx]
                let placeholder = UIImage(systemName: "photo")?.withTintColor(.secondarySystemBackground, renderingMode: .alwaysOriginal)
                c.configure(url: updated.photoURL, liked: updated.isLiked, placeholder: placeholder)
            } else {
                self.collectionView.reloadItems(at: [indexPath])
            }

            // Fire API
            self.feedRepository.updateLike(postId: postId, liked: self.items[idx].isLiked)
                .observe(on: MainScheduler.instance)
                .subscribe(onSuccess: { [weak self] resp in
                    guard let self = self else { return }
                    self.likingPostIds.remove(postId)
                    // Log server JSON response body
                    if let data = try? JSONEncoder().encode(resp),
                       let json = String(data: data, encoding: .utf8) {
                        self.logger.info("[Feed] like response JSON — postId=\(postId), body=\(json, privacy: .public)")
                    } else {
                        self.logger.info("[Feed] like response (unencodable) — postId=\(postId)")
                    }
                    if resp.postId != postId || resp.success == false {
                        // Rollback if server response mismatched
                        self.items[idx].isLiked = previous
                        if let c = cell {
                            let updated = self.items[idx]
                            let placeholder = UIImage(systemName: "photo")?.withTintColor(.secondarySystemBackground, renderingMode: .alwaysOriginal)
                            c.configure(url: updated.photoURL, liked: updated.isLiked, placeholder: placeholder)
                        } else {
                            self.collectionView.reloadItems(at: [indexPath])
                        }
                        self.presentErrorAlert(message: "좋아요 처리에 실패했습니다. 다시 시도해 주세요.")
                    }
                }, onFailure: { [weak self] error in
                    guard let self = self else { return }
                    self.likingPostIds.remove(postId)
                    // Rollback UI
                    self.items[idx].isLiked = previous
                    if let c = cell {
                        let updated = self.items[idx]
                        let placeholder = UIImage(systemName: "photo")?.withTintColor(.secondarySystemBackground, renderingMode: .alwaysOriginal)
                        c.configure(url: updated.photoURL, liked: updated.isLiked, placeholder: placeholder)
                    } else {
                        self.collectionView.reloadItems(at: [indexPath])
                    }
                    self.presentErrorAlert(message: error.localizedDescription)
                })
                .disposed(by: self.disposeBag)
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
        if let size = imageSizeCache[item.postId], size.width > 0 {
            let aspect = size.height / size.width
            return width * aspect
        }
        // Fallback ratio while loading
        return width * (4.0/3.0)
    }
}

// MARK: - Navigation (상세 push)
extension FeedViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = items[indexPath.item]
        let detail = FeedDetailViewController(postId: item.postId)
        navigationController?.pushViewController(detail, animated: true)
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        let threshold = 4
        if indexPath.item >= items.count - threshold, !isLoading, currentPage < totalPages {
            logger.debug("[Feed] willDisplay near end — triggering next page. index=\(indexPath.item), count=\(self.items.count), currentPage=\(self.currentPage), totalPages=\(self.totalPages)")
            loadFeed(reset: false)
        }
    }
}

