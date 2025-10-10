import Cocoa
import Carbon
import Foundation
import ServiceManagement

// 添加 InputSource 类
class InputSource: Equatable {
    static func == (lhs: InputSource, rhs: InputSource) -> Bool {
        return lhs.id == rhs.id
    }

    let tisInputSource: TISInputSource

    var id: String {
        return tisInputSource.id
    }

    var name: String {
        return tisInputSource.name
    }

    var isCJKV: Bool {
        if let lang = tisInputSource.sourceLanguages.first {
            return lang == "ko" || lang == "ja" || lang == "vi" || lang.hasPrefix("zh")
        }
        return false
    }

    init(tisInputSource: TISInputSource) {
        self.tisInputSource = tisInputSource
    }

    func select() {
        let currentSource = InputSourceManager.getCurrentSource()
        if currentSource.id == self.id { return }

        // 简化 CJKV 输入法切换逻辑
        if self.isCJKV {
            switchCJKVSource()
        } else {
            selectWithRetry()
        }
    }

    // 添加重试机制的切换方法
    private func selectWithRetry(maxAttempts: Int = 2) {
        for attempt in 1...maxAttempts {
            TISSelectInputSource(tisInputSource)
            usleep(InputSourceManager.uSeconds)

            // 验证切换是否成功
            if InputSourceManager.getCurrentSource().id == self.id {
                // 强制刷新输入上下文以确保立即生效
                InputSourceManager.forceRefreshInputContext()
                return
            }

            // 如果不是最后一次尝试，多等待一段时间再重试
            if attempt < maxAttempts {
                usleep(InputSourceManager.uSeconds)
            }
        }

        // 即使失败也尝试刷新一次
        InputSourceManager.forceRefreshInputContext()
    }

    private func switchCJKVSource() {
        // 尝试直接切换到目标输入法
        TISSelectInputSource(tisInputSource)
        usleep(InputSourceManager.uSeconds)

        // 验证切换是否成功
        if InputSourceManager.getCurrentSource().id == self.id {
            // 即使切换成功，也强制刷新输入上下文以确保立即生效
            InputSourceManager.forceRefreshInputContext()
            return
        }

        // 如果切换失败，尝试通过非 CJKV 输入法中转
        if let nonCJKV = InputSourceManager.nonCJKVSource() {
            TISSelectInputSource(nonCJKV.tisInputSource)
            usleep(InputSourceManager.uSeconds)
            TISSelectInputSource(tisInputSource)
            usleep(InputSourceManager.uSeconds)

            // 再次验证
            if InputSourceManager.getCurrentSource().id == self.id {
                // 强制刷新输入上下文
                InputSourceManager.forceRefreshInputContext()
                return
            }

            // 最后一次尝试：等待更长时间再切换
            usleep(InputSourceManager.uSeconds * 2)
            TISSelectInputSource(tisInputSource)
            usleep(InputSourceManager.uSeconds)

            // 最后也强制刷新一次
            InputSourceManager.forceRefreshInputContext()
        }
    }
}

// 修改 InputSourceManager 类
class InputSourceManager {
    static var inputSources: [InputSource] = []
    static var uSeconds: UInt32 = 20000  // 增加到20ms以提高稳定性
    static var keyboardOnly: Bool = true

    static func initialize() {
        let inputSourceNSArray = TISCreateInputSourceList(nil, false)
            .takeRetainedValue() as NSArray
        var inputSourceList = inputSourceNSArray as! [TISInputSource]
        if self.keyboardOnly {
            inputSourceList = inputSourceList.filter({ $0.category == TISInputSource.Category.keyboardInputSource })
        }

        inputSources = inputSourceList.filter({ $0.isSelectable })
            .map { InputSource(tisInputSource: $0) }
    }

    static func getCurrentSource() -> InputSource {
        return InputSource(
            tisInputSource: TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        )
    }

    static func getInputSource(name: String) -> InputSource? {
        return inputSources.first(where: { $0.id == name })
    }

    static func nonCJKVSource() -> InputSource? {
        return inputSources.first(where: { !$0.isCJKV })
    }

    static func selectPrevious() {
        let shortcut = getSelectPreviousShortcut()
        if (shortcut == nil) {
            print("Shortcut to select previous input source does not exist")
            return
        }

        let src = CGEventSource(stateID: .hidSystemState)
        let key = CGKeyCode(shortcut!.0)
        let flag = CGEventFlags(rawValue: shortcut!.1)

        let down = CGEvent(keyboardEventSource: src, virtualKey: key, keyDown: true)!
        down.flags = flag
        down.post(tap: .cghidEventTap)

        let up = CGEvent(keyboardEventSource: src, virtualKey: key, keyDown: false)!
        up.post(tap: .cghidEventTap)
        usleep(uSeconds)
    }

