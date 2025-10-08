//
//  RefreshResponse.swift
//  SpaceWalker
//
//  Created by andev on 10/8/25.
//

import Foundation

struct RefreshResponse: Decodable {
    let accessToken: String
    let refreshToken: String
}
