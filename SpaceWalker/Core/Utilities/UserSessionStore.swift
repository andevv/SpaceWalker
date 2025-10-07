//
//  UserSessionStore.swift
//  SpaceWalker
//
//  Created by andev on 10/5/25.
//

import Foundation

final class UserSessionStore {
    static let shared = UserSessionStore()
    private init() {}

    private let accessTokenKey = "access_token"
    private let refreshTokenKey = "refresh_token"

    var accessToken: String? {
        get { UserDefaults.standard.string(forKey: accessTokenKey) }
        set { UserDefaults.standard.setValue(newValue, forKey: accessTokenKey) }
    }

    var refreshToken: String? {
        get { UserDefaults.standard.string(forKey: refreshTokenKey) }
        set { UserDefaults.standard.setValue(newValue, forKey: refreshTokenKey) }
    }

    func clearSession() {
        UserDefaults.standard.removeObject(forKey: accessTokenKey)
        UserDefaults.standard.removeObject(forKey: refreshTokenKey)
    }
}
