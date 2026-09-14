# 0.3.3 视频对照与公开 API

本轮参考 `video_1789244789965(2).mp4`：77.10 秒、512×910、30fps。检查了全片关键位置、3.60–4.37 秒连续 24 帧的展开过程、7.20–7.87 秒连续 21 帧的回弹过程，以及 52.7–55.2 秒的附件收展。

| 视频观察 | 本轮实现 |
| --- | --- |
| 3.7–4.2 秒：六张照片从中心分散到三列两行，横图行更矮 | AnyLayout 保留视图身份，PhotoRowsLayout 按每行最大实际高度排列 |
| 约 70 秒：四张同样用三列，首行竖图居中，末张留在下一行左侧 | 三张及以上固定三列；格内保留照片比例并居中 |
| 下层照片偏模糊，松手后不同层依次追上 | SwiftUI blur 与不同响应的 interactiveSpring / interpolatingSpring |
| 照片边缘能与背景区分，旋转后仍平滑 | 连续圆角、抗锯齿裁切、细内描边、带透明采样边的 drawingGroup |
| 52.7–55.2 秒：附件表面展开后更厚，图标下方有独立标题，收展伴随模糊 | 改用真正 Menu 与两个 ControlGroup；材质、收展和分组呈现由系统负责 |
| 视频中输入栏本身也参与附件形变 | 本轮按用户明确要求保持现有输入框；Menu 从独立的加号按钮打开 |

视频只能显示结果，无法确认作者具体使用了哪些私有或自定义代码。固定四列图标底座加下方标题，不等于系统 Menu 在所有设备上都会采用的布局。本轮优先系统菜单呈现，保留操作的语义标题，接受系统按空间和辅助功能自适应。

照片的层深、角度、描边与布局参数仍属于项目实现。它们使用 SwiftUI 提供的渲染、布局及动画能力，不是调用一个现成的“苹果聊天叠牌”。

## 苹果官方依据

- [Populating SwiftUI menus with adaptive controls](https://developer.apple.com/documentation/swiftui/populating-swiftui-menus-with-adaptive-controls)：Menu 接受标准控件，ControlGroup 用于横向组织最多四个相关操作；menuOrder 可保持定义顺序。工程使用两个四项分组。
- [Meet Liquid Glass, WWDC25](https://developer.apple.com/videos/play/wwdc2025/219/)：展开后的菜单会加厚表面、增加深度和阴影。玻璃用于导航与控制层；照片内容不覆盖玻璃滤镜。
- [AnyLayout](https://developer.apple.com/documentation/swiftui/anylayout)：切换布局时保留子视图状态与身份，用于同一组图片在叠放、网格之间移动。
- [Animate with springs, WWDC23](https://developer.apple.com/videos/play/wwdc2023/10158/)：系统弹簧支持手势速度衔接和目标改变后的连续运动。
- [interactiveSpring](https://developer.apple.com/documentation/swiftui/animation/interactivespring(response:dampingfraction:blendduration:)) 与 [interpolatingSpring](https://developer.apple.com/documentation/swiftui/animation/interpolatingspring(duration:bounce:initialvelocity:))：分别用于持续跟手及松手后的回弹，没有自行驱动显示帧或求解弹簧。
- [drawingGroup](https://developer.apple.com/documentation/swiftui/view/drawinggroup(opaque:colormode:))：将 SwiftUI 图片和形状合成为离屏图像，旋转前统一处理裁切与边缘。
- [dragPreviewsFormation](https://developer.apple.com/documentation/swiftui/view/dragpreviewsformation(_:))：官方标注为 macOS 26 API，用于拖放预览，不能用于本工程的 iPhone 常驻消息叠牌。

公开文档证实 API 的用途与可用性，不能证明本工程已经在真机上达到参考视频的效果。此版本仍需 iOS 26 构建与真机动画验证。
