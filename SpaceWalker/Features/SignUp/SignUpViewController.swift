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
import RxSwift
import RxCocoa

final class SignUpViewController: UIViewController {

    // MARK: - UI Components
    private let logoImageView: UIImageView = {
        let iv = UIImageView(image: UIImage(systemName: "star.fill"))
        iv.tintColor = .label
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private let appleButton: ASAuthorizationAppleIDButton = {
        let btn = ASAuthorizationAppleIDButton(type: .signIn, style: .black)
        btn.cornerRadius = 12
        return btn
    }()

    // 로그인 버튼 아래 링크 영역
    private let linksStack = UIStackView() // “서비스 이용약관” / “개인정보 처리방침”
    private let termsButton = UIButton(type: .system)
    private let privacyButton = UIButton(type: .system)
    private let dotLabel: UILabel = {
        let lb = UILabel()
        lb.text = " · "
        lb.textColor = .tertiaryLabel
        lb.textAlignment = .center
        lb.font = .systemFont(ofSize: 14, weight: .regular)
        return lb
    }()

    private let bottomTextView: UITextView = {
        let tv = UITextView()
        tv.isEditable = false
        tv.isScrollEnabled = false
        tv.textAlignment = .center
        tv.backgroundColor = .clear
        tv.textColor = .secondaryLabel
        tv.font = .systemFont(ofSize: 10)
        tv.text = "로그인을 진행하면 서비스 이용약관 및 개인정보 처리방침에 동의한 것으로 간주됩니다."
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        return tv
    }()

    // MARK: - Apple Sign In Properties
    private var currentNonce: String?
    
    private let disposeBag = DisposeBag()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupLayout()
        setupLinks()
        appleButton.addTarget(self, action: #selector(startAppleLogin), for: .touchUpInside)
    }

    // MARK: - Layout
    private func setupLayout() {
        view.addSubview(logoImageView)
        view.addSubview(appleButton)
        view.addSubview(linksStack)
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

        // 먼저 bottomTextView를 바닥에 고정
        bottomTextView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalTo(view.safeAreaLayoutGuide).inset(20)
        }

        // linksStack을 bottomTextView 위 16pt에 배치
        linksStack.snp.makeConstraints { make in
            make.bottom.equalTo(bottomTextView.snp.top).offset(-16)
            make.centerX.equalToSuperview()
        }
    }

