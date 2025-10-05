//
//  SpaceRepository.swift
//  SpaceWalker
//
//  Created by andev on 10/5/25.
//

import Foundation
import RxSwift
import Alamofire

final class SpaceRepository {

    func fetchSpaces() -> Single<[Space]> {
        // 1) 제네릭 표기 제거 + 2) 응답 타입을 캐스팅으로 제공
        let single: Single<SpacesResponse> = NetworkManager.shared.request(
            "/api/v1/spaces",
            method: .get,
            parameters: nil,
            requiresAuth: true
        )

        // 3) 클로저 인자 타입을 명시해 주면 컴파일러가 확정적으로 알 수 있음.
        return single.map { (resp: SpacesResponse) in
            resp.spaces.map { Space(id: $0.id, name: $0.name) }
        }
    }
    
    func fetchDummySpaces() -> Single<[Space]> {
        return Single.create { single in
            // 더미 API 응답 시뮬레이션
            let dummyResponse = SpacesResponse(
                spaces: [
                    SpaceDTO(id: 1, name: "Study"),
                    SpaceDTO(id: 2, name: "Color"),
                    SpaceDTO(id: 3, name: "Work"),
                    SpaceDTO(id: 4, name: "Rest")
                ],
                total: 4
            )

            // 0.5초 딜레이 후 방출 (API 호출 느낌)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let mapped = dummyResponse.spaces.map { Space(id: $0.id, name: $0.name) }
                single(.success(mapped))
            }

            return Disposables.create()
        }
    }
}
