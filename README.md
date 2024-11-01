# MacVimSwitch

[English](README.md) | [中文说明](README_CN.md)

MacVimSwitch is a utility for macOS that automatically switches input sources, designed specifically for Vim users and those who frequently switch between CJKV(Chinese/Japanese/Korean/Vietnamese) input methods.

## Features

- Automatically switches to ABC input method when pressing ESC
- Runs in the background with a status bar icon
- Built-in Shift key switching feature (enabled by default)
  - Important: Before using, please disable the "Use Shift to switch between English and Chinese/Japanese/Korean/Vietnamese" option in your input method settings
  - Can be disabled in the status bar menu if needed
- Reminder about CapsLock behavior on Mac: short press to switch input method, long press for caps lock
- Auto-starts on system login

## Why MacVimSwitch?

MacVimSwitch offers several advantages over other input source switching solutions:

1. Universal Compatibility
   - Works across all applications (VSCode, Terminal, Obsidian, Cursor, etc.)
   - No need for application-specific configurations
   - No plugins required for different editors

2. Low Latency
   - Minimal delay in input method switching
   - Direct use of macOS APIs for better performance
   - Efficient event handling

3. Input Method Agnostic
   - Works with any Chinese/Japanese/Korean/Vietnamese input method
   - Supports popular input methods like Sogou, iFlytek, WeChat Input, etc.
   - Easy to switch between different input methods

4. Flexible Switching Options
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

## Installation

```bash
brew tap jackiexiao/tap      # Add the repository to Homebrew
brew install macvimswitch    # Install MacVimSwitch
```

Or build from source:
```bash
git clone https://github.com/jackiexiao/macvimswitch
cd macvimswitch
swiftc macvimswitch.swift -o macvimswitch
```

## Usage

1. After installation, grant Accessibility permissions:
   - Go to System Preferences → Security & Privacy → Privacy → Accessibility
   - Add and enable macvimswitch

2. Important first-time setup:
   - Disable the "Use Shift to switch between English and Chinese" option in your input method settings
   - You can select your preferred Chinese input method from the status bar menu

3. The app will automatically start on system login
4. Click the keyboard icon in the status bar to:
   - View instructions
   - Select your preferred Chinese input method
   - Enable/Disable Shift key switching (enabled by default)
   - Quit the application

## Important Notes

1. Make sure to disable the "Use Shift to switch between English and Chinese" option in your input method settings to avoid conflicts
2. The app requires accessibility permissions to function properly
3. A system restart might be required after granting permissions

## For Developers

### How to Release

1. Create GitHub Repository
```bash
# 1. Create a new repository at github.com/jackiexiao/macvimswitch
# 2. Clone and initialize the repository
git clone https://github.com/jackiexiao/macvimswitch.git
cd macvimswitch
```

2. Prepare Release Files
```bash
# Add all necessary files
git add macvimswitch.swift README.md README_CN.md LICENSE
git commit -m "Initial commit"
git push origin main
```

3. Create Release
```bash
# Tag the release
git tag v1.0.0
git push origin v1.0.0

# On GitHub:
# 1. Go to repository → Releases → Create a new release
# 2. Choose the v1.0.0 tag
# 3. Title: MacVimSwitch v1.0.0
# 4. Generate release notes
# 5. Publish release
```

4. Create Homebrew Tap
```bash
# 1. Create a new repository: github.com/jackiexiao/homebrew-tap
# 2. Clone the repository
git clone https://github.com/jackiexiao/homebrew-tap.git
cd homebrew-tap

# 3. Calculate SHA256 of the release tarball
curl -L https://github.com/jackiexiao/macvimswitch/archive/v1.0.0.tar.gz | shasum -a 256

# 4. Update the SHA256 in macvimswitch.rb
# 5. Commit and push the formula
git add macvimswitch.rb
git commit -m "Add MacVimSwitch formula"
git push origin main
```

### Development

To build and test locally:
```bash
swiftc macvimswitch.swift -o macvimswitch
./macvimswitch
```

### Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
