//
//  MainTabBarController.swift
//  SpaceWalker
//
//  Created by andev on 9/29/25.
//

import UIKit

final class MainTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabs()
    }

    private func setupTabs() {
        // 0번 탭: Calendar
        let calendarVC = CalendarViewController()
        let calendarNav = UINavigationController(rootViewController: calendarVC)
        calendarNav.tabBarItem = UITabBarItem(
            title: "Calendar",
            image: UIImage(systemName: "calendar"),
            selectedImage: UIImage(systemName: "calendar.fill")
        )

        // 1번 탭: Feed
        let feedVC = FeedViewController()
        let feedNav = UINavigationController(rootViewController: feedVC)
        feedNav.tabBarItem = UITabBarItem(
            title: "Feed",
            image: UIImage(systemName: "square.grid.2x2"),
            selectedImage: UIImage(systemName: "square.grid.2x2.fill")
        )

        viewControllers = [calendarNav, feedNav]
    }
}
