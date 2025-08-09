import Foundation

class UserPreferences {
    static let shared = UserPreferences()
    private let defaults = UserDefaults.standard
    
    // 键名常量
    private struct Keys {
        static let allowedApps = "allowedApps"
        static let selectedInputMethod = "selectedInputMethod"
        static let selectedEnglishInputMethod = "selectedEnglishInputMethod"
        static let useShiftSwitch = "useShiftSwitch"
        static let launchAtLogin = "launchAtLogin"
    }
    
    // Esc 生效的应用
    var allowedApps: Set<String> {
        get {
            let array = defaults.array(forKey: Keys.allowedApps) as? [String] ?? []
            return Set(array)
        }
        set {
            defaults.set(Array(newValue), forKey: Keys.allowedApps)
        }
    }
    
    // 选择的中文输入法
    var selectedInputMethod: String? {
        get {
            defaults.string(forKey: Keys.selectedInputMethod)
        }
        set {
            defaults.set(newValue, forKey: Keys.selectedInputMethod)
        }
    }
    
    // 选择的英文输入法
    var selectedEnglishInputMethod: String {
        get {
            defaults.string(forKey: Keys.selectedEnglishInputMethod) ?? "com.apple.keylayout.ABC"
        }
        set {
            defaults.set(newValue, forKey: Keys.selectedEnglishInputMethod)
        }
    }
    
    // 是否使用 shift 切换输入法
    var useShiftSwitch: Bool {
        get {
            defaults.bool(forKey: Keys.useShiftSwitch)
        }
        set {
            defaults.set(newValue, forKey: Keys.useShiftSwitch)
        }
    }
    
    // 是否开机启动
    var launchAtLogin: Bool {
        get {
            defaults.bool(forKey: Keys.launchAtLogin)
        }
        set {
            defaults.set(newValue, forKey: Keys.launchAtLogin)
        }
    }
    
    private init() {
        // 设置默认值
        if defaults.object(forKey: Keys.allowedApps) == nil {
            allowedApps = Set([
                "com.apple.Terminal",
                "com.microsoft.VSCode",
                "com.vim.MacVim",
                "com.exafunction.windsurf",
                "md.obsidian",
                "dev.warp.Warp-Stable",
                "com.todesktop.230313mzl4w4u92"
            ])
        }
        
        if defaults.object(forKey: Keys.useShiftSwitch) == nil {
            useShiftSwitch = true
        }
        
        if defaults.object(forKey: Keys.selectedEnglishInputMethod) == nil {
            selectedEnglishInputMethod = "com.apple.keylayout.ABC"
        }
    }
}
