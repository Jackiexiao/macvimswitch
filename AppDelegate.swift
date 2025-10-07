import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate, KeyboardManagerDelegate {
    let statusBarManager = StatusBarManager()
    // 存储允许的应用bundle identifiers
    var allowedApps: Set<String> {
        get { UserPreferences.shared.allowedApps }
        set { UserPreferences.shared.allowedApps = newValue }
    }
    // 用于存储系统中的应用列表
    var systemApps: [(name: String, bundleId: String)] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("应用程序开始初始化...")

        // 确保应用程序被激活
        NSApp.activate(ignoringOtherApps: true)
        print("应用程序已激活")

        // 确保应用不会随终端退出
        ProcessInfo.processInfo.enableSuddenTermination()
        print("已启用突然终止")

        // 加载系统应用列表
        loadSystemApps()
        print("已加载系统应用列表，共 \(systemApps.count) 个应用")

        // 设置代理
        KeyboardManager.shared.delegate = self
        statusBarManager.appDelegate = self
        print("已设置键盘管理器代理")

        // 设置状态栏和菜单
        print("开始设置状态栏和菜单...")
        DispatchQueue.main.async { [weak self] in
            self?.statusBarManager.setupStatusBarItem()
            print("状态栏和菜单设置完成")
        }

        // 启动键盘管理器
        print("开始启动键盘管理器...")
        KeyboardManager.shared.start()
        print("键盘管理器启动完成")

        // 启动自动更新检查
        UpdateManager.shared.startPeriodicCheck()
        print("已启动自动更新检查")

        // 显示初始使用提示
        DispatchQueue.main.async { [weak self] in
            self?.showInitialInstructions()
            print("初始使用提示已显示")
        }

        print("应用程序初始化完成")
    }

    // 加载系统应用列表
    private func loadSystemApps() {
        let workspace = NSWorkspace.shared

        // 获取常用应用程序目录
        let appDirs = [
            "/Applications",
            "~/Applications",
            "/System/Applications"
        ].map { NSString(string: $0).expandingTildeInPath }

        var apps: [(name: String, bundleId: String)] = []

        // 遍历应用程序目录
        for dir in appDirs {
            if let contents = try? FileManager.default.contentsOfDirectory(atPath: dir) {
                for item in contents {
                    if item.hasSuffix(".app") {
                        let path = (dir as NSString).appendingPathComponent(item)
                        if let bundle = Bundle(path: path),
                           let bundleId = bundle.bundleIdentifier,
                           let appName = bundle.infoDictionary?["CFBundleName"] as? String {
                            apps.append((name: appName, bundleId: bundleId))
                        }
                    }
                }
            }
        }

        // 添加当前正在运行的应用
        let runningApps = workspace.runningApplications
        for app in runningApps {
            if let bundleId = app.bundleIdentifier,
               let appName = app.localizedName,
               !apps.contains(where: { $0.bundleId == bundleId }) {
                apps.append((name: appName, bundleId: bundleId))
            }
        }

        // 按应用名称排序
        systemApps = apps.sorted { $0.name < $1.name }
    }

    @objc func toggleApp(_ sender: NSMenuItem) {
        guard let bundleId = sender.representedObject as? String else { return }

        if allowedApps.contains(bundleId) {
            allowedApps.remove(bundleId)
            sender.state = .off
        } else {
            allowedApps.insert(bundleId)
            sender.state = .on
        }
    }

    @objc func refreshAppList() {
        loadSystemApps()
        statusBarManager.createAndShowMenu()
    }

    // 检查当前应用是否允许使用ESC切换输入法
    private func isCurrentAppAllowed() -> Bool {
        if let frontmostApp = NSWorkspace.shared.frontmostApplication {
            return allowedApps.contains(frontmostApp.bundleIdentifier ?? "")
        }
        return false
    }

    // 在切换输入法前检查当前应用
    func shouldSwitchInputSource() -> Bool {
        return isCurrentAppAllowed()
    }

    // 实现代理方法
    func keyboardManagerDidUpdateState() {
        statusBarManager.updateStatusBarIcon()
    }

    private func showInitialInstructions() {
        let alert = NSAlert()
        alert.messageText = "MacVimSwitch 使用说明"
        alert.informativeText = """
            重要提示：
            1. 先关闭输入法中的"使用 Shift 切换中英文"选项，否则会产生冲突
            2. 具体操作：打开输入法偏好设置 → 关闭"使用 Shift 切换中英文"

            功能说明：
            1. 按 ESC 键会自动切换到选定的英文输入法（仅在指定的应用中生效）
            2. 按 Shift 键可以在中英文输入法之间切换（可在菜单栏中关闭）
            3. 提示：在 Mac 上，CapsLock 短按可以切换输入法，长按才是锁定大写
            4. 现在您可以选择英文输入法（默认ABC）和中文输入法

            配置说明：
            1. 点击菜单栏图标 → 选择英文输入法，可以选择您优先的英文输入法
            2. 点击菜单栏图标 → 选择中文输入法，可以选择您优先的中文输入法
            3. 点击菜单栏图标 → 启用的应用，可以选择需要启用ESC切换功能的应用
            4. 如果没有看到某个应用，可以点击"刷新应用列表"更新
            """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "我已了解")

        DispatchQueue.main.async {
            alert.runModal()
        }
    }
}
