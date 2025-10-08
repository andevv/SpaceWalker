//
//  SceneDelegate.swift
//  SpaceWalker
//
//  Created by andev on 9/27/25.
//

import UIKit
import RxSwift

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    
    private let disposeBag = DisposeBag()

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        window = UIWindow(windowScene: windowScene)
        
        // 로그인 여부 확인
        guard let token = UserSessionStore.shared.accessToken, !token.isEmpty else {
            window?.rootViewController = SignUpViewController()
            window?.makeKeyAndVisible()
            return
        }
        
        // 로그인 상태 → 서버에서 내 Space 목록 조회
        let repo = SpaceRepository()
        repo.fetchMySpaces()
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] joinedSpaces in
                guard let self = self else { return }
                
                if joinedSpaces.isEmpty {
                    // Space 없음 → 선택 화면으로 이동
                    self.setRoot(SpaceSelectViewController())
                } else {
                    // 이미 Space 존재 → 메인 캘린더로 이동
                    let mainTab = MainTabBarController()
                    mainTab.selectedIndex = 0
                    self.setRoot(mainTab)
                }
            }, onFailure: { [weak self] _ in
                // 실패 시 기본 SignUp 화면으로 복구
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

