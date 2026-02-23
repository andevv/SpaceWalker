//
//  FeedViewModel.swift
//  SpaceWalker
//
//  Created by andev on 2/23/26.
//

import Foundation
import RxSwift
import RxCocoa
import Kingfisher
import OSLog
import UIKit

final class FeedViewModel {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "SpaceWalker", category: "FeedViewModel")
    private var feedRequestCount: Int = 0

    private let spaceRepository = SpaceRepository()
    private let feedRepository = FeedRepository()
    private let disposeBag = DisposeBag()

    private(set) var items: [FeedItem] = []
    private(set) var spaces: [Space] = []
    private(set) var selectedChipIndex: Int = 0 // 0 = 전체, 1... = spaces indices offset by +1

    private(set) var currentPage = 1
    private(set) var totalPages = 1
    private(set) var isLoading = false
    let pageSize = 10

    private var likingPostIds: Set<Int> = []

    private(set) var imageSizeCache: [Int: CGSize] = [:]
    private var mutableIndexRange: Range<Int>? = nil

    // Outputs
    let chipsUpdated = PublishRelay<Void>()
    let feedUpdated = PublishRelay<Void>()
    let errorMessage = PublishRelay<String>()
    let reportSuccess = PublishRelay<Void>()

    func loadInitial() {
        fetchSpaces()
    }

    func numberOfItems() -> Int {
        items.count
    }

    func item(at indexPath: IndexPath) -> FeedItem? {
        guard indexPath.item < items.count else { return nil }
        return items[indexPath.item]
    }

    func heightForItem(at indexPath: IndexPath, width: CGFloat) -> CGFloat {
        guard indexPath.item < items.count else { return width * (4.0 / 3.0) }
        let item = items[indexPath.item]
        if let size = imageSizeCache[item.postId], size.width > 0 {
            return width * (size.height / size.width)
        }
        return width * (4.0 / 3.0)
    }

    func shouldLoadNextPage(for indexPath: IndexPath, threshold: Int = 4) -> Bool {
        indexPath.item >= items.count - threshold && !isLoading && currentPage < totalPages
    }

    func selectChip(index: Int) {
        selectedChipIndex = index
        currentPage = 0
        totalPages = 1
        mutableIndexRange = nil
        loadFeed(reset: true)
    }

    func loadNextPage() {
        loadFeed(reset: false)
    }

    func updateMeasuredSize(_ size: CGSize, at indexPath: IndexPath) -> Bool {
        guard indexPath.item < items.count else { return false }
        let postId = items[indexPath.item].postId
        if imageSizeCache[postId] != size {
            imageSizeCache[postId] = size
            if let range = mutableIndexRange, range.contains(indexPath.item) {
                return true
            }
        }
        return false
    }

    func toggleLike(at indexPath: IndexPath, onStateChange: @escaping (FeedItem) -> Void) {
        let idx = indexPath.item
        guard idx < items.count else { return }

        let postId = items[idx].postId
        if likingPostIds.contains(postId) { return }
        likingPostIds.insert(postId)

        let previous = items[idx].isLiked
        items[idx].isLiked.toggle()
        onStateChange(items[idx])

        feedRepository.updateLike(postId: postId, liked: items[idx].isLiked)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] resp in
                guard let self else { return }
                self.likingPostIds.remove(postId)

                if let data = try? JSONEncoder().encode(resp),
                   let json = String(data: data, encoding: .utf8) {
                    self.logger.info("[Feed] like response JSON — postId=\(postId), body=\(json, privacy: .public)")
                } else {
                    self.logger.info("[Feed] like response (unencodable) — postId=\(postId)")
                }

                if resp.postId != postId || resp.success == false {
                    self.items[idx].isLiked = previous
                    onStateChange(self.items[idx])
                    self.errorMessage.accept("좋아요 처리에 실패했습니다. 다시 시도해 주세요.")
                }
            }, onFailure: { [weak self] error in
                guard let self else { return }
                self.likingPostIds.remove(postId)
                self.items[idx].isLiked = previous
                onStateChange(self.items[idx])
                self.errorMessage.accept(error.localizedDescription)
            })
            .disposed(by: disposeBag)
    }

    func report(at indexPath: IndexPath) {
        let idx = indexPath.item
        guard idx < items.count else { return }
        let postId = items[idx].postId

        feedRepository.report(postId: postId, reason: "REVIEW_REQUIRED")
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] resp in
                guard let self else { return }
                if let data = try? JSONEncoder().encode(resp),
                   let json = String(data: data, encoding: .utf8) {
                    self.logger.info("[Feed] report response JSON — postId=\(postId), body=\(json, privacy: .public)")
                } else {
                    self.logger.info("[Feed] report response (unencodable) — postId=\(postId)")
                }

                if resp.postId == postId && resp.success {
                    self.reportSuccess.accept(())
                } else {
                    self.errorMessage.accept("신고 처리에 실패했습니다. 잠시 후 다시 시도해주세요.")
                }
            }, onFailure: { [weak self] error in
                self?.errorMessage.accept(error.localizedDescription)
            })
            .disposed(by: disposeBag)
    }

    private func fetchSpaces() {
        spaceRepository.fetchSpaces()
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] spaces in
                guard let self else { return }
                self.spaces = spaces
                self.selectedChipIndex = min(self.selectedChipIndex, self.spaces.count)
                self.chipsUpdated.accept(())
                if self.items.isEmpty {
                    self.loadFeed(reset: true)
                }
            }, onFailure: { [weak self] error in
                self?.errorMessage.accept(error.localizedDescription)
            })
            .disposed(by: disposeBag)
    }

    private func loadFeed(reset: Bool) {
        if isLoading { return }
        isLoading = true

        let requestStart = Date()
        let selectedSpaceId: Int? = (selectedChipIndex == 0) ? nil : spaces[selectedChipIndex - 1].id
        let nextPage = reset ? 1 : (currentPage + 1)

        feedRequestCount += 1
        logger.info("[Feed] request #\(self.feedRequestCount) start — spaceId=\(selectedSpaceId?.description ?? "all", privacy: .public), page=\(nextPage), reset=\(reset, privacy: .public)")

        feedRepository.fetchFeed(spaceId: selectedSpaceId, page: nextPage, size: pageSize)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] resp in
                guard let self else { return }

                self.currentPage = resp.page
                self.totalPages = resp.totalPages

                let pageTuples: [(postId: Int, url: URL, liked: Bool)] = resp.posts.compactMap { dto in
                    guard let url = URL(string: dto.photoUrl) else { return nil }
                    return (postId: dto.postId, url: url, liked: dto.liked)
                }

                let group = DispatchGroup()
                var sizedTuples: [(postId: Int, size: CGSize)] = []
                let syncQueue = DispatchQueue(label: "feed.size.collect")

                for t in pageTuples {
                    group.enter()
                    KingfisherManager.shared.retrieveImage(with: t.url, options: nil, progressBlock: nil) { result in
                        let size: CGSize
                        switch result {
                        case .success(let value):
                            size = value.image.size
                        case .failure:
                            size = CGSize(width: 3, height: 4)
                        }
                        syncQueue.sync {
                            sizedTuples.append((t.postId, size))
                        }
                        group.leave()
                    }
                }

                group.notify(queue: .main) {
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
                    self.feedUpdated.accept(())

                    let elapsed = Date().timeIntervalSince(requestStart)
                    self.logger.info("[Feed] request #\(self.feedRequestCount) success — elapsed=\(elapsed, format: .fixed(precision: 2))s, page=\(self.currentPage), totalPages=\(self.totalPages), added=\(newItems.count), totalItems=\(self.items.count)")

                    self.isLoading = false
                }
            }, onFailure: { [weak self] error in
                guard let self else { return }
                let elapsed = Date().timeIntervalSince(requestStart)
                self.logger.error("[Feed] request #\(self.feedRequestCount) failure — elapsed=\(elapsed, format: .fixed(precision: 2))s, error=\(error.localizedDescription, privacy: .public)")
                self.isLoading = false
                self.errorMessage.accept(error.localizedDescription)
            })
            .disposed(by: disposeBag)
    }
}
