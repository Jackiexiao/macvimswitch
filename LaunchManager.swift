import Cocoa
import ServiceManagement

class LaunchManager {
    static let shared = LaunchManager()
    
    private init() {
        // 初始化时同步开机启动状态到 UserPreferences
        UserPreferences.shared.launchAtLogin = isLaunchAtLoginEnabled()
    }
    
    func isLaunchAtLoginEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            // 对于旧版本的 macOS，检查登录项
            if let loginItems = try? FileManager.default.contentsOfDirectory(atPath: "/Users/\(NSUserName())/Library/Application Support/com.apple.backgroundtaskmanagementagent/BackgroundItems.btm") {
                let isEnabled = loginItems.contains(where: { $0.contains("MacVimSwitch") })
                print("检查开机启动状态: \(isEnabled)")
                return isEnabled
            }
            return false
        }
    }
    
    func toggleLaunchAtLogin() -> Bool {
        if #available(macOS 13.0, *) {
            do {
                let service = SMAppService.mainApp
                if service.status == .enabled {
                    try service.unregister()
                } else {
                    try service.register()
                }
                
                // 验证操作是否成功
                let newState = isLaunchAtLoginEnabled()
                UserPreferences.shared.launchAtLogin = newState
                return true
            } catch {
                print("设置开机启动失败: \(error)")
                return false
            }
        } else {
            // 对于旧版本的 macOS，使用 AppleScript
            let bundlePath = Bundle.main.bundlePath
            let currentState = isLaunchAtLoginEnabled()
            var success = false

            if currentState {
                // 使用 AppleScript 移除登录项
                let script = """
                    tell application "System Events"
                        delete login item "MacVimSwitch"
                    end tell
                """

                var error: NSDictionary?
                if let scriptObject = NSAppleScript(source: script) {
                    scriptObject.executeAndReturnError(&error)
                    if let error = error {
                        print("Error removing login item: \(error)")
                    } else {
                        success = true
                    }
                }
            } else {
                // 使用 AppleScript 添加登录项
                let script = """
                    tell application "System Events"
                        make new login item at end with properties {path:"\(bundlePath)", hidden:false}
                    end tell
                """

                var error: NSDictionary?
                if let scriptObject = NSAppleScript(source: script) {
                    scriptObject.executeAndReturnError(&error)
                    if let error = error {
                        print("Error adding login item: \(error)")
                    } else {
                        success = true
                    }
                }
            }

            // 验证操作是否成功
            let newState = isLaunchAtLoginEnabled()
            success = success && (newState != currentState)
            
            // 更新 UserPreferences
            if success {
                UserPreferences.shared.launchAtLogin = newState
            }
            
            return success
        }
    }
}
