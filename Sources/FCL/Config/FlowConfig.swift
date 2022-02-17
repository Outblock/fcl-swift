//
//  File.swift
//
//
//  Created by lmcmz on 29/8/21.
//

import Foundation

public class Config {
    var dict = [String: String]()

    public enum Key: String, CaseIterable {
        case accessNode = "accessNode.api"
        case icon = "app.detail.icon"
        case title = "app.detail.title"
        case handshake = "challenge.handshake"
        case scope = "challenge.scope"
        case wallet = "discovery.wallet"
        case authn
        case env
        case location
        case openIDScope = "service.OpenID.scopes"
        case domainTag = "fcl.appDomainTag"
    }

    public func configLens(_ regex: String) -> [String: String] {
        let matches = dict.filter { item in
            item.key.range(of: regex, options: .regularExpression) != nil
        }

        let newDict = Dictionary(uniqueKeysWithValues:
            matches.map { key, value in
                (key.replacingOccurrences(of: regex, with: "", options: [.regularExpression]), value)
            })

        return newDict
    }

    public func get(_ key: Key) -> String? {
        return dict[key.rawValue] ?? nil
    }

    @discardableResult
    public func put(_ key: Key, value: String) -> Self {
        dict[key.rawValue] = value
        return self
    }

    @discardableResult
    public func remove(key: Key) -> Config {
        dict.removeValue(forKey: key.rawValue)
        return self
    }

    public func get(_ key: String) -> String? {
        return dict[key] ?? nil
    }

    @discardableResult
    public func put(_ key: String, value: String) -> Self {
        dict[key] = value
        return self
    }

    @discardableResult
    public func remove(_ key: String) -> Config {
        dict.removeValue(forKey: key)
        return self
    }

    @discardableResult
    public func clear() -> Config {
        dict.removeAll()
        return self
    }
}
