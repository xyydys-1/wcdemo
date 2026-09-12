# 本轮视频对照与实现位置

本轮参考：用户提供的 79.07 秒视频，512×910，30fps。

| 需求 | 处理 | 文件 |
| --- | --- | --- |
| 列表一个按钮与聊天两个按钮切换 | 导航路径控制根工具栏，稳定项目 ID、系统工具栏间隔、系统返回手势 | RootViews.swift / ChatViews.swift |
| 附件动画与布局 | 四列两行、单一圆角面板、方形图标底座、加号附近收展；输入栏维持原外观 | ChatViews.swift |
| 多图混合比例、叠牌、展开、翻动 | 自定义 SwiftUI 排列与弹簧；图片比例缓存；展开显示全部；横向手势判定 | MediaViews.swift |
| 本机图库与原生大图查看 | PhotosPicker / Quick Look | ChatViews.swift / MediaViews.swift |
| 自己、联系人、群资料 | 单一资料来源、系统图库、原生 Form | ProfileViews.swift / Models.swift |
| 本地笔记与设置保存 | Codable 存档、独立图片副本、原子替换、备份回读 | LocalData.swift / Models.swift |

视频约 0–17 秒与 69–79 秒展示多图叠牌和翻动，约 55–57 秒与 66–68 秒展示附件面板。保留现有输入框是本轮明确约束，因此附件面板浮在原输入栏上方。视频中其它页面的布局没有整页重建。

叠牌由 SwiftUI 实现；系统图库与大图预览采用公开原生组件。参考的 Apple 公开接口：

- [ToolbarSpacer](https://developer.apple.com/documentation/swiftui/toolbarspacer)
- [Liquid Glass 自定义视图](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views)
- [PhotosPicker](https://developer.apple.com/documentation/photosui/photospicker)
- [Quick Look](https://developer.apple.com/documentation/quicklook/qlpreviewcontroller)

本轮没有 iOS 运行环境，不能据此宣称与视频逐帧一致；真机结果用于后续调整收展曲线与工具栏过渡。
