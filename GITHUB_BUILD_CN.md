# 0.3.2 compilefix2 更新与编译

将 `WeChat26Demo_v0.3.2_NativeSwiftUI_compilefix2_flat.zip` 放到手机 `/var/mobile`，执行：

```sh
cd /var/mobile || exit 1

test -d wcdemo-local/.git || exit 1
mkdir -p wcdemo-v032-fix2
unzip -oq WeChat26Demo_v0.3.2_NativeSwiftUI_compilefix2_flat.zip -d wcdemo-v032-fix2 || exit 1
cp -a wcdemo-v032-fix2/. wcdemo-local/ || exit 1

cd /var/mobile/wcdemo-local || exit 1
rm -f ElasticPhotoStack.swift StackSpring.swift Tests/MigrationAndMotionTests.swift

git status --short
git add -A || exit 1
git diff --cached --quiet || git commit -m "Fix CGFloat types in photo layout tests" || exit 1
git -c credential.helper= push origin main
```

这是更新源代码并触发 GitHub Actions 编译。`rm -f` 只移除已被替换的旧叠牌实现和旧测试文件，不操作应用的聊天存档。新实现由 `NativePhotoStack.swift`、`PhotoLayoutMetrics.swift` 及对应测试组成，Makefile 和工作流清单已同步。

提交到 main 后，进入仓库 Actions → `Build WeChat26Demo iOS 26`。工作流先运行 Foundation 数据与布局测试，再编译并打包。成功后从 Artifacts 下载 `WeChat26Demo-iOS26-unsigned-ipa`，解压并用原方式签名、覆盖安装。

最后一行临时禁用此前缺失的 credential helper。GitHub 若询问 Password，应填写有仓库写权限的 token，不是账号密码；本次包含工作流修改，凭据还需允许修改工作流文件。不要把 token 写入代码、远程 URL 或提交记录。

ZIP 内直接是工程根目录，不需要进入同名内层目录。`cp -a .../.` 会一起复制构建工作流。

应用版本 0.3.2，构建号 7，Bundle ID `com.xyy.wechat26demo`。保留此 Bundle ID 并覆盖安装，继续读取现有本地消息和资料；无需清空存档。当前交付包完成源码及结构检查，尚未在本地执行 iOS 编译或真机测试。
