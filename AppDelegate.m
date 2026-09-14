#import "AppDelegate.h"
#import "SceneDelegate.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
        didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    (void)application;
    (void)launchOptions;
    return YES;
}

- (UISceneConfiguration *)application:(UIApplication *)application
        configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession
        options:(UISceneConnectionOptions *)options {
    (void)application;
    (void)options;

    UISceneConfiguration *configuration =
        [[UISceneConfiguration alloc] initWithName:@"Default Configuration"
                                       sessionRole:connectingSceneSession.role];
    configuration.sceneClass = UIWindowScene.class;
    configuration.delegateClass = SceneDelegate.class;
    return configuration;
}

@end
