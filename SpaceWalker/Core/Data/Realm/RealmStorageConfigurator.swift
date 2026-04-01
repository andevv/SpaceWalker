//
//  RealmStorageConfigurator.swift
//  SpaceWalker
//
//  Created by andev on 4/1/26.
//

import Foundation
import RealmSwift

enum RealmStorageConfigurator {
    private static let realmDirectoryName = "Realm"
    private static let realmFileName = "default.realm"

    static func configureDefaultRealmForBackup() {
        do {
            let destinationURL = try preferredRealmFileURL()
            try migrateLegacyRealmIfNeeded(to: destinationURL)

            var config = Realm.Configuration.defaultConfiguration
            config.fileURL = destinationURL
            Realm.Configuration.defaultConfiguration = config

            _ = try Realm(configuration: config)
            LogGeneral("Realm configured at backup-included path: \(destinationURL.path)")
        } catch {
            LogGeneral("Realm configuration failed: \(error.localizedDescription)")
        }
    }

    private static func preferredRealmFileURL() throws -> URL {
        let appSupport = try applicationSupportDirectory()
        let realmDir = appSupport.appendingPathComponent(realmDirectoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: realmDir, withIntermediateDirectories: true)
        return realmDir.appendingPathComponent(realmFileName)
    }

    private static func applicationSupportDirectory() throws -> URL {
        guard let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "RealmStorageConfigurator", code: -1001, userInfo: [NSLocalizedDescriptionKey: "Application Support directory not found"])
        }
        return url
    }

    private static func migrateLegacyRealmIfNeeded(to destination: URL) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: destination.path) == false else { return }

        let candidates = try legacyRealmCandidates()
        guard let source = candidates.first(where: { fm.fileExists(atPath: $0.path) }) else { return }

        try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try moveRealmFileSet(from: source, to: destination)
        LogGeneral("Realm migrated: \(source.path) -> \(destination.path)")
    }

    private static func legacyRealmCandidates() throws -> [URL] {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first
        let appSupport = try applicationSupportDirectory()

        var urls: [URL] = []
        if let docs { urls.append(docs.appendingPathComponent(realmFileName)) }
        if let library { urls.append(library.appendingPathComponent(realmFileName)) }
        urls.append(appSupport.appendingPathComponent(realmFileName))
        return urls
    }

    private static func moveRealmFileSet(from sourceRealmURL: URL, to destinationRealmURL: URL) throws {
        let fm = FileManager.default
        let pairs = realmFilePairs(sourceRealmURL: sourceRealmURL, destinationRealmURL: destinationRealmURL)

        for (source, destination) in pairs {
            guard fm.fileExists(atPath: source.path) else { continue }
            if fm.fileExists(atPath: destination.path) {
                try? fm.removeItem(at: destination)
            }
            try fm.moveItem(at: source, to: destination)
        }
    }

    private static func realmFilePairs(sourceRealmURL: URL, destinationRealmURL: URL) -> [(URL, URL)] {
        let sourceManagementURL = sourceRealmURL.deletingPathExtension().appendingPathExtension("management")
        let destinationManagementURL = destinationRealmURL.deletingPathExtension().appendingPathExtension("management")

        return [
            (sourceRealmURL, destinationRealmURL),
            (sourceRealmURL.appendingPathExtension("lock"), destinationRealmURL.appendingPathExtension("lock")),
            (sourceRealmURL.appendingPathExtension("note"), destinationRealmURL.appendingPathExtension("note")),
            (sourceManagementURL, destinationManagementURL)
        ]
    }
}
