//
//  EditNicknameViewModel.swift
//  SpaceWalker
//
//  Created by andev on 2/28/26.
//

import Foundation

enum EditNicknameSaveResult {
    case invalid
    case success
    case failure
}

final class EditNicknameViewModel {
    private let onSave: (String, @escaping (Bool) -> Void) -> Void
    private let originalNickname: String

    private(set) var isSaving: Bool = false
    private(set) var currentText: String = ""

    init(currentNickname: String?, onSave: @escaping (String, @escaping (Bool) -> Void) -> Void) {
        self.onSave = onSave
        self.originalNickname = (currentNickname ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        self.currentText = currentNickname ?? ""
    }

    func currentValidationState() -> EditNicknameValidationState {
        EditNicknameValidator.makeState(text: currentText, originalNickname: originalNickname, isSaving: isSaving)
    }

    func updateText(_ text: String) -> EditNicknameValidationState {
        currentText = text
        return currentValidationState()
    }

    func setSaving(_ saving: Bool) -> EditNicknameValidationState {
        isSaving = saving
        return currentValidationState()
    }

    func save(completion: @escaping (EditNicknameSaveResult) -> Void) {
        let state = currentValidationState()
        guard state.canSave else {
            completion(.invalid)
            return
        }

        isSaving = true
        onSave(state.trimmedText) { [weak self] success in
            guard let self else { return }
            self.isSaving = false
            completion(success ? .success : .failure)
        }
    }
}
