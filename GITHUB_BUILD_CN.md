# 0.3.4 更新编译

将 `wcdemo_v034.zip` 放到 `/var/mobile` 后执行：

```sh
cd /var/mobile || exit 1

test -d wcdemo-local/.git || exit 1
rm -rf wcdemo-v034
mkdir -p wcdemo-v034
unzip -oq wcdemo_v034.zip -d wcdemo-v034 || exit 1
cp -a wcdemo-v034/. wcdemo-local/ || exit 1

cd /var/mobile/wcdemo-local || exit 1

git status --short
git add -A || exit 1
git diff --cached --quiet || git commit -m "WeChat26Demo 0.3.4 restore UI and lock photo gestures" || exit 1
git -c credential.helper= push origin main
```

推送后在 GitHub Actions 下载 `WeChat26Demo-iOS26-unsigned-ipa`，按原方式签名并覆盖安装。
