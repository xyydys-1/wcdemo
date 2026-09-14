# 0.3.4 compilefix1 更新与编译

将 `wcdemo_v034_fix1.zip` 放到 `/var/mobile` 后执行：

```sh
cd /var/mobile || exit 1

test -d wcdemo-local/.git || exit 1
rm -rf wcdemo-v034-fix1
mkdir -p wcdemo-v034-fix1

unzip -oq wcdemo_v034_fix1.zip -d wcdemo-v034-fix1 || exit 1
cp -a wcdemo-v034-fix1/. wcdemo-local/ || exit 1

cd /var/mobile/wcdemo-local || exit 1

git status --short
git add -A || exit 1
git diff --cached --quiet || git commit -m "WeChat26Demo 0.3.4 compilefix1" || exit 1
git -c credential.helper= push origin main
```

这个修复包只处理当前 Xcode 编译错误：
- 群成员 `LazyVGrid` 拆成独立小视图，避免 Swift 类型检查超时；
- `wxGreen` 显式写成 `Color.wxGreen`，避免被推断成 `ShapeStyle.wxGreen`。

输入框、照片手势、列表样式、本地数据和 Bundle ID 均不改。
