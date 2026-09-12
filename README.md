# WeChat26Demo 0.1.0

A standalone iOS 26 SwiftUI offline demo reconstructed from the supplied 4:01 reference video.
It is intentionally a fake-running showcase: no server, no account system, no network protocol,
no persistence, and no private WeChat API.

## Current demo scope

- Native iOS 26 SwiftUI `TabView` with four main tabs plus the system search-role tab.
- `tabBarMinimizeBehavior(.onScrollDown)` for the system iOS 26 compact tab transition.
- System Liquid Glass button styles and `GlassEffectContainer` in chat controls.
- Chats list with unread badges, pin/delete swipe actions, plus-menu and navigation.
- Chat screen with text bubbles, image messages, tappable stacked-photo animation and composer.
- Fake photo picker using image material sampled from the supplied video.
- Chat detail/group-detail style controls, pin/mute toggles and wallpaper switching.
- Contacts, contact detail/delete confirmation, Discover, Me, Add Friend, Payment and Create Group.
- Semantic system colors, so the UI follows iOS light/dark mode automatically.
- Runtime state is memory-only and resets when the app is killed.

## Build target

- Minimum iOS: 26.0
- Architecture: arm64
- GitHub Actions runner: macOS 26
- Xcode: 26.6
- Output: unsigned IPA (sign with your own certificate/profile before normal installation)

## GitHub Actions

1. Create a new GitHub repository.
2. Upload the *contents* of this folder to the repository root.
3. Commit/push to `main`.
4. Open **Actions -> Build WeChat26Demo iOS 26**.
5. Wait for the green run.
6. Download artifact **WeChat26Demo-iOS26-unsigned-ipa**.
7. Sign the IPA using your own signing workflow, then install it.

You can also press **Run workflow** manually because `workflow_dispatch` is enabled.

## Notes for the next optimization pass

The code is deliberately componentized rather than pixel-hardcoded. For a 90%+ visual pass, focus on:
1. exact list row heights and typography;
2. exact chat bubble/image geometry;
3. photo-stack spring/rotation curves;
4. toolbar icon spacing and glass grouping;
5. more accurate avatar/background assets;
6. matching the video's fake photo picker and group-detail pages.

Do not replace the system iOS 26 tab bar with a custom drawn bar unless a device test proves a real mismatch.
