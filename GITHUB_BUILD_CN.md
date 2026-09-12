# GitHub 编译说明

这个工程最适合直接交给 GitHub Actions 编译，因为 Windows 本地没有 Apple iOS 26 SDK/Xcode。

## 最短步骤

1. GitHub 新建一个空仓库，例如 `WeChat26Demo`。
2. 把本 ZIP 解压后的所有内容上传到仓库根目录。
   - `.github` 目录必须保留。
   - `Makefile` 必须位于仓库根目录。
3. 提交到 `main`。
4. 打开仓库的 `Actions`。
5. 点 `Build WeChat26Demo iOS 26`。
6. 构建成功后，在页面底部 `Artifacts` 下载：
   `WeChat26Demo-iOS26-unsigned-ipa`。
7. 解压 artifact 得到 `.ipa`。
8. 该 IPA 是 unsigned，按你自己的证书/描述文件方式签名后安装。

## 为什么不用 Windows 直接编译

Swift 语言本身能在 Windows/Linux 使用，但 iOS App 依赖 Apple 的 UIKit、SwiftUI 和 iPhoneOS SDK，
正式构建仍需要 macOS/Xcode 工具链。GitHub 的 macOS runner 正好解决这一点。
