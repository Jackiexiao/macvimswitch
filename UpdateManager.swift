import Foundation
import AppKit

class UpdateManager {
    static let shared = UpdateManager()

    private let currentVersion: String
    private let githubRepo = "jackiexiao/macvimswitch"
    private var updateCheckTimer: Timer?

    private init() {
        // Read version from Info.plist
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            currentVersion = version
        } else {
            currentVersion = "0.0.0"
        }
    }

    // Start automatic update checking (every 24 hours)
    func startPeriodicCheck() {
        // Check immediately on startup
        checkForUpdates(silent: true)

        // Then check every 24 hours
        updateCheckTimer = Timer.scheduledTimer(withTimeInterval: 86400, repeats: true) { [weak self] _ in
            self?.checkForUpdates(silent: true)
        }
    }

    func stopPeriodicCheck() {
        updateCheckTimer?.invalidate()
        updateCheckTimer = nil
    }

    // Manual check (triggered by user)
    func checkForUpdates(silent: Bool = false) {
        Task {
            do {
                if let latestVersion = try await fetchLatestVersion() {
                    if isNewerVersion(latestVersion, than: currentVersion) {
                        await MainActor.run {
                            self.showUpdateAlert(newVersion: latestVersion)
                        }
                    } else if !silent {
                        await MainActor.run {
                            self.showNoUpdateAlert()
                        }
                    }
                }
            } catch {
                if !silent {
                    await MainActor.run {
                        self.showErrorAlert(error: error)
                    }
                }
            }
        }
    }

    private func fetchLatestVersion() async throws -> String? {
        let url = URL(string: "https://api.github.com/repos/\(githubRepo)/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw UpdateError.networkError
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tagName = json["tag_name"] as? String else {
            throw UpdateError.parseError
        }

        // Remove 'v' prefix if present
        return tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
    }

    private func isNewerVersion(_ newVersion: String, than currentVersion: String) -> Bool {
        let newComponents = newVersion.split(separator: ".").compactMap { Int($0) }
        let currentComponents = currentVersion.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(newComponents.count, currentComponents.count) {
            let new = i < newComponents.count ? newComponents[i] : 0
            let current = i < currentComponents.count ? currentComponents[i] : 0

            if new > current {
                return true
            } else if new < current {
                return false
            }
        }
        return false
    }

    private func showUpdateAlert(newVersion: String) {
        let alert = NSAlert()
        alert.messageText = "新版本可用"
        alert.informativeText = "MacVimSwitch \(newVersion) 已发布。当前版本: \(currentVersion)\n\n是否前往下载?"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "下载")
        alert.addButton(withTitle: "稍后提醒")
        alert.addButton(withTitle: "忽略此版本")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Open releases page
            if let url = URL(string: "https://github.com/\(githubRepo)/releases/latest") {
                NSWorkspace.shared.open(url)
            }
        } else if response == .alertThirdButtonReturn {
            // Save ignored version
            UserDefaults.standard.set(newVersion, forKey: "IgnoredVersion")
        }
    }

    private func showNoUpdateAlert() {
        let alert = NSAlert()
        alert.messageText = "已是最新版本"
        alert.informativeText = "您正在使用最新版本 \(currentVersion)"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "好的")
        alert.runModal()
    }

    private func showErrorAlert(error: Error) {
        let alert = NSAlert()
        alert.messageText = "检查更新失败"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "好的")
        alert.runModal()
    }

    func shouldCheckVersion(_ version: String) -> Bool {
        // Don't check if this version is ignored
        if let ignoredVersion = UserDefaults.standard.string(forKey: "IgnoredVersion"),
           ignoredVersion == version {
            return false
        }
        return true
    }
}

enum UpdateError: LocalizedError {
    case networkError
    case parseError

    var errorDescription: String? {
        switch self {
        case .networkError:
            return "无法连接到更新服务器"
        case .parseError:
            return "无法解析版本信息"
        }
    }
}
