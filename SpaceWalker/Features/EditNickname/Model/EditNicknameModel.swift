//
//  EditNicknameModel.swift
//  SpaceWalker
//
//  Created by andev on 2/28/26.
//

import Foundation

struct EditNicknameValidationState {
    let trimmedText: String
    let countText: String
    let isLengthValid: Bool
    let isCharsetValid: Bool
    let isNoSpaceValid: Bool
    let isNoEmojiValid: Bool
    let isAllValid: Bool
    let canSave: Bool
}

enum EditNicknameValidator {
    static func makeState(text: String, originalNickname: String, isSaving: Bool) -> EditNicknameValidationState {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let length = validateLength(trimmed)
        let noSpace = validateNoSpace(trimmed)
        let noEmoji = validateNoEmoji(trimmed)
        let charset = validateAllowedCharset(trimmed)
        let allValid = length && noSpace && noEmoji && charset

        return EditNicknameValidationState(
            trimmedText: trimmed,
            countText: "\(trimmed.count)/20",
            isLengthValid: length,
            isCharsetValid: charset,
            isNoSpaceValid: noSpace,
            isNoEmojiValid: noEmoji,
            isAllValid: allValid,
            canSave: allValid && trimmed != originalNickname && !isSaving
        )
    }

    static func validateLength(_ text: String) -> Bool {
        (2...20).contains(text.count)
    }

    static func validateNoSpace(_ text: String) -> Bool {
        !text.contains { $0.isWhitespace }
    }

    static func validateNoEmoji(_ text: String) -> Bool {
        for scalar in text.unicodeScalars {
            if scalar.properties.isEmoji && (scalar.properties.isEmojiPresentation || scalar.value >= 0x238d) {
                return false
            }
        }
        return true
    }

    static func validateAllowedCharset(_ text: String) -> Bool {
        if text.isEmpty { return false }
        let allowed = CharacterSet.letters
            .union(.decimalDigits)
            .union(CharacterSet(charactersIn: "-_"))
        return text.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
}
