import Cocoa

class StatusBarManager {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var menu: NSMenu?
    weak var appDelegate: AppDelegate?

    func setupStatusBarItem() {
        if let button = statusItem.button {
            updateStatusBarIcon()
            createAndShowMenu()
            button.isEnabled = true
        } else {
            print("错误：无法创建状态栏按钮")
        }
    }

    func updateStatusBarIcon() {
        guard let button = statusItem.button else {
            print("Status item button not found")
            return
        }

        if KeyboardManager.shared.useShiftSwitch {
            button.image = NSImage(systemSymbolName: "keyboard.badge.ellipsis", accessibilityDescription: "MacVimSwitch (Shift Enabled)")
        } else {
            button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "MacVimSwitch")
        }

        button.isEnabled = true
    }

    func createAndShowMenu() {
        let newMenu = NSMenu()

        let homepageItem = NSMenuItem(title: "使用说明", action: #selector(openHomepage), keyEquivalent: "")
        homepageItem.target = self
        newMenu.addItem(homepageItem)

        newMenu.addItem(NSMenuItem.separator())

        // 添加输入法选择子菜单
        let inputMethodMenu = NSMenu()
        let inputMethodItem = NSMenuItem(title: "选择中文输入法", action: nil, keyEquivalent: "")
        inputMethodItem.submenu = inputMethodMenu

        // 获取所有输入法并添加到子菜单
        if let inputMethods = InputMethodManager.shared.getAvailableInputMethods() {
            print("当前保存的输入法: \(KeyboardManager.shared.lastInputSource ?? "nil")")
            print("UserPreferences中的输入法: \(UserPreferences.shared.selectedInputMethod ?? "nil")")
            
            for (sourceId, name) in inputMethods {
                print("添加输入法菜单项: \(name) (\(sourceId))")
                let item = NSMenuItem(
                    title: name,
                    action: #selector(selectInputMethod(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = sourceId
                // 检查是否是当前选中的输入法
                if sourceId == KeyboardManager.shared.lastInputSource {
                    print("设置选中状态: \(name) (\(sourceId))")
                    item.state = .on
                }
                inputMethodMenu.addItem(item)
            }
        }

        newMenu.addItem(inputMethodItem)
        newMenu.addItem(NSMenuItem.separator())

        // 添加应用列表子菜单
        if let delegate = appDelegate {
            let appsMenu = NSMenu()
            let appsMenuItem = NSMenuItem(title: "Esc生效的应用", action: nil, keyEquivalent: "")
            appsMenuItem.submenu = appsMenu

            // 添加所有应用到子菜单
            for app in delegate.systemApps {
                let item = NSMenuItem(title: app.name, action: #selector(AppDelegate.toggleApp(_:)), keyEquivalent: "")
                item.state = delegate.allowedApps.contains(app.bundleId) ? .on : .off
                item.representedObject = app.bundleId
                item.target = delegate
                appsMenu.addItem(item)
            }

            // 添加刷新应用列表选项
            appsMenu.addItem(NSMenuItem.separator())
            let refreshItem = NSMenuItem(title: "刷新应用列表", action: #selector(AppDelegate.refreshAppList), keyEquivalent: "r")
            refreshItem.target = delegate
            appsMenu.addItem(refreshItem)

            newMenu.addItem(appsMenuItem)
            newMenu.addItem(NSMenuItem.separator())
        }

        // 修改 Shift 切换选项的文字
        let shiftSwitchItem = NSMenuItem(
            title: "使用 Shift 切换入法",
            action: #selector(toggleShiftSwitch),
            keyEquivalent: ""
        )
        shiftSwitchItem.target = self
        shiftSwitchItem.state = KeyboardManager.shared.useShiftSwitch ? .on : .off
        newMenu.addItem(shiftSwitchItem)

        newMenu.addItem(NSMenuItem.separator())

        // 添加开机启动选项
        let launchAtLoginItem = NSMenuItem(
            title: "开机启动",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchAtLoginItem.target = self
        launchAtLoginItem.state = UserPreferences.shared.launchAtLogin ? .on : .off
        newMenu.addItem(launchAtLoginItem)

        newMenu.addItem(NSMenuItem.separator())

        // 添加退出选项
        let quitItem = NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = NSApp
        newMenu.addItem(quitItem)

        statusItem.menu = newMenu
        self.menu = newMenu
    }

    @objc private func openHomepage() {
        if let url = URL(string: "https://github.com/Jackiexiao/macvimswitch") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func toggleShiftSwitch() {
        KeyboardManager.shared.useShiftSwitch = !KeyboardManager.shared.useShiftSwitch
        UserPreferences.shared.useShiftSwitch = KeyboardManager.shared.useShiftSwitch
        updateStatusBarIcon()
        createAndShowMenu()
    }

    @objc private func selectInputMethod(_ sender: NSMenuItem) {
        guard let sourceId = sender.representedObject as? String else { return }
        print("[StatusBarManager] 选择输入法: \(sourceId)")
        KeyboardManager.shared.setLastInputSource(sourceId)
        createAndShowMenu()  // 重新创建菜单以更新选中状态
    }

    @objc private func toggleLaunchAtLogin() {
        if LaunchManager.shared.toggleLaunchAtLogin() {
            // 操作成功，重新创建菜单以更新状态
            createAndShowMenu()
        } else {
            // 操作失败，显示错误提示
            let alert = NSAlert()
            alert.messageText = "设置失败"
            alert.informativeText = "无法修改开机启动设置，请检查系统权限。"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "确定")
            alert.runModal()
        }
    }

    @objc private func quitApp() {
        KeyboardManager.shared.disableEventTap()
        NSApplication.shared.terminate(self)
    }
}
