//
//  RefreshResponse.swift
//  SpaceWalker
//
//  Created by andev on 10/8/25.
//

import Foundation

nonisolated struct RefreshResponse: Decodable, Sendable {
    let accessToken: String
    let refreshToken: String
}
