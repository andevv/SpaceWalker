//
//  SignUpViewController.swift
//  SpaceWalker
//
//  Created by andev on 9/29/25.
//

import UIKit
import SnapKit
import AuthenticationServices
import CryptoKit

final class SignUpViewController: UIViewController {

    // MARK: - UI Components
    private let logoImageView: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "AppLogo"))
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private let appleButton: ASAuthorizationAppleIDButton = {
        let btn = ASAuthorizationAppleIDButton(type: .signIn, style: .black)
        btn.cornerRadius = 12
        return btn
    }()

    private let bottomTextView: UITextView = {
        let tv = UITextView()
        tv.isEditable = false
        tv.isScrollEnabled = false
        tv.textAlignment = .center
        tv.backgroundColor = .clear
        tv.textColor = .secondaryLabel
        tv.font = .systemFont(ofSize: 13)
        tv.text = "로그인을 진행하면 서비스 이용약관 및 개인정보 처리방침에 동의한 것으로 간주됩니다."
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        return tv
    }()

    // MARK: - Apple Sign In Properties
    private var currentNonce: String?

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupLayout()
        appleButton.addTarget(self, action: #selector(startAppleLogin), for: .touchUpInside)
    }

    // MARK: - Layout
    private func setupLayout() {
        view.addSubview(logoImageView)
        view.addSubview(appleButton)
        view.addSubview(bottomTextView)

        logoImageView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(100)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(120)
        }

        appleButton.snp.makeConstraints { make in
            make.top.equalTo(logoImageView.snp.bottom).offset(60)
            make.leading.trailing.equalToSuperview().inset(24)
            make.height.equalTo(52)
        }

        bottomTextView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalTo(view.safeAreaLayoutGuide).inset(20)
        }
    }

    // MARK: - Apple Login Flow
    @objc private func startAppleLogin() {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [] // 사용자 정보 불필요
        let nonce = randomNonceString()
        currentNonce = nonce
        request.nonce = sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    // MARK: - Nonce Helpers
    private func randomNonceString(length: Int = 32) -> String {
        let charset: [Character] =
            Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms = (0 ..< 16).map { _ in UInt8.random(in: 0...255) }
            randoms.forEach { random in
                if remainingLength == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random) % charset.count])
                    remainingLength -= 1
                }
            }
        }
        return result
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - ASAuthorizationControllerDelegate
extension SignUpViewController: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }

        guard let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            print("ID Token 없음")
            return
        }

        let userIdentifier = credential.user
        print("Apple 로그인 성공")
        print("userIdentifier:", userIdentifier)
        print("idToken (JWT):", idToken)

        // 서버 통신 준비 (현재는 OFF)
        #if DEBUG
        showDebugAlert(userIdentifier: userIdentifier, idToken: idToken)
        #else
        sendToServer(idToken: idToken, userIdentifier: userIdentifier)
        #endif
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithError error: Error) {
        print("Apple 로그인 실패:", error.localizedDescription)
        let alert = UIAlertController(
            title: "로그인 실패",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "확인", style: .cancel))
        present(alert, animated: true)
    }

    // MARK: - Local Debug (for Simulator)
    private func showDebugAlert(userIdentifier: String, idToken: String) {
        let alert = UIAlertController(
            title: "로그인 성공",
            message: "User ID: \(userIdentifier)\n\nJWT 앞부분:\n\(idToken.prefix(40))...",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }

    // MARK: - Future Server Communication
    private func sendToServer(idToken: String, userIdentifier: String) {
        // TODO: 나중에 서버(Spring Boot) 연결 시 활성화
        // 예시 URL: https://api.spacewalker.com/api/v1/auth/apple
        /*
        AF.request("https://api.spacewalker.com/api/v1/auth/apple",
                   method: .post,
                   parameters: ["id_token": idToken, "user_identifier": userIdentifier],
                   encoding: JSONEncoding.default)
        .validate()
        .responseDecodable(of: AuthResponse.self) { response in
            switch response.result {
            case .success(let result):
                print("서버 응답:", result)
            case .failure(let error):
                print("서버 통신 오류:", error)
            }
        }
        */
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension SignUpViewController: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return view.window!
    }
}
