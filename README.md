# MacVimSwitch

[English](README.md) | [中文说明](README_CN.md)

MacVimSwitch is a utility for macOS that automatically switches input sources, designed specifically for Vim users and those who frequently switch between CJKV(Chinese/Japanese/Korean/Vietnamese) input methods. Thx to [macism](https://github.com/laishulu/macism) for the input method switching solution.

## Features

- Automatically switches to ABC input method when pressing ESC
- Built-in Shift key switching feature (enabled by default), switch between ABC English input method and Chinese/Japanese/Korean/Vietnamese input method
  - Important: Before using, please disable the "Use Shift to switch between English and Chinese/Japanese/Korean/Vietnamese" option in your input method settings
  - Can be disabled in the status bar menu if needed
- If you don't want to use Shift key switching, on Mac, CapsLock short press to switch input method, long press for caps lock
- Runs in the background with a status bar icon
- Auto-starts on system login (can be disabled from menu bar)
- Recommend: Use [inputsource.pro](https://inputsource.pro/) to automatically switch input method for each application. You can set a default input method for each application, for example, set the default input method to English in the browser and to Chinese in Vim.

![26621732330717_ pic](https://github.com/user-attachments/assets/9919de3b-461d-4a7b-b7de-8a8ae49ed661)


## Installation

Download from [GitHub Releases](https://github.com/Jackiexiao/macvimswitch/releases) and install it manually.

## Usage

1. First Launch:
   - Unzip and open MacVimSwitch
   - Grant Accessibility permissions when prompted
   - Go to System Preferences → Security & Privacy → Privacy → Accessibility
   - Add and enable MacVimSwitch
   - Restart the app

2. Important first-time setup:
   - Disable the "Use Shift to switch between English and Chinese" option in your input method settings
   - You can select your preferred Chinese input method from the status bar menu
   - You must enable the MacOS keyboard shortcut for "Select the previous input source", which can be found in "Preference -> Keyboard -> Shortcuts -> Input Source".
   - The shortcut can be anything as your wish, macism will read the shortcut from that entry and trigger it by emulation when needed. Just to make sure you have already enabled the shortcut.

3. Menu Bar Options:
   - Click the keyboard icon in the menu bar to:
     - View instructions
     - Select your preferred Chinese input method
     - Enable/Disable Shift key switching
     - Select the applications that you want to enable `Esc` to switch input source, by default, vscode, terminal, obsidian, cursor, windsurf, warp are enabled.
     - Enable/Disable launch at login
     - Quit the application


## Why MacVimSwitch?

MacVimSwitch offers several advantages over other input source switching solutions:

1. Universal Compatibility
   - Works across all applications (VSCode, Terminal, Obsidian, Cursor, etc.)
   - No need for application-specific configurations
   - No plugins required for different editors

2. Input Method Agnostic
   - Works with any Chinese/Japanese/Korean/Vietnamese input method
   - Supports popular input methods like Sogou, iFlytek, WeChat Input, etc.
   - Easy to switch between different input methods

3. Flexible Switching Options
   - Use Shift key for quick switching (enabled by default)
   - Or use CapsLock if you prefer (macOS built-in feature)
   - ESC key always switches to ABC input method (perfect for Vim users)

### Input Method Switching Options

1. Using Shift (Default)
   - Quick and convenient
   - Similar to CapsLock behavior
   - Can be disabled if not needed

2. Using CapsLock (Built-in macOS Feature)
   - System-level feature
   - Short press to switch input methods
   - Long press for caps lock
   - Works alongside MacVimSwitch

Choose the method that best suits your workflow!


## For Developers

### How to Release

1. Create GitHub Repository
Create a new repository at github.com/jackiexiao/macvimswitch
2. Clone and initialize the repository
```
git clone https://github.com/jackiexiao/macvimswitch.git
cd macvimswitch
```
3. Release
```
Tag the release
git tag v1.0.0
git push origin v1.0.0
```
4. Formula
```
bash
1. Create a new repository: github.com/jackiexiao/homebrew-tap (if not exists)
2. Clone the repository
```
git clone https://github.com/jackiexiao/homebrew-tap.git
cd homebrew-tap
```
3. Update the SHA256 in macvimswitch.rb with the one from GitHub Release
4. Commit and push the formula
git add macvimswitch.rb
git commit -m "Update MacVimSwitch formula to v1.0.0"
git push origin main
```
5. Apply for a tap

### Development

To build and test locally:
```bash
swiftc macvimswitch.swift -o macvimswitch
./macvimswitch
```

Build for release
```bash
./build.sh --create-dmg
tccutil reset All com.jackiexiao.macvimswitch # Reset permissions
# open MacVimSwitch.dmg
```

### Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.


## Acknowledgments

- [macism](https://github.com/laishulu/macism) for the input method switching solution
