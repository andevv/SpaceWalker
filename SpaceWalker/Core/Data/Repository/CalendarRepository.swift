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

    func uploadImageDataToS3(
        _ data: Data,
        contentType: String,
        to urlString: String,
        progress: ((Double) -> Void)? = nil
    ) -> Single<Void> {
        Single.create { single in
            guard let url = URL(string: urlString) else {
                single(.failure(NSError(domain: "InvalidURL", code: -1)))
                return Disposables.create()
            }

            let headers: HTTPHeaders = ["Content-Type": contentType]
            let request = Self.afSession.upload(data, to: url, method: .put, headers: headers)
                .uploadProgress { prog in
                    progress?(prog.fractionCompleted)
                }
                .validate(statusCode: 200..<300)
                .response { response in
                    if let err = response.error {
                        LogNetwork("[S3] upload failed — status=\(response.response?.statusCode ?? -1), error=\(err.localizedDescription)")
                        if let bodyData = response.data, let body = String(data: bodyData, encoding: .utf8) {
                            LogNetwork("[S3] upload error body — \(body)")
                        }
                        single(.failure(err))
                    } else {
                        let status = response.response?.statusCode ?? -1
                        LogNetwork("[S3] upload success — status=\(status)")
                        single(.success(()))
                    }
                }

            return Disposables.create {
                request.cancel()
            }
        }
    }
}
