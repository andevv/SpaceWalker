//
//  CalendarRepository.swift
//  SpaceWalker
//
//  Created by andev on 3/31/26.
//

import Foundation
import UIKit
import RxSwift
import Alamofire

final class CalendarRepository {
    private static let afSession: Session = {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.urlCache = URLCache(
            memoryCapacity: 50 * 1024 * 1024,
            diskCapacity: 200 * 1024 * 1024,
            diskPath: "calendar.image.cache"
        )
        return Session(configuration: config)
    }()

    func fetchImage(url: URL) -> Single<UIImage?> {
        Single.create { single in
            let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 30)

            let afRequest = Self.afSession.request(request)
                .validate(statusCode: 200..<400)
                .responseData(queue: .global(qos: .userInitiated)) { response in
                    switch response.result {
                    case .success(let data):
                        single(.success(UIImage(data: data)))
                    case .failure(let error):
                        LogNetwork("[AF] image request failed — url=\(url.absoluteString), error=\(error.localizedDescription)")
                        single(.success(nil))
                    }
                }

            return Disposables.create {
                afRequest.cancel()
            }
        }
    }
}
