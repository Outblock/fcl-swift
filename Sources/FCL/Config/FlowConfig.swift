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
    }

    public func get(key: Key) -> String? {
        return dict[key.rawValue] ?? nil
    }

    @discardableResult
    public func put(key: Key, value: String?) -> Self {
        if let valueString = value {
            dict[key.rawValue] = valueString
        }
        return self
    }

    @discardableResult
    public func remove(key: Key) -> Config {
        dict.removeValue(forKey: key.rawValue)
        return self
    }

    public func get(key: String) -> String? {
        return dict[key] ?? nil
    }

    @discardableResult
    public func put(key: String, value: String?) -> Self {
        if let valueString = value {
            dict[key] = valueString
        }
        return self
    }

    @discardableResult
    public func remove(key: String) -> Config {
        dict.removeValue(forKey: key)
        return self
    }

    @discardableResult
    public func clear() -> Config {
        dict.removeAll()
        return self
    }
}
