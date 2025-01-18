# MacVimSwitch

[English](README.md) | [中文说明](README_CN.md)

MacVimSwitch 是一个 macOS 输入法切换工具，专为 Vim 用户和经常需要切换中文输入法的用户设计。感谢 [macism](https://github.com/laishulu/macism) 提供的输入法切换方案。

欢迎添加微信： less-wrong 反馈问题和建议

## 功能特点

- 按 ESC 键时自动切换到 ABC 英文输入法
- Shift 键切换 ABC 英文输入法 和 中文/日文/韩文/越南文输入法（可以是任何中文输入法， 如搜狗、讯飞、微信输入法等）
  - 重要提示：使用前请先关闭输入法中的"使用 Shift 切换中英文"选项
  - 如需关闭可在状态栏菜单中设置
- 后台运行，状态栏显示图标
- 温馨提示：如果你不想使用 Shift 键切换输入法，在 Mac 上，CapsLock 短按可以切换输入法，长按才是锁定大写
- 系统登录时自动启动（可在菜单栏中关闭）
- 推荐：配合上 [inputsource.pro](https://inputsource.pro/)这类能设置每个应用默认输入法的程序使用体验更佳。举个例子，你进入到浏览器中默认是中文输入法，进入 Vim 中默认是英文输入法。就不需要自己频繁切换输入法了。

![26621732330717_ pic](https://github.com/user-attachments/assets/9919de3b-461d-4a7b-b7de-8a8ae49ed661)

## 安装方法

从 [GitHub Releases](https://github.com/Jackiexiao/macvimswitch/releases) 下载并手动安装。

## 使用方法

1. 首次启动：
   - 解压后打开 MacVimSwitch
   - 根据提示授予辅助功能权限
   - 打开系统偏好设置 → 安全性与隐私 → 隐私 → 辅助功能
   - 添加并启用 MacVimSwitch
   - 重启应用程序，状态栏图标应该出现了。

2. 首次使用重要设置：
   - 关闭输入法中的"使用 Shift 切换中英文"选项，避免冲突
   - 可以在状态栏菜单中选择您偏好的中文输入法
   - 您必须为“选择上一个输入源”启用 MacOS 键盘快捷键，该快捷键可在“首选项 - > 键盘 - > 快捷键 - > InputSource”中找到。
   - 快捷方式可以是您想要的任何内容，macism 将从该条目中读取快捷方式并在需要时通过仿真触发它。只是为了确保您已经启用了快捷方式。

3. 菜单栏选项：
   - 点击状态栏的键盘图标可以：
     - 查看使用说明
     - 选择偏好的中文输入法
     - 开启/关闭 Shift 键切换功能
     - 选择 Esc 生效的应用（可多选，默认在 Terminal、VSCode、MacVim、windsurf、obsidian、warp 中生效）
     - 开启/关闭开机自动启动
     - 退出应用程序

## 开发者指南

### 发布流程

1. 创建 GitHub 仓库
```bash
# 1. 在 github.com/jackiexiao/macvimswitch 创建新仓库
# 2. 克隆并初始化仓库
git clone https://github.com/jackiexiao/macvimswitch.git
cd macvimswitch
```

2. 准备发布文件
```bash
# 添加所有必要文件
git add macvimswitch.swift README.md README_CN.md LICENSE
git commit -m "Initial commit"
git push origin main
```

3. 创建发布版本
```bash
# 标记版本
git tag v1.0.0
git push origin v1.0.0
```
GitHub Actions 工作流会自动：
- 构建应用程序
- 创建包含应用程序包（.app）和源代码包（.tar.gz）的发布版本
- 计算并显示用于更新 Homebrew formula 的 SHA256 值
更新 Homebrew Formula


4. 创建 Homebrew Tap
```bash
# 1. 创建新仓库：github.com/jackiexiao/homebrew-tap（如果不存在）
# 2. 克隆仓库
git clone https://github.com/jackiexiao/homebrew-tap.git
cd homebrew-tap

# 3. 使用 GitHub Release 中提供的 SHA256 值更新 macvimswitch.rb
# 4. 提交并推送 formula
git add macvimswitch.rb
git commit -m "更新 MacVimSwitch formula 到 v1.0.0"
git push origin main
```

### 本地开发

本地构建和测试：
```bash
./build.sh
# 打开第一次，辅助功能先把之前的 MacVimSwitch 删除，看起来好像必须得这么做
open dist/MacVimSwitch.app
# 打开第二次，启动辅助功能
open dist/MacVimSwitch.app
# 打开第三次，相当于重启应用，这个时候你才能正确获取授权
open dist/MacVimSwitch.app
```

构建发布版本：
```bash
./build.sh --create-dmg
tccutil reset All com.jackiexiao.macvimswitch # Reset permissions
# open MacVimSwitch.dmg
```

### 贡献代码

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m '添加某个很棒的特性'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 提交 Pull Request

## 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件。

## 为什么选择 MacVimSwitch？

MacVimSwitch 相比其他输入法切换方案有以下优势：

1. 通用兼容性
   - 可在所有应用程序中使用（VSCode、终端、Obsidian、Cursor、Warp、Windsurf 等）
   - 无需针对不同应用进行配置
   - 不需要为不同编辑器安装插件

2. 输入法无关性
   - 支持任何中文输入法
   - 兼容搜狗、讯飞、微信输入法等主流输入法
   - 可以方便地在不同输入法间切换

3. 灵活的切换选项
   - 使用 Shift 键快速切换（默认开启）
   - 或使用 CapsLock（macOS 内置功能）
   - ESC 键始终切换到英文（对 Vim 用户很友好）

### 输入法切换选项

1. 使用 Shift 键（默认方式）
   - 快速便捷
   - 类似 CapsLock 的行为
   - 可根据需要关闭

2. 使用 CapsLock（macOS 内置功能）
   - 系统级功能
   - 短按切换输入法
   - 长按锁定大写
   - 可与 MacVimSwitch 同时使用

选择最适合您工作流程的方式！

# 感谢

- [macism](https://github.com/laishulu/macism) 提供的输入法切换方案
