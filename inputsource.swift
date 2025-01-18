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
            TISSelectInputSource(tisInputSource)
            usleep(InputSourceManager.uSeconds)
        }
    }

    private func switchCJKVSource() {
        // 直接切换到目标输入法
        TISSelectInputSource(tisInputSource)
        usleep(InputSourceManager.uSeconds)

        // 如果切换失败，尝试通过非 CJKV 输入法中转
        if InputSourceManager.getCurrentSource().id != self.id,
           let nonCJKV = InputSourceManager.nonCJKVSource() {
            TISSelectInputSource(nonCJKV.tisInputSource)
            usleep(InputSourceManager.uSeconds)
            TISSelectInputSource(tisInputSource)
        }
    }
}

// 修改 InputSourceManager 类
class InputSourceManager {
    static var inputSources: [InputSource] = []
    static var uSeconds: UInt32 = 12000
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
    let abcInputSource = "com.apple.keylayout.ABC"
    var useShiftSwitch: Bool = true {
        didSet {
            delegate?.keyboardManagerDidUpdateState()  // 移除日志，保留代理通知
        }
    }
    var lastShiftPressTime: TimeInterval = 0

    // 添加属性来跟踪上一个输入法
    private(set) var lastInputSource: String?
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

    private init() {
        // 移除通知相关的初始化
    }

    private func initializeInputSources() {
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

        // 找到第一个 ABC 的中文输入法
        for source in keyboardSources {
            guard let sourceIdRef = TISGetInputSourceProperty(source, kTISPropertyInputSourceID),
                  let sourceId = (Unmanaged<CFString>.fromOpaque(sourceIdRef).takeUnretainedValue() as NSString) as String? else {
                continue
            }

            if sourceId != abcInputSource {
                lastInputSource = sourceId
                print("Found Chinese input source: \(sourceId)")
                break
            }
        }

        print("Initialized with input source: \(lastInputSource ?? "none")")
    }

    func start() {
        InputSourceManager.initialize()
        initializeInputSources()  // 添加初始化调用
        setupEventTap()
    }

    private func setupEventTap() {
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

            if event.getIntegerValueField(.keyboardEventKeycode) == 0x35 { // ESC key
                print("ESC key pressed")
                // 检查是否应该切换输入法
                if let delegate = manager.delegate,
                   delegate.shouldSwitchInputSource() {
                    manager.switchToABC()
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
        print("当前输入法: \(currentSource.id)")
        print("上一个输入法: \(lastInputSource ?? "nil")")

        if let lastSource = lastInputSource,
           let targetSource = InputSourceManager.getInputSource(name: lastSource) {
            if currentSource.id == abcInputSource {
                // 从ABC切换到上一个输入法
                targetSource.select()
                print("切换到上一个输入法: \(lastSource)")
            } else {
                // 从其他输入法切换到ABC
                lastInputSource = currentSource.id
                print("保存当前输入法: \(currentSource.id)")
                if let abcSource = InputSourceManager.getInputSource(name: abcInputSource) {
                    abcSource.select()
                }
            }
        } else {
            // 如果没有lastInputSource，则更新它
            updateLastInputSource(currentSource)
        }

        delegate?.keyboardManagerDidUpdateState()
    }

    private func updateLastInputSource(_ currentSource: InputSource) {
        if currentSource.id != abcInputSource {
            lastInputSource = currentSource.id
            print("初始化上一个输入法: \(currentSource.id)")
        }
        InputSourceManager.initialize()
    }

    // 添加新方法：专门用于ESC键的切换
    func switchToABC() {
        if let abcSource = InputSourceManager.getInputSource(name: abcInputSource) {
            let currentSource = InputSourceManager.getCurrentSource()
            if currentSource.id != abcInputSource {
                // 保存当前输入法作为lastInputSource
                lastInputSource = currentSource.id
                print("保存上一个输入法: \(currentSource.id)")
                InputSource(tisInputSource: abcSource.tisInputSource).select()
                delegate?.keyboardManagerDidUpdateState()
            }
        }
    }

    // 优化事件处理逻辑
    func handleModifierFlags(_ flags: CGEventFlags) {
        let currentTime = Date().timeIntervalSince1970
        let isShiftKey = flags.rawValue == 0x20102
        let isShiftRelease = flags.rawValue == 0x100

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
            if useShiftSwitch && !hasOtherKeysDuringShift && pressDuration < 0.5 {
                switchInputMethod()
            }
        }
        isShiftPressed = false
        hasOtherKeysDuringShift = false
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
        if let source = InputSourceManager.getInputSource(name: sourceId) {
            // 直接切到选择的输入法
            if source.isCJKV {
                switchToCJKV(source)
            } else {
                TISSelectInputSource(source.tisInputSource)
                usleep(InputSourceManager.uSeconds)
            }

            // 更新 lastInputSource
            lastInputSource = sourceId
            print("Set last input source to: \(sourceId)")

            // 通知状态更新
            delegate?.keyboardManagerDidUpdateState()
        }
    }

    // 添加新的辅助方法来处理 CJKV 输入法切换
    private func switchToCJKV(_ source: InputSource) {
        // 第一步：切换到目标输入法
        TISSelectInputSource(source.tisInputSource)
        usleep(InputSourceManager.uSeconds)

        // 第二步：切换到 ABC
        if let abcSource = InputSourceManager.getInputSource(name: abcInputSource) {
            TISSelectInputSource(abcSource.tisInputSource)
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
