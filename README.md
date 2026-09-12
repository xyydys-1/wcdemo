# WeChat26Demo 0.2.0

A standalone iOS 26 SwiftUI offline demo reconstructed from the supplied 4:01 reference video.
It is intentionally a fake-running showcase: no server, no account system, no network protocol,
no persistence, and no private WeChat API.

## Current demo scope

- Native iOS 26 SwiftUI `TabView` with four main tabs plus the system search-role tab.
- `tabBarMinimizeBehavior(.onScrollDown)` for the system iOS 26 compact tab transition.
- System Liquid Glass button styles and `GlassEffectContainer` in chat controls.
- Chats list with unread badges, pin/delete swipe actions, plus-menu and navigation.
- Chat screen with iOS 26 Liquid Glass text bubbles, image messages, swipe/tap photo-stack animation and a three-piece glass composer.
- Fake photo picker for demo message sending, plus the real system `PhotosPicker` for per-chat wallpapers.
- Chat detail/group-detail style controls, pin/mute toggles and photo-library wallpaper selection.
- Contacts, contact detail/delete confirmation, Discover, Me, Add Friend, Payment and Create Group.
- Semantic system colors for adaptive toolbar icons and automatic iOS light/dark appearance.
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

## 0.2.0 pass

- Hides the root tab bar on chat/detail flows.
- Splits the chat search/menu toolbar controls into independent glass groups.
- Makes toolbar icons semantic black/white instead of inheriting the green tab tint.
- Rebuilds the composer as equal-height circle + capsule + circle glass controls.
- Adds colored action icons with primary text in the composer panel.
- Replaces the built-in wallpaper toggle with the system photo library picker.
- Pins selected wallpapers to the chat background coordinate space so keyboard changes do not move them.
- Converts text bubbles to tinted iOS 26 Liquid Glass.
- Reworks stacked photo messages with fan expansion and swipe-to-cycle top-card behavior.
- Seeds the family group so it never opens as an empty chat.

## Notes for the next optimization pass

The code is deliberately componentized rather than pixel-hardcoded. For a 90%+ visual pass, focus on:
1. exact list row heights and typography;
2. exact toolbar spacing from the reference video;
3. fine tuning photo-stack spring/rotation curves on device;
4. more accurate avatar/background assets;
5. matching remaining secondary pages.

Do not replace the system iOS 26 tab bar with a custom drawn bar unless a device test proves a real mismatch.