    static func getSelectPreviousShortcut() -> (Int, UInt64)? {
        guard let dict = UserDefaults.standard.persistentDomain(forName: "com.apple.symbolichotkeys"),
              let symbolichotkeys = dict["AppleSymbolicHotKeys"] as? NSDictionary,
              let symbolichotkey = symbolichotkeys["60"] as? NSDictionary,
              (symbolichotkey["enabled"] as? NSNumber)?.intValue == 1,
              let value = symbolichotkey["value"] as? NSDictionary,
              let parameters = value["parameters"] as? NSArray else {
            return nil
        }

        return ((parameters[1] as! NSNumber).intValue,
                (parameters[2] as! NSNumber).uint64Value)
    }

    static func isCJKVSource(_ source: InputSource) -> Bool {
        return source.isCJKV
    }

    static func getSourceID(_ source: InputSource) -> String {
        return source.id
    }

    static func getNonCJKVSource() -> InputSource? {
        return nonCJKVSource()
    }

    // 强制刷新输入上下文，确保输入法切换立即生效
    static func forceRefreshInputContext() {
        // 策略1: 通过多次重新选择当前输入法来强制系统刷新
        // 这个方法比应用切换更轻量，但同样有效
        let current = TISCopyCurrentKeyboardInputSource().takeRetainedValue()

        // 第一次：立即重选
        TISSelectInputSource(current)
        usleep(3000) // 3ms

        // 第二次：再次重选以确保生效
        TISSelectInputSource(current)
        usleep(3000) // 3ms

        // 策略2: 发送一个特殊的"空操作"键盘事件序列
        // 使用 NSEventType.appKitDefined 或类似的无副作用事件
        // 通过快速的修饰键按下-释放来触发输入上下文更新
        sendRefreshKeySequence()
    }

    // 发送一个特殊的按键序列来刷新输入上下文
    // 使用极短的修饰键脉冲，几乎不会被用户察觉
    private static func sendRefreshKeySequence() {
        let source = CGEventSource(stateID: .hidSystemState)

        // 使用 Function 键 (0x3F) - 这是最不会干扰用户输入的修饰键
        // 因为单独按 Fn 键通常不会触发任何操作
        if let fnDown = CGEvent(keyboardEventSource: source, virtualKey: 0x3F, keyDown: true) {
            fnDown.post(tap: .cghidEventTap)
            usleep(500) // 0.5ms - 极短的延迟

            if let fnUp = CGEvent(keyboardEventSource: source, virtualKey: 0x3F, keyDown: false) {
                fnUp.post(tap: .cghidEventTap)
            }
        }

        usleep(2000) // 2ms - 让系统处理事件
    }
}

// 添加 TISInputSource 扩展
extension TISInputSource {
    enum Category {
        static var keyboardInputSource: String {
            return kTISCategoryKeyboardInputSource as String
        }
    }

    private func getProperty(_ key: CFString) -> AnyObject? {
        let cfType = TISGetInputSourceProperty(self, key)
        if (cfType != nil) {
            return Unmanaged<AnyObject>.fromOpaque(cfType!).takeUnretainedValue()
        }
        return nil
    }

    var id: String {
        return getProperty(kTISPropertyInputSourceID) as! String
    }

    var name: String {
        return getProperty(kTISPropertyLocalizedName) as! String
    }

    var category: String {
        return getProperty(kTISPropertyInputSourceCategory) as! String
    }

    var isSelectable: Bool {
        return getProperty(kTISPropertyInputSourceIsSelectCapable) as! Bool
    }

    var sourceLanguages: [String] {
        return getProperty(kTISPropertyInputSourceLanguages) as! [String]
    }
}

// 添加代理协议
protocol KeyboardManagerDelegate: AnyObject {
    func keyboardManagerDidUpdateState()
    func shouldSwitchInputSource() -> Bool
}

class KeyboardManager {
    static let shared = KeyboardManager()
    weak var delegate: KeyboardManagerDelegate?  // 添加代理属性
    private var eventTap: CFMachPort?

    private enum KeyCode {
        static let esc: Int64 = 0x35
        static let j: Int64 = 0x26
        static let k: Int64 = 0x28
    }

