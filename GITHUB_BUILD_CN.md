# 0.3.1 更新与编译

将 `WeChat26Demo_v0.3.1_ElasticStack_flat.zip` 放在手机 `/var/mobile`，在终端执行：

```sh
cd /var/mobile || exit 1

test -d wcdemo-local/.git || exit 1
mkdir -p wcdemo-v031
unzip -oq WeChat26Demo_v0.3.1_ElasticStack_flat.zip -d wcdemo-v031 || exit 1
cp -a wcdemo-v031/. wcdemo-local/ || exit 1

cd /var/mobile/wcdemo-local || exit 1

git status --short
git add -A || exit 1
git diff --cached --quiet || git commit -m "WeChat26Demo 0.3.1 native toolbar and elastic photo stack" || exit 1
git -c credential.helper= push origin main
```

这是覆盖源代码并触发 GitHub 编译的指令。工作流沿用原仓库的 macOS / Xcode 26 配置。提交到 main 后进入仓库 Actions，打开 `Build WeChat26Demo iOS 26`，成功后从 Artifacts 下载 `WeChat26Demo-iOS26-unsigned-ipa`，解压并用原方式签名、覆盖安装。

最后一行临时禁用截图中缺失的 credential helper；如询问密码，应填写有该仓库写权限的 GitHub token，而非账号密码。本次更新包含工作流文件，token 也需要允许更新工作流。不要把 token 写进工程或提交记录。

压缩包是平铺工程，Makefile 和 `.github` 位于包根目录。新增的 `StackSpring.swift`、`ElasticPhotoStack.swift`、`Tests/MigrationAndMotionTests.swift` 必须一起复制；上面的 `cp -a .../.` 已包含它们。

应用版本 0.3.1 / 构建号 6，Bundle ID `com.xyy.wechat26demo` 保持一致。覆盖安装后自动迁移预置历史，不需要删除应用或清空存档。代码仓库在 `/var/mobile/wcdemo-local`；个人聊天记录在已安装应用自己的数据目录里，两者分开。
