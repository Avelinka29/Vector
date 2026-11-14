import GoogleSignIn
import UIKit

@MainActor
enum GoogleSignInService {
    static func idToken() async throws -> String {
        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String,
              let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
              var presenter = scene.windows.first(where: \.isKeyWindow)?.rootViewController
        else {
            throw AuthenticationError.unavailable
        }
        while let presented = presenter.presentedViewController {
            presenter = presented
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
            guard let token = result.user.idToken?.tokenString else {
                throw AuthenticationError.unavailable
            }
            return token
        } catch {
            if (error as NSError).domain == kGIDSignInErrorDomain,
               (error as NSError).code == GIDSignInError.canceled.rawValue {
                throw CancellationError()
            }
            throw error
        }
    }
}