    var englishInputSource: String {
        get { UserPreferences.shared.selectedEnglishInputMethod }
        set { UserPreferences.shared.selectedEnglishInputMethod = newValue }
    }
    var useShiftSwitch: Bool {
        get { UserPreferences.shared.useShiftSwitch }
        set {
            UserPreferences.shared.useShiftSwitch = newValue
            delegate?.keyboardManagerDidUpdateState()
        }
    }
    var useJkSwitch: Bool {
        get { UserPreferences.shared.useJkSwitch }
        set {
            UserPreferences.shared.useJkSwitch = newValue
            delegate?.keyboardManagerDidUpdateState()
        }
    }
    var lastShiftPressTime: TimeInterval = 0

    // 添加属性来跟踪上一个输入法
    private(set) var lastInputSource: String? {
        get {
            let value = UserPreferences.shared.selectedInputMethod
            print("[KeyboardManager] 获取 lastInputSource: \(value ?? "nil")")
            return value
        }
        set {
            print("[KeyboardManager] 设置 lastInputSource: \(newValue ?? "nil")")
            UserPreferences.shared.selectedInputMethod = newValue
        }
    }
    private var isShiftPressed = false
    private var lastKeyDownTime: TimeInterval = 0  // 修改变量名使其更明确
    private var isKeyDown = false  // 添加新变量跟踪是否有按键被按下

    private var keyDownTime: TimeInterval = 0  // 记录最后一次按键时间
    private var lastFlagChangeTime: TimeInterval = 0  // 记录最一次修饰键变化时

    private var keySequence: [TimeInterval] = []  // 记录按键序列的时间戳
    private var lastKeyEventTime: TimeInterval = 0  // 记录最后一次按键事件的时间
    private static let KEY_SEQUENCE_WINDOW: TimeInterval = 0.3  // 按键序列的时间窗口

    private var shiftPressStartTime: TimeInterval = 0  // 记录 Shift 下的开始时间
    private var hasOtherKeysDuringShift = false       // 记录 Shift 按下期间是否有其他键按下
    private var waitingForKAfterJ = false             // 记录是否等待 k 以组成 jk 序列
    private var lastJKeyTime: TimeInterval = 0        // 记录最近一次 j 键的时间
    private static let JK_SEQUENCE_WINDOW: TimeInterval = 0.35

    private init() {
        // 从 UserPreferences 加载配置
        useShiftSwitch = UserPreferences.shared.useShiftSwitch
        useJkSwitch = UserPreferences.shared.useJkSwitch
        lastInputSource = UserPreferences.shared.selectedInputMethod
    }

    func start() {
        InputSourceManager.initialize()
        initializeInputSources()
        setupEventTap()

        // 检查当前输入法，如果是英文且有保存的上一个输入法，则更新 lastInputSource
        let currentSource = InputSourceManager.getCurrentSource()
        if currentSource.id == englishInputSource,
           let savedSource = UserPreferences.shared.selectedInputMethod {
            lastInputSource = savedSource
        } else if currentSource.id != englishInputSource {
            // 如果当前不是英文，就保存当前输入法
            lastInputSource = currentSource.id
            UserPreferences.shared.selectedInputMethod = currentSource.id
        }
    }

    private func initializeInputSources() {
        // 如果已经有保存的输入法设置，就不需要初始化
        if UserPreferences.shared.selectedInputMethod != nil {
            return
        }

        // 获取所有可用的输入源
        guard let inputSources = TISCreateInputSourceList(nil, true)?.takeRetainedValue() as? [TISInputSource] else {
            print("Failed to get input sources")
            return
        }

        // 过滤出键盘输入源
        let keyboardSources = inputSources.filter { source in
            guard let categoryRef = TISGetInputSourceProperty(source, kTISPropertyInputSourceCategory),
                  let category = (Unmanaged<CFString>.fromOpaque(categoryRef).takeUnretainedValue() as NSString) as String? else {
                return false
            }
            return category == kTISCategoryKeyboardInputSource as String
        }

        // 找到第一个非 ABC 的中文输入法
        for source in keyboardSources {
            guard let sourceIdRef = TISGetInputSourceProperty(source, kTISPropertyInputSourceID),
                  let sourceId = (Unmanaged<CFString>.fromOpaque(sourceIdRef).takeUnretainedValue() as NSString) as String? else {
                continue
            }

            if sourceId != englishInputSource {
                lastInputSource = sourceId
                print("Found Chinese input source: \(sourceId)")
                break
            }
        }

        print("Initialized with input source: \(lastInputSource ?? "none")")
    }

