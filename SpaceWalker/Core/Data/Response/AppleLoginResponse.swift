//
//  AppleLoginResponse.swift
//  SpaceWalker
//
//  Created by andev on 10/7/25.
//

import Foundation

// MARK: - DTO
struct AppleLoginResponse: Decodable {
    let accessToken: String
    let refreshToken: String
}

struct AppleLoginErrorResponse: Decodable {
    let code: String
    let message: String
}
