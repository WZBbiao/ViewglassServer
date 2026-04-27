#ifdef SHOULD_COMPILE_LOOKIN_SERVER
//
//  LKS_MultiplatformAdapter.m
//  
//
//  Created by nixjiang on 2024/3/12.
//

#import "LKS_MultiplatformAdapter.h"
#import <UIKit/UIKit.h>

@implementation LKS_MultiplatformAdapter

+ (BOOL)isiPad {
    static BOOL s_isiPad = NO;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *nsModel = [UIDevice currentDevice].model;
        s_isiPad = [nsModel hasPrefix:@"iPad"];
    });

    return s_isiPad;
}

+ (CGRect)mainScreenBounds {
#if TARGET_OS_VISION
    return [LKS_MultiplatformAdapter getFirstActiveWindowScene].coordinateSpace.bounds;
#else
    return [UIScreen mainScreen].bounds;
#endif
}

+ (CGFloat)mainScreenScale {
#if TARGET_OS_VISION
    return 2.f;
#else
    return [UIScreen mainScreen].scale;
#endif
}

#if TARGET_OS_VISION
+ (UIWindowScene *)getFirstActiveWindowScene {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) {
            continue;
        }
        UIWindowScene *windowScene = (UIWindowScene *)scene;
        if (windowScene.activationState == UISceneActivationStateForegroundActive) {
            return windowScene;
        }
    }
    return nil;
}
#endif

+ (UIWindow *)keyWindow {
    if (@available(iOS 13.0, tvOS 13.0, *)) {
        UIWindow *candidate = nil;
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class]) {
                continue;
            }
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            if (windowScene.activationState != UISceneActivationStateForegroundActive &&
                windowScene.activationState != UISceneActivationStateForegroundInactive) {
                continue;
            }
            if (windowScene.keyWindow) {
                return windowScene.keyWindow;
            }
            if (!candidate) {
                candidate = windowScene.windows.firstObject;
            }
        }
        if (candidate) {
            return candidate;
        }
    }
    return [UIApplication sharedApplication].keyWindow;
}

+ (NSArray<UIWindow *> *)allWindows {
    NSMutableArray<UIWindow *> *windows = [NSMutableArray new];
    if (@available(iOS 13.0, tvOS 13.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class]) {
                continue;
            }
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            if (windowScene.activationState != UISceneActivationStateForegroundActive &&
                windowScene.activationState != UISceneActivationStateForegroundInactive) {
                continue;
            }
            [windows addObjectsFromArray:windowScene.windows];

            // 以 UIModalPresentationFormSheet 形式展示的页面由系统私有 window 承载，不总在 scene.windows 中。
            UIWindow *keyWindow = windowScene.keyWindow;
            if (keyWindow && ![windows containsObject:keyWindow] && ![NSStringFromClass(keyWindow.class) containsString:@"HUD"]) {
                [windows addObject:keyWindow];
            }
        }
        if (windows.count) {
            return [windows copy];
        }
    }

    return [[UIApplication sharedApplication].windows copy];
}

@end

#endif /* SHOULD_COMPILE_LOOKIN_SERVER */