    private func setupLinks() {
        linksStack.axis = .horizontal
        linksStack.spacing = 8
        linksStack.alignment = .firstBaseline // 기준선 정렬로 가운데 점 위치 안정화
        linksStack.distribution = .equalCentering

        func styleLinkButton(_ b: UIButton, title: String) {
            var config = UIButton.Configuration.plain()
            config.title = title
            config.baseForegroundColor = .secondaryLabel
            config.contentInsets = .zero
            b.configuration = config
            b.titleLabel?.font = .systemFont(ofSize: 12, weight: .regular)

            let attr = NSAttributedString(
                string: title,
                attributes: [
                    .font: UIFont.systemFont(ofSize: 12, weight: .regular),
                    .foregroundColor: UIColor.secondaryLabel,
                    .underlineStyle: NSUnderlineStyle.single.rawValue
                ]
            )
            b.setAttributedTitle(attr, for: .normal)
        }

        styleLinkButton(termsButton, title: "서비스 이용약관")
        styleLinkButton(privacyButton, title: "개인정보 처리방침")

        termsButton.addTarget(self, action: #selector(openTerms), for: .touchUpInside)
        privacyButton.addTarget(self, action: #selector(openPrivacy), for: .touchUpInside)

        // 가운데 점의 너비가 과도하게 늘어나지 않도록 우선순위 조정
        dotLabel.setContentHuggingPriority(.required, for: .horizontal)
        dotLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        linksStack.addArrangedSubview(termsButton)
        linksStack.addArrangedSubview(dotLabel)
        linksStack.addArrangedSubview(privacyButton)
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

    // MARK: - Terms / Privacy (더미 표시)
    @objc private func openTerms() {
        let dummy = """
        [서비스 이용약관 - 더미]
        SpaceWalker 서비스를 이용해주셔서 감사합니다.
        본 약관은 서비스의 이용조건 및 절차, 회원과 회사의 권리·의무 등 기본적인 사항을 규정합니다.

        1. 목적
        2. 용어의 정의
        3. 약관의 효력 및 변경
        4. 회원의 의무
        5. 서비스의 제공 및 중단
        6. 기타

        ※ 실제 약관은 서버 API 연동 후 교체됩니다.
        """
        let vc = SimpleDocViewController(titleText: "서비스 이용약관", bodyText: dummy)
        presentSheet(vc)
    }

    @objc private func openPrivacy() {
        let dummy = """
        [개인정보 처리방침 - 더미]
        SpaceWalker는 이용자의 개인정보를 중요하게 생각합니다.
        수집·이용·보관·파기에 관한 정책을 다음과 같이 안내합니다.

        1. 수집하는 개인정보의 항목
        2. 개인정보의 수집 및 이용목적
        3. 개인정보의 보유 및 이용기간
        4. 개인정보의 제3자 제공 및 위탁
        5. 이용자의 권리와 행사 방법
        6. 기타

        ※ 실제 방침은 서버 API 연동 후 교체됩니다.
        """
        let vc = SimpleDocViewController(titleText: "개인정보 처리방침", bodyText: dummy)
        presentSheet(vc)
    }

    private func presentSheet(_ vc: UIViewController) {
        vc.modalPresentationStyle = .pageSheet
        if let sheet = vc.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 16
        }
        present(vc, animated: true)
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
        UserDefaults.standard.set(userIdentifier, forKey: "apple_user_id")
        print("Apple 로그인 성공")
        print("userIdentifier:", userIdentifier)
        print("idToken (JWT):", idToken)

        let loginRepo = AppleLoginRepository()
            let spaceRepo = SpaceRepository()

            // 순차 비동기 체인
            loginRepo.loginWithApple(idToken: idToken)
                .do(onSuccess: { response in
                    // 토큰 저장
                    UserSessionStore.shared.accessToken = response.accessToken
                    UserSessionStore.shared.refreshToken = response.refreshToken
                    print("서버 로그인 성공 — AccessToken 저장 완료")
                })
                .flatMap { _ in
                    // 로그인 완료 후 → 스페이스 목록 요청
                    print("[API] 내 스페이스 목록 요청 시작")
                    return spaceRepo.fetchMySpaces()
                }
                .observe(on: MainScheduler.instance)
                .subscribe(
                    onSuccess: { joinedSpaces in
                        print("[API] 내 스페이스 목록 응답 수신 — count: \(joinedSpaces.count)")

                        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                              let delegate = scene.delegate as? SceneDelegate,
                              let window = delegate.window else { return }

                        let nextVC: UIViewController
                        if joinedSpaces.isEmpty {
                            print("사용자가 속한 Space 없음 → SpaceSelectViewController로 이동")
                            nextVC = SpaceSelectViewController()
                        } else {
                            print("사용자가 속한 Space 있음 → CalendarViewController로 이동")
                            nextVC = CalendarViewController()
                        }

                        UIView.transition(
                            with: window,
                            duration: 0.4,
                            options: .transitionCrossDissolve,
                            animations: {
                                window.rootViewController = nextVC
                            },
                            completion: nil
                        )
                    },
                    onFailure: { error in
                        print("로그인 or 스페이스 조회 실패:", error.localizedDescription)
                        let alert = UIAlertController(
                            title: "로그인 실패",
                            message: error.localizedDescription,
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(title: "확인", style: .cancel))
                        self.present(alert, animated: true)
                    }
                )
                .disposed(by: disposeBag)
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
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension SignUpViewController: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        view.window!
    }
}
