


# 项目名称：CountDownVoiceTimer

## 类型：
- iOS App（SwiftUI）
- 附带 watchOS 子应用（仅在系统版本允许时启用）

## 目标平台与部署版本：

- iOS 主应用：
  - 使用 SwiftUI 开发
  - Deployment Target 设置为 iOS 15
  - 保证能在 Xcode 14.2 上构建、运行、发布
  - 不依赖后端服务，所有功能本地完成

- watchOS 子应用（Apple Watch）：
  - 使用 SwiftUI 开发
  - Deployment Target 设置为 watchOS 9
  - 使用 Extension 模式集成，作为可选 Watch App
  - 主 App 保持 iOS 15 部署不变，仅当用户 iPhone 为 iOS 16+ 且有 watchOS 9+ 设备时显示 Watch App
  - 要求 Watch App 能脱离 iPhone 独立运行（Standalone）

## iOS 主 App 功能需求：

### 1. 倒计时语音读秒器“计时页面”

- 用户输入一个总时间（例如 4 分 25 秒）
- 用户设置每“圈”的距离（如 200 米），自动计算每圈的目标时间（如 53 秒）
- 进入倒计时界面后，每个圈内定时语音每隔一秒播报“1”,“2”,“3”......“53”(当前圈秒数)，在一圈描述结束后立刻从下一圈重新开始读秒
- 支持开始 / 暂停 / 重置倒计时

### 2. 语音设置功能 “设置页面”

- 用户可选择男声、女声（使用 AVSpeechSynthesizer）
- 用户可选择语速、语言（如中文普通话）
- 未来计划支持自定义语音包（可留接口）

### 3. 定位与距离测量 “测距页面”

- 允许用户开启定位功能，用于实地行走/跑步时辅助判断圈数
- 使用 CoreLocation 和 MapKit 实现
- 不需要联网或后端，只测量用户相对移动的距离

### 4. UI 要求

- 使用现代 SwiftUI 组件
- 模块化页面设计：首页（设置）➜ 倒计时界面 ➜ 设置界面
- 使用开源 SwiftUI UI 组件库（如 SwiftUIX、Shimmer 或 Glassmorphism 风格）美化界面
- “设置页面”不仅包括语音设置，还能查看计时历史记录，iwatch端信息，和软件版本

## Apple Watch 子应用功能需求（watchOS 9+）：

- 集成 watchOS 子 App，但只在用户的设备运行 iOS 16+ 和 watchOS 9+ 时才启用
- 所以请使用 **条件部署**，让 Watch App 作为 Extension 独立于主 App 运行，但不会影响主 App 在 iOS 15 上的安装与使用
- 显示当前倒计时剩余时间
- 支持开始 / 暂停 / 重置倒计时
- 播放语音播报（使用系统语音）
- 在无连接 iPhone 情况下可单独运行（Standalone）
- Watch App 的 Deployment Target 设置为 watchOS 9
- iOS 主 App 的 Deployment Target 保持在 iOS 15

## 技术要求总结：

- SwiftUI + MVVM 架构
- 无需后台 / 网络服务
- 支持 AVSpeechSynthesizer 本地语音合成
- 支持 CoreLocation 获取用户运动距离（辅助圈数）
- Xcode 14.2 兼容性
- 条件部署 Watch App（仅 iOS 16+ 设备可用）
