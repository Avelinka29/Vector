//
//  VectorApp.swift
//  Vector
//
//  Created by Avelina Maksimchik on 06.08.2026.
//

import SwiftUI
import FirebaseCore
import GoogleSignIn

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        NotificationService.shared.configure()
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        NotificationService.shared.registerAPNsToken(deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        NotificationService.shared.didFailToRegister(error: error)
    }
}

@main
struct VectorApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var passwordResetLink: PasswordResetLink?

    @State private var emailVerificationLink: EmailVerificationLink?

    var body: some Scene {
        WindowGroup {
            ContentView()
                .sheet(item: $passwordResetLink) { link in
                    PasswordResetView(link: link)
                }
                .sheet(item: $emailVerificationLink) { link in
                    EmailVerificationView(link: link)
                }
                .onOpenURL { url in
                    if let link = PasswordResetLink(url: url) {
                        passwordResetLink = link
                    } else if let link = EmailVerificationLink(url: url) {
                        emailVerificationLink = link
                    } else {
                        _ = GIDSignIn.sharedInstance.handle(url)
                    }
                }
        }
    }
}
