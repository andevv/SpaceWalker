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

    private let tokenKey = "access_token"

    var accessToken: String? {
        get { UserDefaults.standard.string(forKey: tokenKey) }
        set {
            if let value = newValue {
                UserDefaults.standard.set(value, forKey: tokenKey)
            } else {
                UserDefaults.standard.removeObject(forKey: tokenKey)
            }
        }
    }

    func clearSession() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
    }
}