    func setupEventTap() {
        // 修改事件掩码，添加 keyUp 事件的监听
        let eventMask = (1 << CGEventType.keyDown.rawValue) |
                       (1 << CGEventType.keyUp.rawValue) |
                       (1 << CGEventType.flagsChanged.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: eventCallback,
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            print("Failed to create event tap")
            exit(1)
        }

        eventTap = tap
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private let eventCallback: CGEventTapCallBack = { proxy, type, event, refcon in
        guard let refcon = refcon else { return Unmanaged.passRetained(event) }
        let manager = Unmanaged<KeyboardManager>.fromOpaque(refcon).takeUnretainedValue()

        switch type {
        case .keyDown:
            manager.handleKeyDown(true)

            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            manager.handleJkSequence(keyCode: keyCode, flags: event.flags)

            if keyCode == KeyboardManager.KeyCode.esc { // ESC key
                print("ESC key pressed")
                // 检查是否应该切换输入法
                if let delegate = manager.delegate,
                   delegate.shouldSwitchInputSource() {
                    manager.switchToEnglish()
                }
            }

        case .keyUp:
            manager.handleKeyDown(false)

        case .flagsChanged:
            let flags = event.flags
            manager.handleModifierFlags(flags)

        default:
            break
        }

        // 总是让事件继续传播
        return Unmanaged.passRetained(event)
    }

    func switchInputMethod() {
        let currentSource = InputSourceManager.getCurrentSource()

        if currentSource.id == englishInputSource {
            // 从英文切换到保存的输入法
            if let lastSource = lastInputSource,
               let targetSource = InputSourceManager.getInputSource(name: lastSource) {
                targetSource.select()
            }
        } else {
            // 从其他输入法切换到英文
            lastInputSource = currentSource.id
            UserPreferences.shared.selectedInputMethod = currentSource.id
            if let englishSource = InputSourceManager.getInputSource(name: englishInputSource) {
                englishSource.select()
            }
        }

        delegate?.keyboardManagerDidUpdateState()
    }

    private func updateLastInputSource(_ currentSource: InputSource) {
        if currentSource.id != englishInputSource {
            lastInputSource = currentSource.id
            print("初始化上一个输入法: \(currentSource.id)")
        }
        InputSourceManager.initialize()
    }

    // 添加新方法：专门用于ESC键的切换
    func switchToEnglish() {
        if let englishSource = InputSourceManager.getInputSource(name: englishInputSource) {
            let currentSource = InputSourceManager.getCurrentSource()
            if currentSource.id != englishInputSource {
                // 保存当前输入法作为lastInputSource
                lastInputSource = currentSource.id
                print("保存上一个输入法: \(currentSource.id)")
                InputSource(tisInputSource: englishSource.tisInputSource).select()
                delegate?.keyboardManagerDidUpdateState()
            }
        }
    }

    // 优化事件处理逻辑
    private var lastFlags: CGEventFlags = CGEventFlags(rawValue: 0)

    func handleModifierFlags(_ flags: CGEventFlags) {
        let currentTime = Date().timeIntervalSince1970

        // 打印当前修饰键的原始值，用于调试
        // print("修饰键 flags 原始值: 0x\(String(flags.rawValue, radix: 16))（\(flags.rawValue))")

        // 检测Shift键状态的改进逻辑：支持左右Shift键
        // 左Shift: 0x20102, 右Shift: 0x20104
        let currentHasShift = flags.contains(.maskShift)
        let previousHasShift = lastFlags.contains(.maskShift)

        // Shift键按下：当前有Shift但之前没有
        let isShiftKey = currentHasShift && !previousHasShift
        // Shift键释放：之前有Shift但当前没有
        let isShiftRelease = !currentHasShift && previousHasShift

        // 检查是否有其他修饰键（当前或之前的状态）
        let hasOtherModifiers = flags.contains(.maskCommand) || flags.contains(.maskControl) ||
                                flags.contains(.maskAlternate) || flags.contains(.maskSecondaryFn) ||
                                lastFlags.contains(.maskCommand) || lastFlags.contains(.maskControl) ||
                                lastFlags.contains(.maskAlternate) || lastFlags.contains(.maskSecondaryFn)

        // 打印具体的修饰键状态
        if hasOtherModifiers {
            var modifiers: [String] = []
            if flags.contains(.maskCommand) || lastFlags.contains(.maskCommand) { modifiers.append("Command") }
            if flags.contains(.maskControl) || lastFlags.contains(.maskControl) { modifiers.append("Control") }
            if flags.contains(.maskAlternate) || lastFlags.contains(.maskAlternate) { modifiers.append("Option") }
            if flags.contains(.maskSecondaryFn) || lastFlags.contains(.maskSecondaryFn) { modifiers.append("Fn") }
            // print("检测到其他修饰键: \(modifiers.joined(separator: ", "))，忽略此次事件")

            isShiftPressed = false
            hasOtherKeysDuringShift = true
            lastFlags = flags
            return
        }

        // 更新上一次的修饰键状态
        lastFlags = flags

        if isShiftKey {
            handleShiftPress(currentTime)
        } else if isShiftRelease {
            handleShiftRelease(currentTime)
        }
    }

    private func handleShiftPress(_ time: TimeInterval) {
        if !isShiftPressed {
            isShiftPressed = true
            shiftPressStartTime = time
            hasOtherKeysDuringShift = false
        }
    }

    private func handleShiftRelease(_ time: TimeInterval) {
        if isShiftPressed {
            let pressDuration = time - shiftPressStartTime
            // print("Shift 释放 - hasOtherKeysDuringShift: \(hasOtherKeysDuringShift), pressDuration: \(pressDuration)")
            if useShiftSwitch && !hasOtherKeysDuringShift && pressDuration < 0.5 {
                switchInputMethod()
            }
        }
        isShiftPressed = false
        hasOtherKeysDuringShift = false
    }

    private func handleJkSequence(keyCode: Int64, flags: CGEventFlags) {
        guard useJkSwitch else {
            waitingForKAfterJ = false
            return
        }

        let currentTime = Date().timeIntervalSince1970

        if waitingForKAfterJ && currentTime - lastJKeyTime > KeyboardManager.JK_SEQUENCE_WINDOW {
            waitingForKAfterJ = false
        }

        // 当有修饰键（除 CapsLock 外）按下时，认为不是 jk 序列
        let disallowedModifiers: CGEventFlags = [
            .maskCommand,
            .maskControl,
            .maskAlternate,
            .maskSecondaryFn,
            .maskShift
        ]
        if !flags.intersection(disallowedModifiers).isEmpty {
            if keyCode != KeyboardManager.KeyCode.j {
                waitingForKAfterJ = false
            }
            return
        }

        if keyCode == KeyboardManager.KeyCode.j {
            waitingForKAfterJ = true
            lastJKeyTime = currentTime
            return
        }

        if keyCode == KeyboardManager.KeyCode.k {
            if waitingForKAfterJ && currentTime - lastJKeyTime <= KeyboardManager.JK_SEQUENCE_WINDOW {
                waitingForKAfterJ = false
                if let delegate = delegate, delegate.shouldSwitchInputSource() {
                    switchToEnglish()
                }
            } else {
                waitingForKAfterJ = false
            }
            return
        }

        waitingForKAfterJ = false
    }

    private func cleanupKeySequence(_ currentTime: TimeInterval) {
        // 移除超过时间窗口的按键记录
        keySequence = keySequence.filter {
            currentTime - $0 < KeyboardManager.KEY_SEQUENCE_WINDOW
        }
    }

    private func shouldTriggerSwitch(_ currentTime: TimeInterval) -> Bool {
        // 如果在时间窗口内有其他按键事件，不触发切换
        if keySequence.count > 1 {
            return false
        }

        // 如果最近有其他按键事件，不触发切换
        if currentTime - lastKeyDownTime < 0.1 {
            return false
        }

        return true
    }

    // 修改键盘事件记录方法
    func handleKeyDown(_ down: Bool) {
        if down && isShiftPressed {
            hasOtherKeysDuringShift = true
        }
    }

    func setLastInputSource(_ sourceId: String) {
        lastInputSource = sourceId
        if let source = InputSourceManager.getInputSource(name: sourceId) {
            source.select()
        }
        // 保存到 UserPreferences
        UserPreferences.shared.selectedInputMethod = sourceId
    }

    // 添加新的辅助方法来处理 CJKV 输入法切换
    private func switchToCJKV(_ source: InputSource) {
        // 第一步：切换到目标输入法
        TISSelectInputSource(source.tisInputSource)
        usleep(InputSourceManager.uSeconds)

        // 第二步：切换到英文
        if let englishSource = InputSourceManager.getInputSource(name: englishInputSource) {
            TISSelectInputSource(englishSource.tisInputSource)
            usleep(InputSourceManager.uSeconds)

            // 第三步：再切回目标输入法
            TISSelectInputSource(source.tisInputSource)
            usleep(InputSourceManager.uSeconds)

            // 第四步：验证切换结果
            let finalSource = InputSourceManager.getCurrentSource()
            if finalSource.id != source.id {
                // 如果失败，尝试使用另一种序列
                if let nonCJKV = InputSourceManager.nonCJKVSource() {
                    TISSelectInputSource(nonCJKV.tisInputSource)
                    usleep(InputSourceManager.uSeconds)
                    TISSelectInputSource(source.tisInputSource)
                    usleep(InputSourceManager.uSeconds)
                }
            }
        }
    }

    // 添加公共方法来访问和控制 eventTap
    func disableEventTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
    }
}
