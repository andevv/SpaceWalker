//
//  FeedDetailViewModel.swift
//  SpaceWalker
//
//  Created by andev on 2/25/26.
//

import Foundation
import UIKit
import RxSwift
import RxCocoa

final class FeedDetailViewModel: BaseViewModel {

    struct Input {
        let viewDidLoad: Observable<Void>
    }

    struct Output {
        let detail: Driver<FeedDetailModel>
    }

    private let feedRepository = FeedRepository()
    private let disposeBag = DisposeBag()

    private let initialModel: FeedDetailModel
    private let apiPostId: Int?
    private let detailRelay: BehaviorRelay<FeedDetailModel>

    init(initialModel: FeedDetailModel, postId: Int?) {
        self.initialModel = initialModel
        self.apiPostId = postId
        self.detailRelay = BehaviorRelay(value: initialModel)
    }

    func transform(input: Input) -> Output {
        input.viewDidLoad
            .subscribe(onNext: { [weak self] in
                guard let self else { return }
                if let postId = self.apiPostId {
                    self.fetchFeedDetail(postId: postId)
                } else {
                    self.bindInitialModel()
                }
            })
            .disposed(by: disposeBag)

        return Output(
            detail: detailRelay.asDriver()
        )
    }

    private func bindInitialModel() {
        var model = initialModel
        if model.image == nil, let url = model.imageURL {
            loadImage(from: url) { [weak self] image in
                guard let self else { return }
                model.image = image
                self.detailRelay.accept(model)
            }
        } else {
            detailRelay.accept(model)
        }
    }

    private func fetchFeedDetail(postId: Int) {
        feedRepository.fetchFeedDetail(postId: postId)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] dto in
                guard let self else { return }

                var updated = FeedDetailModel(
                    image: nil,
                    likeCount: dto.likeCount,
                    liked: dto.liked,
                    authorName: dto.author.nickname,
                    missionTitle: dto.dailyMission.title,
                    imageURL: URL(string: dto.photoUrl),
                    authorProfileURL: dto.author.profileImageUrl.flatMap(URL.init(string:))
                )

                self.detailRelay.accept(updated)

                if let url = updated.imageURL {
                    self.loadImage(from: url) { [weak self] image in
                        guard let self else { return }
                        updated.image = image
                        self.detailRelay.accept(updated)
                    }
                }

            }, onFailure: { [weak self] error in
                print("[FeedDetail] fetch error: \(error)")
                self?.bindInitialModel()
            })
            .disposed(by: disposeBag)
    }

    private func loadImage(from url: URL, completion: @escaping (UIImage?) -> Void) {
        let task = URLSession.shared.dataTask(with: url) { data, _, _ in
            let image = data.flatMap { UIImage(data: $0) }
            DispatchQueue.main.async {
                completion(image)
            }
        }
        task.resume()
    }
}
