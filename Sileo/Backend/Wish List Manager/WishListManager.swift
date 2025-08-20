//
//  WishListManager.swift
//  Sileo
//
//  Created by CoolStar on 7/3/19.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation

class WishListManager {
    public static let shared = WishListManager()
    public static let changeNotification = NSNotification.Name(
        "SileoWishlistChanged"
    )
    private(set) public var wishlist: [String] = []

    init() {
        self.reloadData()
    }

    func reloadData() {
        guard
            var rawWishlist = UserDefaults.standard.array(forKey: "wishlist")
                as? [String]
        else {
            wishlist = []
            return
        }
        let installedPackages = PackageListManager.shared.installedPackages
        rawWishlist.removeAll { item in
            installedPackages.contains { $0.key == item }
        }
        wishlist = rawWishlist
    }

    func isPackageInWishList(_ package: String) -> Bool {
        wishlist.contains(package)
    }

    func addPackageToWishList(_ package: String) -> Bool {
        if self.isPackageInWishList(package) {
            return false
        }
        wishlist.append(package)
        UserDefaults.standard.set(wishlist, forKey: "wishlist")
        NotificationCenter.default.post(
            name: WishListManager.changeNotification,
            object: nil
        )
        return true
    }

    func removePackageFromWishList(_ package: String) {
        wishlist.removeAll { package == $0 }
        UserDefaults.standard.set(wishlist, forKey: "wishlist")
        NotificationCenter.default.post(
            name: WishListManager.changeNotification,
            object: nil
        )
    }
}

class InstallHistoryManager {
    public static let shared = InstallHistoryManager()
    public static let changeNotification = NSNotification.Name(
        "SileoInstallHistoryChanged"
    )

    public enum Action: String, Codable {
        case install
        case reinstall
        case uninstall
        case update
    }

    public struct Entry: Codable {
        public let id: String
        public let version: String?
        public let date: TimeInterval
        public let action: Action?
        public let previousVersion: String?

        public var timestamp: TimeInterval { date }
    }

    private var entries: [Entry] = []
    private let maxItems = 1000

    private var fileURL: URL {
        let base = URL(fileURLWithPath: CommandPath.prefix)
            .appendingPathComponent(
                "var/mobile/Library/Sileo",
                isDirectory: true
            )
        if !FileManager.default.fileExists(atPath: base.path) {
            try? FileManager.default.createDirectory(
                at: base,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
        return base.appendingPathComponent("InstallHistory.plist")
    }

    init() {
        load()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else {
            entries = []
            return
        }
        entries =
            (try? PropertyListDecoder().decode([Entry].self, from: data)) ?? []
    }

    private func save() {
        let pruned = Array(entries.suffix(maxItems))
        if let data = try? PropertyListEncoder().encode(pruned) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    public var recentPackageIDs: [String] {
        var seen = Set<String>()
        var ids: [String] = []
        for entry in entries.sorted(by: { $0.date > $1.date }) {
            if !seen.contains(entry.id) {
                seen.insert(entry.id)
                ids.append(entry.id)
            }
        }
        return ids
    }

    public func addToHistory(_ packageIDs: [String]) {
        // Backwards compatibility: default to install
        addToHistory(packageIDs, action: .install)
    }

    public func addToHistory(_ packageIDs: [String], action: Action) {
        guard !packageIDs.isEmpty else { return }
        let now = Date().timeIntervalSince1970
        for id in packageIDs {
            let version = PackageListManager.shared.installedPackage(
                identifier: id
            )?.version
            entries.append(
                Entry(
                    id: id,
                    version: version,
                    date: now,
                    action: action,
                    previousVersion: nil
                )
            )
        }
        save()
        NotificationCenter.default.post(
            name: InstallHistoryManager.changeNotification,
            object: nil
        )
    }

    public func addToHistory(
        _ items: [(id: String, previousVersion: String?, newVersion: String?)],
        action: Action
    ) {
        guard !items.isEmpty else { return }
        let now = Date().timeIntervalSince1970
        for item in items {
            entries.append(
                Entry(
                    id: item.id,
                    version: item.newVersion,
                    date: now,
                    action: action,
                    previousVersion: item.previousVersion
                )
            )
        }
        save()
        NotificationCenter.default.post(
            name: InstallHistoryManager.changeNotification,
            object: nil
        )
    }

    public func actionForPackage(_ id: String) -> Action? {
        // Return the most recent action recorded for the given package id
        return
            entries
            .filter { $0.id == id }
            .max(by: { $0.date < $1.date })?.action
    }

    public func lastKnownVersion(for id: String) -> String? {
        return
            entries
            .filter { $0.id == id }
            .max(by: { $0.date < $1.date })?.version
    }

    public var timeline: [Entry] {
        entries.sorted(by: { $0.date > $1.date })
    }

    public func clear() {
        entries.removeAll()
        save()
        NotificationCenter.default.post(
            name: InstallHistoryManager.changeNotification,
            object: nil
        )
    }
}
