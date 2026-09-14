# 0.3.3 更新与编译

将 `WeChat26Demo_v0.3.3_PhotoHomeGroupFix_compilefix1_flat.zip` 放到手机 `/var/mobile`，执行：

```sh
cd /var/mobile || exit 1

test -d wcdemo-local/.git || exit 1
rm -rf wcdemo-v033
mkdir -p wcdemo-v033
unzip -oq WeChat26Demo_v0.3.3_PhotoHomeGroupFix_compilefix1_flat.zip -d wcdemo-v033 || exit 1
cp -a wcdemo-v033/. wcdemo-local/ || exit 1

cd /var/mobile/wcdemo-local || exit 1
rm -f ElasticPhotoStack.swift StackSpring.swift Tests/MigrationAndMotionTests.swift

git status --short
git add -A || exit 1
git diff --cached --quiet || git commit -m "Update demo to 0.3.3" || exit 1
git -c credential.helper= push origin main
```

提交到 main 后进入仓库 Actions → `Build WeChat26Demo iOS 26`。成功后下载 `WeChat26Demo-iOS26-unsigned-ipa`，按原方式签名并覆盖安装。

应用版本 0.3.3，构建号 9，Bundle ID 仍为 `com.xyy.wechat26demo`。覆盖安装不会主动清空 0.3.2 的聊天、联系人、图片、头像、壁纸和草稿。
