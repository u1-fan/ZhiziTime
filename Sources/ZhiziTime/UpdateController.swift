import Foundation

#if ZHIZI_ENABLE_SPARKLE
import Sparkle
#endif

@MainActor
final class AppUpdater {
    #if ZHIZI_ENABLE_SPARKLE
    private let controller: SPUStandardUpdaterController?

    init() {
        let publicKey = (Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let publicKey, !publicKey.isEmpty else {
            controller = nil
            return
        }
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    var isAvailable: Bool { controller != nil }

    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }
    #else
    init() {}

    var isAvailable: Bool { false }

    func checkForUpdates() {}
    #endif
}
