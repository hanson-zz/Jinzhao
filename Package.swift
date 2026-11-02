// swift-tools-version: 5.10
import PackageDescription

// 用 SwiftPM 而不是手写 Xcode 工程：没有本地 Xcode 也能靠 GitHub Actions 在云端 Mac 上编译打包。
// 系统要求（产品定版）：macOS 26+（液态玻璃）。这里的 platforms 只是编译下限，打包时 Info.plist 会写 26.0。
let package = Package(
    name: "Jinzhao",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Jinzhao", targets: ["Jinzhao"])
    ],
    targets: [
        .executableTarget(
            name: "Jinzhao",
            path: "Jinzhao",
            exclude: ["Resources"] // JSON 数据在打包阶段拷进 .app 的 Resources/Holidays，运行时走 Bundle.main
        )
    ]
)
