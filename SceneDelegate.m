#import "SceneDelegate.h"
#import <WeChat26Demo-Swift.h>

@implementation SceneDelegate
- (void)scene:(UIScene *)scene
        willConnectToSession:(UISceneSession *)session
        options:(UISceneConnectionOptions *)connectionOptions {
    (void)session;
    (void)connectionOptions;
    if (![scene isKindOfClass:UIWindowScene.class]) return;
    UIWindowScene *windowScene = (UIWindowScene *)scene;
    UIWindow *window = [[UIWindow alloc] initWithWindowScene:windowScene];
    window.rootViewController = [WeChatDemoRootFactory makeRootViewController];
    self.window = window;
    [window makeKeyAndVisible];
}
@end
