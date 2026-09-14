# 0.3.3 更新与编译

将 `WeChat26Demo_v0.3.3_GlassPanel_Directory_flat.zip` 放到手机 `/var/mobile`，执行下面整段：

```sh
cd /var/mobile || exit 1

test -d wcdemo-local/.git || exit 1
mkdir -p wcdemo-v033
unzip -oq WeChat26Demo_v0.3.3_GlassPanel_Directory_flat.zip -d wcdemo-v033 || exit 1
cp -a wcdemo-v033/. wcdemo-local/ || exit 1

cd /var/mobile/wcdemo-local || exit 1
rm -f ElasticPhotoStack.swift StackSpring.swift Tests/MigrationAndMotionTests.swift

git status --short
git add -A || exit 1
git diff --cached --quiet || git commit -m "WeChat26Demo 0.3.3 glass panel and editable directory" || exit 1
git -c credential.helper= push origin main
```

这段指令更新源代码并触发 GitHub Actions 编译。ZIP 内直接是工程，不需要再进入同名内层目录。`cp -a .../.` 会同时复制构建工作流。删除命令只清理已被替换的三个旧源码／测试文件。

推送后进入仓库 Actions → `Build WeChat26Demo iOS 26`。工作流先运行存档与布局测试，再编译 IPA。成功后从 Artifacts 下载 `WeChat26Demo-iOS26-unsigned-ipa`，解压并用原方式签名、覆盖安装。

最后一行临时禁用此前缺失的 credential helper。若 GitHub 询问 Password，填写有仓库写权限的 token；本次更新包含工作流文件，凭据还需具有工作流修改权限。不要将 token 写进源码或远程 URL。

应用版本 0.3.3，构建号 8，Bundle ID `com.xyy.wechat26demo`。覆盖安装可继续读取原有本地记录，不需要清空数据。

本地未执行 iOS 编译或真机验证，编译结果以 GitHub Actions 为准。
