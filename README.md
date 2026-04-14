# ViewglassServer 0.1.0

`ViewglassServer 0.1.0` is the iOS runtime server used by [Viewglass](https://github.com/WZBbiao/viewglass).
It is the maintained server-side fork of `LookinServer`, with additional protocol hardening and
AI-oriented runtime actions.

Use this repository when you want your iOS app to work with:

- `viewglass` CLI
- semantic actions such as `tap`, `long-press`, `scroll`, and `invoke`
- high-resolution screenshots over the server protocol

`ViewglassServer` keeps the product and module name `LookinServer` for compatibility, so existing
projects can continue to `import LookinServer`.

## Requirements

- iOS or tvOS app
- Debug-only integration
- Xcode with Swift Package Manager or CocoaPods

Do not ship `ViewglassServer` in Release or App Store builds.

## Install with Swift Package Manager

Recommended.

In Xcode:

1. Open your app project.
2. Go to `File > Add Package Dependencies...`
3. Enter:

```text
https://github.com/WZBbiao/ViewglassServer.git
```

4. Choose the latest tag, currently `0.1.0`.
5. Add the `LookinServer` library to your app target.
6. Link it only in `Debug` builds.

Example `Package.swift`:

```swift
.package(url: "https://github.com/WZBbiao/ViewglassServer.git", from: "0.1.0")
```

Then add:

```swift
.product(name: "LookinServer", package: "ViewglassServer")
```

For local development, you can also use a path dependency:

```swift
.package(path: "../ViewglassServer")
```

## Install with CocoaPods

If your project still uses CocoaPods:

### Swift project

```ruby
pod 'LookinServer', :git => 'https://github.com/WZBbiao/ViewglassServer.git', :tag => '0.1.0', :subspecs => ['Swift'], :configurations => ['Debug']
```

### Objective-C project

```ruby
pod 'LookinServer', :git => 'https://github.com/WZBbiao/ViewglassServer.git', :tag => '0.1.0', :configurations => ['Debug']
```

If you need the `NoHook` variant:

```ruby
pod 'LookinServer/NoHook', :git => 'https://github.com/WZBbiao/ViewglassServer.git', :tag => '0.1.0', :configurations => ['Debug']
```

## Basic Usage

Import `LookinServer` in your app and keep it available only in debug builds.

Swift:

```swift
#if DEBUG
import LookinServer
#endif
```

Objective-C:

```objc
#if DEBUG
@import LookinServer;
#endif
```

Then launch your app on a simulator or device. `viewglass apps list` should discover it.

## Relationship to Viewglass

- `ViewglassServer` runs inside your iOS app
- [`viewglass`](https://github.com/WZBbiao/viewglass) connects to it from macOS
- both simulator and physical-device screenshots now go through the same server protocol

## Compatibility Notes

- The framework and import name remain `LookinServer`
- This repository is a maintained fork of the original `QMUI/LookinServer`, published under the independent ViewglassServer 0.1.0 version line
- The protocol includes additional safety checks to reduce app crashes during semantic actions

## Warnings

- Debug only
- Do not include in App Store / Release builds
- Keep client and server reasonably close in version when using newer action or screenshot features

## 中文说明

`ViewglassServer 0.1.0` 是 `Viewglass` 使用的 iOS 运行时服务端。它基于 `LookinServer` 继续维护，
加入了更安全的语义操作能力和统一的高分截图协议。

集成建议：

- 优先使用 Swift Package Manager
- 只在 `Debug` 配置中接入
- 业务代码里仍然使用 `import LookinServer`

SPM 地址：

```text
https://github.com/WZBbiao/ViewglassServer.git
```

CocoaPods 示例：

```ruby
pod 'LookinServer', :git => 'https://github.com/WZBbiao/ViewglassServer.git', :tag => '0.1.0', :configurations => ['Debug']
```

Swift 项目如果需要 Swift 支持：

```ruby
pod 'LookinServer', :git => 'https://github.com/WZBbiao/ViewglassServer.git', :tag => '0.1.0', :subspecs => ['Swift'], :configurations => ['Debug']
```
