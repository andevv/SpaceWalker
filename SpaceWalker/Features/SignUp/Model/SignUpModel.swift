//
//  SignUpModel.swift
//  SpaceWalker
//
//  Created by andev on 3/4/26.
//

import Foundation

struct SignUpAppleLoginPayload {
    let userIdentifier: String
    let idToken: String
    let authCode: String
}

enum SignUpRoute {
    case spaceSelect
    case mainTab
}
