# Reference-video implementation notes

Source reference: user-supplied 4:01 iOS 26 demo video (512x910, 30 fps).

This first pass intentionally targets about 70-80% demo fidelity, not production behavior.
The implementation follows these rules:

- keep the iOS 26 system TabView/search tab/minimization instead of redrawing it;
- keep system navigation, Form/List, Menu, alerts, swipe actions and automatic dark mode;
- custom-build only chat bubbles, stacked photo animation, fake picker and composer panel;
- keep all data offline and in memory;
- preserve the video's primary navigation path: Chats -> chat -> details/background/photos -> other tabs -> group/contact actions -> dark mode.

The `Reference/reference_contact.jpg` sheet contains representative frames extracted from the supplied video for the next visual tuning pass.
