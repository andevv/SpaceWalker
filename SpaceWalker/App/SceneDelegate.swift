//
//  SceneDelegate.swift
//  SpaceWalker
//
//  Created by andev on 9/27/25.
//

import UIKit
import RxSwift
import OSLog

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    
    private let disposeBag = DisposeBag()
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "", category: "SceneDelegate")

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        window = UIWindow(windowScene: windowScene)
        
//        let window = UIWindow(windowScene: windowScene)
//        window.rootViewController = UINavigationController(rootViewController: SpaceSelectViewController())
//        window.makeKeyAndVisible()
//        self.window = window
//    }
        
        
        // 재인증(로그아웃 후 재로그인) 필요 시 실행될 콜백 등록
        NetworkManager.shared.onRequireReauthentication = { [weak self] in
            DispatchQueue.main.async {
                UserSessionStore.shared.clearSession()
                let signUpVC = SignUpViewController()
                self?.setRoot(signUpVC)
            }
        }
        
        // 로그인 여부 확인
        guard let token = UserSessionStore.shared.accessToken, !token.isEmpty else {
            logger.info("로그인되지 않은 상태 — SignUpViewController 표시")
            window?.rootViewController = SignUpViewController()
            window?.makeKeyAndVisible()
            return
        }
        
        logger.info("로그인된 사용자 — accessToken 존재. 서버로 내 Space 목록 요청 시작")

        let repo = SpaceRepository()
        repo.fetchMySpaces()
            .observe(on: MainScheduler.instance)
            .do(onSubscribe: { [weak self] in
                self?.logger.debug("[API] GET /api/v1/space/my-space 요청 시작")
            })
            .subscribe(onSuccess: { [weak self] joinedSpaces in
                guard let self = self else { return }

                self.logger.info("[API] Space 목록 조회 성공 — count: \(joinedSpaces.count)")

                if joinedSpaces.isEmpty {
                    self.logger.info("사용자가 속한 Space 없음 — SpaceSelectViewController로 이동")
                    self.setRoot(SpaceSelectViewController())
                } else {
                    self.logger.info("사용자가 \(joinedSpaces.count)개의 Space에 속해 있음 — Calendar로 이동")
                    let mainTab = MainTabBarController()
                    mainTab.selectedIndex = 0
                    self.setRoot(mainTab)
                }
            }, onFailure: { [weak self] error in
                self?.logger.error("[API] Space 목록 조회 실패: \(error.localizedDescription)")
                self?.setRoot(SignUpViewController())
            })
            .disposed(by: disposeBag)
    }
    
    private func setRoot(_ vc: UIViewController) {
        guard let window else { return }
        UIView.transition(
            with: window,
            duration: 0.4,
            options: .transitionCrossDissolve,
            animations: {
                self.logger.debug("RootViewController 전환: \(String(describing: type(of: vc)))")
                window.rootViewController = vc
            },
            completion: nil
        )
        window.makeKeyAndVisible()
    }


    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }


}

