//
//  JSONDecoder+.swift
//  SpaceWalker
//
//  Created by andev on 10/5/25.
//

import Foundation

extension JSONDecoder {
    static func iso8601() -> JSONDecoder {
        let decoder = JSONDecoder()
        // 서버에서 ISO8601 포맷("2025-09-20T00:10:00Z") 사용 시
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
