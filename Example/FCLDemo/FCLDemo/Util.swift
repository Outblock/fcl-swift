//
//  File.swift
//
//
//  Created by lmcmz on 9/11/21.
//

import Combine
import Foundation
import SwiftUI

public class KeyboardInfo: ObservableObject {
    public static var shared = KeyboardInfo()

    @Published public var height: CGFloat = 0

    private init() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardChanged), name: UIApplication.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardChanged), name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardChanged), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }

    @objc func keyboardChanged(notification: Notification) {
        if notification.name == UIApplication.keyboardWillHideNotification {
            height = 0
        } else {
            height = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height ?? 0
        }
    }
}

struct KeyboardAware: ViewModifier {
    @ObservedObject private var keyboard = KeyboardInfo.shared

    func body(content: Content) -> some View {
        content
            .padding(.bottom, keyboard.height)
            .edgesIgnoringSafeArea(keyboard.height > 0 ? .bottom : [])
            .animation(.easeOut)
    }
}

public extension View {
    func keyboardAware() -> some View {
        ModifiedContent(content: self, modifier: KeyboardAware())
    }

    func dismissingKeyboard() -> some View {
        ModifiedContent(content: self, modifier: DismissingKeyboard())
    }
}

struct DismissingKeyboard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onTapGesture {
                let keyWindow = UIApplication.shared.connectedScenes
                    .filter { $0.activationState == .foregroundActive }
                    .map { $0 as? UIWindowScene }
                    .compactMap { $0 }
                    .first?.windows
                    .filter { $0.isKeyWindow }.first
                keyWindow?.endEditing(true)
            }
    }
}

extension String {
    func leftPadding(toLength: Int, withPad character: Character) -> String {
        let stringLength = count
        if stringLength < toLength {
            return String(repeatElement(character, count: toLength - stringLength)) + self
        } else {
            return String(suffix(toLength))
        }
    }

    subscript(bounds: CountableClosedRange<Int>) -> String {
        let start = index(startIndex, offsetBy: bounds.lowerBound)
        let end = index(startIndex, offsetBy: bounds.upperBound)
        return String(self[start ... end])
    }

    subscript(bounds: CountableRange<Int>) -> String {
        let start = index(startIndex, offsetBy: bounds.lowerBound)
        let end = index(startIndex, offsetBy: bounds.upperBound)
        return String(self[start ..< end])
    }
}

extension String {
    func addHexPrefix() -> String {
        if !hasPrefix("0x") {
            return "0x" + self
        }
        return self
    }
}

extension Decimal {
    func toTokenFormat(decimal: Int = 8) -> String {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = decimal
        formatter.minimumFractionDigits = 1
        formatter.numberStyle = .decimal
        return formatter.string(for: self) ?? String(NSDecimalNumber(decimal: self).doubleValue)
    }
}
