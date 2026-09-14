# 视频与公开 API 对照

此前对 `video_1789244789965(2).mp4` 检查了关键位置，包括 3.60–4.37 秒连续 24 帧的照片展开、7.20–7.87 秒连续 21 帧的回弹，以及 52.7–55.2 秒的附件收展。此次结合用户新增的 IMG_7860、IMG_7863–7867 截图及逐层跟随比例说明继续修改。

| 参考与反馈 | 0.3.3 实现 |
| --- | --- |
| 第二、三层仅跟随约 40%、20%，更深层幅度更小 | 100% / 40% / 20% / 10% / 5%，逐层延长系统弹簧响应 |
| 下层照片更模糊 | 后层 blur 2.8 / 4.3 / 5.6 / 6.8pt，展开归零 |
| 左右滑动都应将首张叠到最后 | 两个方向使用同一循环队列；方向只影响拖动位移 |
| 六张照片三列两行，四张仍三列；混合比例行内居中 | 保留 AnyLayout 和按真实比例测量的 PhotoRowsLayout |
| 图片起手也应能上下滚动聊天 | 原生方向判断发生在识别之前，展开后禁用横向叠牌识别 |
| 图片边缘接近气泡的光学边缘 | 共享连续圆角与窄 clear glass 底边，不覆盖照片内容 |
| IMG_7860：大玻璃表面、两排四列灰色磨砂方块、标题在下 | 系统部分高度 sheet + 从按钮缩放过渡；八块 native Material 内容，轻微 spring 按压放大 |
| IMG_7864–7866：显示模式二级菜单、置顶可折叠 | 原生 Menu 内 Picker，持久化模式和折叠状态 |
| IMG_7867：成员偏小且缺少添加位置 | 增大成员头像／名字，真实成员数及“＋”选择入口 |

## 苹果官方依据

- [Build a SwiftUI app with the new design，WWDC25](https://developer.apple.com/videos/play/wwdc2025/323/)：iOS 26 部分高度 sheet 默认采用内缩玻璃外观；通过 matchedTransitionSource 和 zoom 过渡关联来源按钮。本项目保留 sheet 默认背景。
- [matchedTransitionSource](https://developer.apple.com/documentation/swiftui/view/matchedtransitionsource(id:in:))、[navigationTransition](https://developer.apple.com/documentation/swiftui/view/navigationtransition(_:))：来源和目标的系统过渡连接；工程仅关联独立加号，遵守输入框不改动的要求。
- [UIGestureRecognizerRepresentable](https://developer.apple.com/documentation/swiftui/uigesturerecognizerrepresentable)：把系统手势识别器接入 SwiftUI，使用 coordinator 处理 delegate 的方向裁决。没有更改聊天 ScrollView 的内部视图层级。
- [Applying Liquid Glass to custom views](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views)：公开 glassEffect 可应用到明确的形状。这里只作为照片后方的窄边，不声称是苹果照片应用的专有描边实现。
- [Material](https://developer.apple.com/documentation/swiftui/material)：用于附件方块的系统磨砂材质。按钮的自定义部分仅为轻微缩放，不仿制液态玻璃背景。
- [AnyLayout](https://developer.apple.com/documentation/swiftui/anylayout)：叠放和展开使用同一组照片视图，保留身份。
- [Animate with springs，WWDC23](https://developer.apple.com/videos/play/wwdc2023/10158/)：使用系统弹簧处理目标变化后的连续动画；没有 CADisplayLink 驱动或手写物理积分。
- [Populating SwiftUI menus with adaptive controls](https://developer.apple.com/documentation/swiftui/populating-swiftui-menus-with-adaptive-controls)：保留的紧凑附件方案使用 Menu 和两个 ControlGroup，首页显示模式使用系统二级菜单。

视频只能提供视觉参考，不能确认作者的具体源码。照片堆叠是本项目用公开 SwiftUI 布局、渲染和动画 API 组合的效果，没有找到可直接调用的 iPhone 聊天叠牌组件。大面板的外壳和过渡为系统 sheet；其内部四列附件内容由项目排列。

公开文档与源码检查不能代替 iOS 编译、真机动画及触摸验证，本次未将这些列为已通过。
