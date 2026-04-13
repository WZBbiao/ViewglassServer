#ifdef SHOULD_COMPILE_LOOKIN_SERVER 

//
//  LKS_RequestHandler.m
//  LookinServer
//
//  Created by Li Kai on 2019/1/15.
//  https://lookin.work
//

#import "LKS_RequestHandler.h"
#import "NSObject+LookinServer.h"
#import "UIImage+LookinServer.h"
#import "LKS_ConnectionManager.h"
#import "Lookin_PTChannel.h"
#import "LookinConnectionResponseAttachment.h"
#import "LookinAttributeModification.h"
#import "LookinDisplayItemDetail.h"
#import "LookinHierarchyInfo.h"
#import "LookinServerDefines.h"
#import <objc/runtime.h>
#import "LookinObject.h"
#import "LookinAppInfo.h"
#import "LKS_AttrGroupsMaker.h"
#import "LKS_InbuiltAttrModificationHandler.h"
#import "LKS_CustomAttrModificationHandler.h"
#import "LKS_AttrModificationPatchHandler.h"
#import "LKS_HierarchyDetailsHandler.h"
#import "LookinStaticAsyncUpdateTask.h"
#import "LKS_GestureTargetActionsSearcher.h"
#import "LookinWeakContainer.h"
#import "LookinTuple.h"

@interface LKS_RequestHandler ()

@property(nonatomic, strong) NSMutableSet<LKS_HierarchyDetailsHandler *> *activeDetailHandlers;

@end

@implementation LKS_RequestHandler {
    NSSet *_validRequestTypes;
}

- (instancetype)init {
    if (self = [super init]) {
        _validRequestTypes = [NSSet setWithObjects:@(LookinRequestTypePing),
                              @(LookinRequestTypeApp),
                              @(LookinRequestTypeHierarchy),
                              @(LookinRequestTypeInbuiltAttrModification),
                              @(LookinRequestTypeCustomAttrModification),
                              @(LookinRequestTypeAttrModificationPatch),
                              @(LookinRequestTypeHierarchyDetails),
                              @(LookinRequestTypeFetchObject),
                              @(LookinRequestTypeAllAttrGroups),
                              @(LookinRequestTypeAllSelectorNames),
                              @(LookinRequestTypeInvokeMethod),
                              @(LookinRequestTypeFetchImageViewImage),
                              @(LookinRequestTypeModifyRecognizerEnable),
                              @(LookinRequestTypeSemanticTap),
                              @(LookinRequestTypeSemanticLongPress),
                              @(LookinRequestTypeHighResolutionScreenshot),
                              @(LookinRequestTypeSemanticDismiss),
                              @(LookinRequestTypeSemanticTextInput),
                              @(LookinRequestTypeSemanticScrollAnimated),
                              @(LookinPush_CanceHierarchyDetails),
                              nil];
        
        self.activeDetailHandlers = [NSMutableSet set];
    }
    return self;
}

- (BOOL)canHandleRequestType:(uint32_t)requestType {
    if ([_validRequestTypes containsObject:@(requestType)]) {
        return YES;
    }
    return NO;
}

- (void)handleRequestType:(uint32_t)requestType tag:(uint32_t)tag object:(id)object channel:(Lookin_PTChannel *)channel {
    if (requestType == LookinRequestTypePing) {
        LookinConnectionResponseAttachment *responseAttachment = [LookinConnectionResponseAttachment new];
        // 当 app 处于后台时，可能可以执行代码也可能不能执行代码，如果运气好了可以执行代码，则这里直接主动使用 appIsInBackground 标识 app 处于后台，不要让 Lookin 客户端傻傻地等待超时了
        if (![LKS_ConnectionManager sharedInstance].applicationIsActive) {
            responseAttachment.appIsInBackground = YES;
        }
        [[LKS_ConnectionManager sharedInstance] respond:responseAttachment requestType:requestType tag:tag channel:channel];

    } else if (requestType == LookinRequestTypeApp) {
        // 请求可用设备信息
        if (![object isKindOfClass:[NSDictionary class]]) {
            [self _submitResponseWithError:LookinErr_Inner requestType:requestType tag:tag channel:channel];
            return;
        }
        NSDictionary<NSString *, id> *params = object;
        BOOL needImages = ((NSNumber *)params[@"needImages"]).boolValue;
        NSArray<NSNumber *> *localIdentifiers = params[@"local"];

        LookinAppInfo *appInfo = [LookinAppInfo currentInfoWithScreenshot:needImages icon:needImages localIdentifiers:localIdentifiers];

        LookinConnectionResponseAttachment *responseAttachment = [LookinConnectionResponseAttachment new];
        responseAttachment.data = appInfo;
        [[LKS_ConnectionManager sharedInstance] respond:responseAttachment requestType:requestType tag:tag channel:channel];

    } else if (requestType == LookinRequestTypeHierarchy) {
        // 从 LookinClient 1.0.4 开始有这个参数，之前是 nil
        NSString *clientVersion = nil;
        if ([object isKindOfClass:[NSDictionary class]]) {
            NSDictionary<NSString *, id> *params = object;
            NSString *version = params[@"clientVersion"];
            if ([version isKindOfClass:[NSString class]]) {
                clientVersion = version;
            }
        }

        LookinConnectionResponseAttachment *responseAttachment = [LookinConnectionResponseAttachment new];
        responseAttachment.data = [LookinHierarchyInfo staticInfoWithLookinVersion:clientVersion];
        [[LKS_ConnectionManager sharedInstance] respond:responseAttachment requestType:requestType tag:tag channel:channel];

    } else if (requestType == LookinRequestTypeInbuiltAttrModification) {
        // 请求修改某个属性
        [LKS_InbuiltAttrModificationHandler handleModification:object completion:^(LookinDisplayItemDetail *data, NSError *error) {
            LookinConnectionResponseAttachment *attachment = [LookinConnectionResponseAttachment new];
            if (error) {
                attachment.error = error;
            } else {
                attachment.data = data;
            }
            [[LKS_ConnectionManager sharedInstance] respond:attachment requestType:requestType tag:tag channel:channel];
        }];

    } else if (requestType == LookinRequestTypeCustomAttrModification) {
        BOOL succ = [LKS_CustomAttrModificationHandler handleModification:object];
        if (succ) {
            [self _submitResponseWithData:nil requestType:requestType tag:tag channel:channel];
        } else {
            [self _submitResponseWithError:LookinErr_Inner requestType:requestType tag:tag channel:channel];
        }

    } else if (requestType == LookinRequestTypeAttrModificationPatch) {
        NSArray<LookinStaticAsyncUpdateTask *> *tasks = object;
        NSUInteger dataTotalCount = tasks.count;
        [LKS_InbuiltAttrModificationHandler handlePatchWithTasks:tasks block:^(LookinDisplayItemDetail *data) {
            LookinConnectionResponseAttachment *attrAttachment = [LookinConnectionResponseAttachment new];
            attrAttachment.data = data;
            attrAttachment.dataTotalCount = dataTotalCount;
            attrAttachment.currentDataCount = 1;
            [[LKS_ConnectionManager sharedInstance] respond:attrAttachment requestType:LookinRequestTypeAttrModificationPatch tag:tag channel:channel];
        }];

    } else if (requestType == LookinRequestTypeHierarchyDetails) {
        NSArray<LookinStaticAsyncUpdateTasksPackage *> *packages = object;
        NSUInteger responsesDataTotalCount = [packages lookin_reduceInteger:^NSInteger(NSInteger accumulator, NSUInteger idx, LookinStaticAsyncUpdateTasksPackage *package) {
            accumulator += package.tasks.count;
            return accumulator;
        } initialAccumlator:0];

        LKS_HierarchyDetailsHandler *handler = [LKS_HierarchyDetailsHandler new];
        [self.activeDetailHandlers addObject:handler];

        [handler startWithPackages:packages block:^(NSArray<LookinDisplayItemDetail *> *details) {
            LookinConnectionResponseAttachment *attachment = [LookinConnectionResponseAttachment new];
            attachment.data = details;
            attachment.dataTotalCount = responsesDataTotalCount;
            attachment.currentDataCount = details.count;
            [[LKS_ConnectionManager sharedInstance] respond:attachment requestType:LookinRequestTypeHierarchyDetails tag:tag channel:channel];

        } finishedBlock:^{
            [self.activeDetailHandlers removeObject:handler];
        }];

    } else if (requestType == LookinRequestTypeFetchObject) {
        unsigned long oid = ((NSNumber *)object).unsignedLongValue;
        NSObject *object = [NSObject lks_objectWithOid:oid];
        LookinObject *lookinObj = [LookinObject instanceWithObject:object];

        LookinConnectionResponseAttachment *attach = [LookinConnectionResponseAttachment new];
        attach.data = lookinObj;
        [[LKS_ConnectionManager sharedInstance] respond:attach requestType:requestType tag:tag channel:channel];

    } else if (requestType == LookinRequestTypeAllAttrGroups) {
        unsigned long oid = ((NSNumber *)object).unsignedLongValue;
        CALayer *layer = (CALayer *)[NSObject lks_objectWithOid:oid];
        if (![layer isKindOfClass:[CALayer class]]) {
            [self _submitResponseWithError:LookinErr_ObjNotFound requestType:LookinRequestTypeAllAttrGroups tag:tag channel:channel];
            return;
        }

        NSArray<LookinAttributesGroup *> *list = [LKS_AttrGroupsMaker attrGroupsForLayer:layer];
        [self _submitResponseWithData:list requestType:LookinRequestTypeAllAttrGroups tag:tag channel:channel];

    } else if (requestType == LookinRequestTypeAllSelectorNames) {
        if (![object isKindOfClass:[NSDictionary class]]) {
            [self _submitResponseWithError:LookinErr_Inner requestType:requestType tag:tag channel:channel];
            return;
        }
        NSDictionary *params = object;
        Class targetClass = NSClassFromString(params[@"className"]);
        BOOL hasArg = [(NSNumber *)params[@"hasArg"] boolValue];
        if (!targetClass) {
            NSString *errorMsg = [NSString stringWithFormat:LKS_Localized(@"Didn't find the class named \"%@\". Please input another class and try again."), object];
            [self _submitResponseWithError:LookinErrorMake(errorMsg, @"") requestType:requestType tag:tag channel:channel];
            return;
        }

        NSArray<NSString *> *selNames = [self _methodNameListForClass:targetClass hasArg:hasArg];
        [self _submitResponseWithData:selNames requestType:requestType tag:tag channel:channel];

    } else if (requestType == LookinRequestTypeInvokeMethod) {
        if (![object isKindOfClass:[NSDictionary class]]) {
            [self _submitResponseWithError:LookinErr_Inner requestType:requestType tag:tag channel:channel];
            return;
        }
        NSDictionary *param = object;
        unsigned long oid = [param[@"oid"] unsignedLongValue];
        NSString *text = param[@"text"];
        if (!text.length) {
            [self _submitResponseWithError:LookinErr_Inner requestType:requestType tag:tag channel:channel];
            return;
        }
        NSObject *targerObj = [NSObject lks_objectWithOid:oid];
        if (!targerObj) {
            [self _submitResponseWithError:LookinErr_ObjNotFound requestType:requestType tag:tag channel:channel];
            return;
        }

        NSArray<NSString *> *args = param[@"args"] ?: @[];
        SEL targetSelector = NSSelectorFromString(text);
        if (targetSelector && [targerObj respondsToSelector:targetSelector]) {
            NSString *resultDescription;
            NSObject *resultObject;
            NSError *error;
            [self _handleInvokeWithObject:targerObj selector:targetSelector args:args resultDescription:&resultDescription resultObject:&resultObject error:&error];
            if (error) {
                [self _submitResponseWithError:error requestType:requestType tag:tag channel:channel];
                return;
            }
            NSMutableDictionary *responseData = [NSMutableDictionary dictionaryWithCapacity:2];
            if (resultDescription) {
                responseData[@"description"] = resultDescription;
            }
            if (resultObject) {
                responseData[@"object"] = resultObject;
            }
            [self _submitResponseWithData:responseData requestType:requestType tag:tag channel:channel];
        } else {
            NSString *errMsg = [NSString stringWithFormat:LKS_Localized(@"%@ doesn't have an instance method called \"%@\"."), NSStringFromClass(targerObj.class), text];
            [self _submitResponseWithError:LookinErrorMake(errMsg, @"") requestType:requestType tag:tag channel:channel];
        }

    } else if (requestType == LookinPush_CanceHierarchyDetails) {
        [self.activeDetailHandlers enumerateObjectsUsingBlock:^(LKS_HierarchyDetailsHandler * _Nonnull handler, BOOL * _Nonnull stop) {
            [handler cancel];
        }];
        [self.activeDetailHandlers removeAllObjects];

    } else if (requestType == LookinRequestTypeFetchImageViewImage) {
        if (![object isKindOfClass:[NSNumber class]]) {
            [self _submitResponseWithError:LookinErr_Inner requestType:requestType tag:tag channel:channel];
            return;
        }
        unsigned long imageViewOid = [(NSNumber *)object unsignedLongValue];
        UIImageView *imageView = (UIImageView *)[NSObject lks_objectWithOid:imageViewOid];
        if (!imageView) {
            [self _submitResponseWithError:LookinErr_ObjNotFound requestType:requestType tag:tag channel:channel];
            return;
        }
        if (![imageView isKindOfClass:[UIImageView class]]) {
            [self _submitResponseWithError:LookinErr_Inner requestType:requestType tag:tag channel:channel];
            return;
        }
        UIImage *image = imageView.image;
        NSData *imageData = [image lookin_data];
        [self _submitResponseWithData:imageData requestType:requestType tag:tag channel:channel];

    } else if (requestType == LookinRequestTypeModifyRecognizerEnable) {
        if (![object isKindOfClass:[NSDictionary class]]) {
            [self _submitResponseWithError:LookinErr_Inner requestType:requestType tag:tag channel:channel];
            return;
        }
        NSDictionary<NSString *, NSNumber *> *params = object;
        unsigned long recognizerOid = ((NSNumber *)params[@"oid"]).unsignedLongValue;
        BOOL shouldBeEnabled = ((NSNumber *)params[@"enable"]).boolValue;

        UIGestureRecognizer *recognizer = (UIGestureRecognizer *)[NSObject lks_objectWithOid:recognizerOid];
        if (!recognizer) {
            [self _submitResponseWithError:LookinErr_ObjNotFound requestType:requestType tag:tag channel:channel];
            return;
        }
        if (![recognizer isKindOfClass:[UIGestureRecognizer class]]) {
            [self _submitResponseWithError:LookinErr_Inner requestType:requestType tag:tag channel:channel];
            return;
        }
        recognizer.enabled = shouldBeEnabled;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            // dispatch 以确保拿到的 enabled 是比较新的
            [self _submitResponseWithData:@(recognizer.enabled) requestType:requestType tag:tag channel:channel];
        });
    } else if (requestType == LookinRequestTypeSemanticTap) {
        if (![object isKindOfClass:[NSDictionary class]]) {
            [self _submitResponseWithError:LookinErr_Inner requestType:requestType tag:tag channel:channel];
            return;
        }
        NSDictionary<NSString *, NSNumber *> *params = object;
        unsigned long oid = ((NSNumber *)params[@"oid"]).unsignedLongValue;
        NSObject *targetObj = [NSObject lks_objectWithOid:oid];
        if (!targetObj) {
            [self _submitResponseWithError:LookinErr_ObjNotFound requestType:requestType tag:tag channel:channel];
            return;
        }
        if (![targetObj isKindOfClass:[UIView class]]) {
            NSString *message = [NSString stringWithFormat:LKS_Localized(@"Semantic tap only supports UIView targets, got %@."), NSStringFromClass(targetObj.class)];
            [self _submitResponseWithError:LookinErrorMake(message, @"") requestType:requestType tag:tag channel:channel];
            return;
        }
        NSError *error = nil;
        NSString *detail = [self _performSemanticTapOnView:(UIView *)targetObj error:&error];
        if (error) {
            [self _submitResponseWithError:error requestType:requestType tag:tag channel:channel];
            return;
        }
        [self _submitResponseWithData:@{@"detail": detail ?: @"Triggered semantic tap"} requestType:requestType tag:tag channel:channel];
    } else if (requestType == LookinRequestTypeSemanticLongPress) {
        if (![object isKindOfClass:[NSDictionary class]]) {
            [self _submitResponseWithError:LookinErr_Inner requestType:requestType tag:tag channel:channel];
            return;
        }
        NSDictionary<NSString *, NSNumber *> *params = object;
        unsigned long oid = ((NSNumber *)params[@"oid"]).unsignedLongValue;
        NSObject *targetObj = [NSObject lks_objectWithOid:oid];
        if (!targetObj) {
            [self _submitResponseWithError:LookinErr_ObjNotFound requestType:requestType tag:tag channel:channel];
            return;
        }
        if (![targetObj isKindOfClass:[UIView class]]) {
            NSString *message = [NSString stringWithFormat:LKS_Localized(@"Semantic long press only supports UIView targets, got %@."), NSStringFromClass(targetObj.class)];
            [self _submitResponseWithError:LookinErrorMake(message, @"") requestType:requestType tag:tag channel:channel];
            return;
        }
        NSError *error = nil;
        NSString *detail = [self _performSemanticLongPressOnView:(UIView *)targetObj error:&error];
        if (error) {
            [self _submitResponseWithError:error requestType:requestType tag:tag channel:channel];
            return;
        }
        [self _submitResponseWithData:@{@"detail": detail ?: @"Triggered semantic long press"} requestType:requestType tag:tag channel:channel];
    } else if (requestType == LookinRequestTypeHighResolutionScreenshot) {
        if (![object isKindOfClass:[NSDictionary class]]) {
            [self _submitResponseWithError:LookinErr_Inner requestType:requestType tag:tag channel:channel];
            return;
        }
        NSError *error = nil;
        NSData *imageData = [self _captureHighResolutionScreenshotWithParams:(NSDictionary<NSString *, id> *)object error:&error];
        if (error || !imageData.length) {
            [self _submitResponseWithError:error ?: LookinErr_Inner requestType:requestType tag:tag channel:channel];
            return;
        }
        [self _submitResponseWithData:imageData requestType:requestType tag:tag channel:channel];
    } else if (requestType == LookinRequestTypeSemanticDismiss) {
        if (![object isKindOfClass:[NSDictionary class]]) {
            [self _submitResponseWithError:LookinErr_Inner requestType:requestType tag:tag channel:channel];
            return;
        }
        NSDictionary<NSString *, NSNumber *> *params = object;
        unsigned long oid = ((NSNumber *)params[@"oid"]).unsignedLongValue;
        NSObject *targetObj = [NSObject lks_objectWithOid:oid];
        if (!targetObj) {
            [self _submitResponseWithError:LookinErr_ObjNotFound requestType:requestType tag:tag channel:channel];
            return;
        }
        if (![targetObj isKindOfClass:[UIViewController class]]) {
            NSString *message = [NSString stringWithFormat:LKS_Localized(@"Semantic dismiss only supports UIViewController targets, got %@."), NSStringFromClass(targetObj.class)];
            [self _submitResponseWithError:LookinErrorMake(message, @"") requestType:requestType tag:tag channel:channel];
            return;
        }
        NSError *error = nil;
        NSString *detail = [self _performSemanticDismissOnViewController:(UIViewController *)targetObj error:&error];
        if (error) {
            [self _submitResponseWithError:error requestType:requestType tag:tag channel:channel];
            return;
        }
        [self _submitResponseWithData:@{@"detail": detail ?: @"Dismissed UIViewController"} requestType:requestType tag:tag channel:channel];
    } else if (requestType == LookinRequestTypeSemanticTextInput) {
        if (![object isKindOfClass:[NSDictionary class]]) {
            [self _submitResponseWithError:LookinErr_Inner requestType:requestType tag:tag channel:channel];
            return;
        }
        NSDictionary<NSString *, id> *params = object;
        unsigned long oid = ((NSNumber *)params[@"oid"]).unsignedLongValue;
        NSString *text = [params[@"text"] isKindOfClass:[NSString class]] ? (NSString *)params[@"text"] : nil;
        if (!text) {
            [self _submitResponseWithError:LookinErr_Inner requestType:requestType tag:tag channel:channel];
            return;
        }
        NSObject *targetObj = [NSObject lks_objectWithOid:oid];
        if (!targetObj) {
            [self _submitResponseWithError:LookinErr_ObjNotFound requestType:requestType tag:tag channel:channel];
            return;
        }

        NSError *error = nil;
        NSString *detail = [self _performSemanticTextInputOnObject:targetObj text:text error:&error];
        if (error) {
            [self _submitResponseWithError:error requestType:requestType tag:tag channel:channel];
            return;
        }
        [self _submitResponseWithData:@{@"detail": detail ?: @"Inserted semantic text"} requestType:requestType tag:tag channel:channel];
    } else if (requestType == LookinRequestTypeSemanticScrollAnimated) {
        if (![object isKindOfClass:[NSDictionary class]]) {
            [self _submitResponseWithError:LookinErr_Inner requestType:requestType tag:tag channel:channel];
            return;
        }
        NSDictionary<NSString *, id> *params = object;
        unsigned long oid = ((NSNumber *)params[@"oid"]).unsignedLongValue;
        CGFloat x = ((NSNumber *)params[@"x"]).doubleValue;
        CGFloat y = ((NSNumber *)params[@"y"]).doubleValue;
        NSObject *targetObj = [NSObject lks_objectWithOid:oid];
        if (!targetObj) {
            [self _submitResponseWithError:LookinErr_ObjNotFound requestType:requestType tag:tag channel:channel];
            return;
        }
        if (![targetObj isKindOfClass:[UIScrollView class]]) {
            NSString *message = [NSString stringWithFormat:LKS_Localized(@"SemanticScrollAnimated only supports UIScrollView targets, got %@."), NSStringFromClass(targetObj.class)];
            [self _submitResponseWithError:LookinErrorMake(message, @"") requestType:requestType tag:tag channel:channel];
            return;
        }
        UIScrollView *scrollView = (UIScrollView *)targetObj;
        CGPoint targetOffset = CGPointMake(x, y);
        // UIKit call must be on the main thread. Defer the TCP response until after the
        // animation finishes: UIScrollView uses Apple's standard ~0.3 s timing curve.
        dispatch_async(dispatch_get_main_queue(), ^{
            [scrollView setContentOffset:targetOffset animated:YES];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(350 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
                NSString *detail = [NSString stringWithFormat:@"contentOffset -> (%.1f, %.1f)", x, y];
                [self _submitResponseWithData:@{@"detail": detail} requestType:requestType tag:tag channel:channel];
            });
        });
    }
}

- (NSData *)_captureHighResolutionScreenshotWithParams:(NSDictionary<NSString *, id> *)params error:(NSError **)error {
    NSNumber *oidNumber = params[@"oid"];
    if (!oidNumber || oidNumber == (id)kCFNull) {
        UIImage *image = [LookinAppInfo highResolutionScreenshotImage];
        if (!image) {
            if (error) {
                *error = LookinErrorMake(LKS_Localized(@"Failed to capture a high-resolution screen screenshot."), @"");
            }
            return nil;
        }
        NSData *data = UIImagePNGRepresentation(image);
        if (!data.length && error) {
            *error = LookinErrorMake(LKS_Localized(@"Failed to encode the screen screenshot as PNG."), @"");
        }
        return data;
    }

    unsigned long oid = oidNumber.unsignedLongValue;
    NSObject *targetObj = [NSObject lks_objectWithOid:oid];
    if (!targetObj) {
        if (error) {
            *error = LookinErr_ObjNotFound;
        }
        return nil;
    }

    CALayer *layer = nil;
    if ([targetObj isKindOfClass:[CALayer class]]) {
        layer = (CALayer *)targetObj;
    } else if ([targetObj isKindOfClass:[UIView class]]) {
        layer = ((UIView *)targetObj).layer;
    }
    if (!layer) {
        if (error) {
            NSString *message = [NSString stringWithFormat:LKS_Localized(@"High-resolution node screenshot only supports UIView/CALayer targets, got %@."), NSStringFromClass(targetObj.class)];
            *error = LookinErrorMake(message, @"");
        }
        return nil;
    }

    UIImage *image = [layer lks_groupScreenshotWithLowQuality:NO];
    if (!image) {
        if (error) {
            NSString *message = [NSString stringWithFormat:LKS_Localized(@"Failed to capture a high-resolution node screenshot for %@."), NSStringFromClass(targetObj.class)];
            *error = LookinErrorMake(message, @"");
        }
        return nil;
    }
    NSData *data = UIImagePNGRepresentation(image);
    if (!data.length && error) {
        *error = LookinErrorMake(LKS_Localized(@"Failed to encode the node screenshot as PNG."), @"");
    }
    return data;
}

- (NSString *)_performSemanticTapOnView:(UIView *)view error:(NSError **)error {
    UIView *currentView = view;
    while (currentView) {
        if ([currentView isKindOfClass:[UIControl class]]) {
            NSString *detail = [self _performControlTap:(UIControl *)currentView error:error];
            if (detail || (error && *error)) {
                return detail;
            }
        }

        if ([currentView isKindOfClass:[UITableViewCell class]]) {
            NSString *detail = [self _performTableViewCellTap:(UITableViewCell *)currentView error:error];
            if (detail || (error && *error)) {
                return detail;
            }
        }

        if ([currentView isKindOfClass:[UICollectionViewCell class]]) {
            NSString *detail = [self _performCollectionViewCellTap:(UICollectionViewCell *)currentView error:error];
            if (detail || (error && *error)) {
                return detail;
            }
        }

        NSString *detail = [self _performTapGestureOnView:currentView error:error];
        if (detail || (error && *error)) {
            return detail;
        }

        currentView = currentView.superview;
    }

    NSString *message = [NSString stringWithFormat:LKS_Localized(@"Didn't find a tappable UIControl or UITapGestureRecognizer for %@."), NSStringFromClass(view.class)];
    if (error) {
        *error = LookinErrorMake(message, @"");
    }
    return nil;
}

- (NSString *)_performSemanticDismissOnViewController:(UIViewController *)viewController error:(NSError **)error {
    __block NSError *blockError = nil;
    __block NSString *detail = nil;
    void (^work)(void) = ^{
        @try {
            [viewController dismissViewControllerAnimated:YES completion:nil];
            detail = [NSString stringWithFormat:@"Dismissed %@.", NSStringFromClass(viewController.class)];
        } @catch (NSException *exception) {
            NSString *message = [NSString stringWithFormat:LKS_Localized(@"%@ raised an exception while dismissing."), NSStringFromClass(viewController.class)];
            blockError = LookinErrorMake(message, exception.description ?: @"");
        }
    };

    if ([NSThread isMainThread]) {
        work();
    } else {
        dispatch_sync(dispatch_get_main_queue(), work);
    }

    if (error) {
        *error = blockError;
    }
    return detail;
}

- (NSString *)_performSemanticTextInputOnObject:(NSObject *)targetObj text:(NSString *)text error:(NSError **)error {
    if ([targetObj isKindOfClass:[UITextField class]]) {
        return [self _performSemanticTextInputOnTextField:(UITextField *)targetObj text:text error:error];
    }
    if ([targetObj isKindOfClass:[UITextView class]]) {
        return [self _performSemanticTextInputOnTextView:(UITextView *)targetObj text:text error:error];
    }

    if (error) {
        NSString *message = [NSString stringWithFormat:LKS_Localized(@"Semantic text input only supports UITextField/UITextView targets, got %@."), NSStringFromClass(targetObj.class)];
        *error = LookinErrorMake(message, @"");
    }
    return nil;
}

- (NSString *)_performSemanticLongPressOnView:(UIView *)view error:(NSError **)error {
    UIView *currentView = view;
    while (currentView) {
        NSString *detail = [self _performLongPressGestureOnView:currentView error:error];
        if (detail || (error && *error)) {
            return detail;
        }
        currentView = currentView.superview;
    }

    NSString *message = [NSString stringWithFormat:LKS_Localized(@"Didn't find an enabled UILongPressGestureRecognizer for %@."), NSStringFromClass(view.class)];
    if (error) {
        *error = LookinErrorMake(message, @"");
    }
    return nil;
}

- (NSString *)_performSemanticTextInputOnTextField:(UITextField *)textField text:(NSString *)text error:(NSError **)error {
    __block NSError *blockError = nil;
    __block NSString *detail = nil;
    void (^work)(void) = ^{
        @try {
            [textField becomeFirstResponder];
            textField.text = text;
            [textField sendActionsForControlEvents:UIControlEventEditingChanged];
            detail = [NSString stringWithFormat:@"Inserted %lu characters into %@.", (unsigned long)text.length, NSStringFromClass(textField.class)];
        } @catch (NSException *exception) {
            NSString *message = [NSString stringWithFormat:LKS_Localized(@"%@ raised an exception while handling semantic text input."), NSStringFromClass(textField.class)];
            blockError = LookinErrorMake(message, exception.reason ?: @"");
        }
    };

    if ([NSThread isMainThread]) {
        work();
    } else {
        dispatch_sync(dispatch_get_main_queue(), work);
    }

    if (error) {
        *error = blockError;
    }
    return detail;
}

- (NSString *)_performSemanticTextInputOnTextView:(UITextView *)textView text:(NSString *)text error:(NSError **)error {
    __block NSError *blockError = nil;
    __block NSString *detail = nil;
    void (^work)(void) = ^{
        @try {
            [textView becomeFirstResponder];
            textView.text = text;
            textView.selectedRange = NSMakeRange(text.length, 0);
            id<UITextViewDelegate> delegate = textView.delegate;
            if ([delegate respondsToSelector:@selector(textViewDidChange:)]) {
                [delegate textViewDidChange:textView];
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:UITextViewTextDidChangeNotification object:textView];
            detail = [NSString stringWithFormat:@"Inserted %lu characters into %@.", (unsigned long)text.length, NSStringFromClass(textView.class)];
        } @catch (NSException *exception) {
            NSString *message = [NSString stringWithFormat:LKS_Localized(@"%@ raised an exception while handling semantic text input."), NSStringFromClass(textView.class)];
            blockError = LookinErrorMake(message, exception.reason ?: @"");
        }
    };

    if ([NSThread isMainThread]) {
        work();
    } else {
        dispatch_sync(dispatch_get_main_queue(), work);
    }

    if (error) {
        *error = blockError;
    }
    return detail;
}

- (NSString *)_performTableViewCellTap:(UITableViewCell *)cell error:(NSError **)error {
    UITableView *tableView = [self _enclosingTableViewForView:cell];
    if (!tableView || !tableView.allowsSelection) {
        return nil;
    }

    NSIndexPath *indexPath = [tableView indexPathForCell:cell];
    if (!indexPath) {
        return nil;
    }

    __block NSError *blockError = nil;
    __block NSString *detail = nil;
    void (^work)(void) = ^{
        @try {
            [tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
            id<UITableViewDelegate> delegate = tableView.delegate;
            if ([delegate respondsToSelector:@selector(tableView:didSelectRowAtIndexPath:)]) {
                [delegate tableView:tableView didSelectRowAtIndexPath:indexPath];
            }
            detail = [NSString stringWithFormat:@"Selected %@ at section %ld row %ld.",
                      NSStringFromClass(cell.class),
                      (long)indexPath.section,
                      (long)indexPath.row];
        } @catch (NSException *exception) {
            NSString *message = [NSString stringWithFormat:LKS_Localized(@"%@ raised an exception while selecting a table view cell."), NSStringFromClass(cell.class)];
            blockError = LookinErrorMake(message, exception.reason ?: @"");
        }
    };

    if ([NSThread isMainThread]) {
        work();
    } else {
        dispatch_sync(dispatch_get_main_queue(), work);
    }

    if (error) {
        *error = blockError;
    }
    return detail;
}

- (NSString *)_performCollectionViewCellTap:(UICollectionViewCell *)cell error:(NSError **)error {
    UICollectionView *collectionView = [self _enclosingCollectionViewForView:cell];
    if (!collectionView || !collectionView.allowsSelection) {
        return nil;
    }

    NSIndexPath *indexPath = [collectionView indexPathForCell:cell];
    if (!indexPath) {
        return nil;
    }

    __block NSError *blockError = nil;
    __block NSString *detail = nil;
    void (^work)(void) = ^{
        @try {
            [collectionView selectItemAtIndexPath:indexPath animated:NO scrollPosition:UICollectionViewScrollPositionNone];
            id<UICollectionViewDelegate> delegate = collectionView.delegate;
            if ([delegate respondsToSelector:@selector(collectionView:didSelectItemAtIndexPath:)]) {
                [delegate collectionView:collectionView didSelectItemAtIndexPath:indexPath];
            }
            detail = [NSString stringWithFormat:@"Selected %@ at section %ld item %ld.",
                      NSStringFromClass(cell.class),
                      (long)indexPath.section,
                      (long)indexPath.item];
        } @catch (NSException *exception) {
            NSString *message = [NSString stringWithFormat:LKS_Localized(@"%@ raised an exception while selecting a collection view cell."), NSStringFromClass(cell.class)];
            blockError = LookinErrorMake(message, exception.reason ?: @"");
        }
    };

    if ([NSThread isMainThread]) {
        work();
    } else {
        dispatch_sync(dispatch_get_main_queue(), work);
    }

    if (error) {
        *error = blockError;
    }
    return detail;
}

- (UITableView *)_enclosingTableViewForView:(UIView *)view {
    UIView *current = view.superview;
    while (current) {
        if ([current isKindOfClass:[UITableView class]]) {
            return (UITableView *)current;
        }
        current = current.superview;
    }
    return nil;
}

- (UICollectionView *)_enclosingCollectionViewForView:(UIView *)view {
    UIView *current = view.superview;
    while (current) {
        if ([current isKindOfClass:[UICollectionView class]]) {
            return (UICollectionView *)current;
        }
        current = current.superview;
    }
    return nil;
}

- (NSString *)_performControlTap:(UIControl *)control error:(NSError **)error {
    SEL selector = @selector(sendActionsForControlEvents:);
    if (![control respondsToSelector:selector]) {
        return nil;
    }
    @try {
        [control sendActionsForControlEvents:UIControlEventTouchUpInside];
        return [NSString stringWithFormat:@"Triggered UIControlEventTouchUpInside on %@", NSStringFromClass(control.class)];
    } @catch (NSException *exception) {
        if (error) {
            NSString *message = [NSString stringWithFormat:LKS_Localized(@"%@ raised an exception while handling touchUpInside."), NSStringFromClass(control.class)];
            *error = LookinErrorMake(message, exception.reason ?: @"");
        }
        return nil;
    }
}

- (NSString *)_performTapGestureOnView:(UIView *)view error:(NSError **)error {
    for (UIGestureRecognizer *recognizer in view.gestureRecognizers) {
        if (![recognizer isKindOfClass:[UITapGestureRecognizer class]] || !recognizer.enabled) {
            continue;
        }
        NSString *detail = [self _invokeTapGestureRecognizer:(UITapGestureRecognizer *)recognizer error:error];
        if (detail || (error && *error)) {
            return detail;
        }
    }
    return nil;
}

- (NSString *)_performLongPressGestureOnView:(UIView *)view error:(NSError **)error {
    for (UIGestureRecognizer *recognizer in view.gestureRecognizers) {
        if (![recognizer isKindOfClass:[UILongPressGestureRecognizer class]] || !recognizer.enabled) {
            continue;
        }
        NSString *detail = [self _invokeLongPressGestureRecognizer:(UILongPressGestureRecognizer *)recognizer error:error];
        if (detail || (error && *error)) {
            return detail;
        }
    }
    return nil;
}

- (NSString *)_invokeTapGestureRecognizer:(UITapGestureRecognizer *)recognizer error:(NSError **)error {
    NSArray<LookinTwoTuple *> *targetActions = [LKS_GestureTargetActionsSearcher getTargetActionsFromRecognizer:recognizer];
    for (LookinTwoTuple *tuple in targetActions) {
        LookinWeakContainer *container = [tuple.first isKindOfClass:[LookinWeakContainer class]] ? (LookinWeakContainer *)tuple.first : nil;
        NSObject *target = container.object;
        NSString *selectorName = [tuple.second isKindOfClass:[NSString class]] ? (NSString *)tuple.second : nil;
        if (!target || selectorName.length == 0 || [selectorName isEqualToString:@"NULL"]) {
            continue;
        }
        if (![self _isSemanticGestureTarget:target selectorName:selectorName recognizer:recognizer]) {
            continue;
        }
        SEL selector = NSSelectorFromString(selectorName);
        if (![target respondsToSelector:selector]) {
            continue;
        }

        NSMethodSignature *signature = [target methodSignatureForSelector:selector];
        if (!signature) {
            continue;
        }

        if (signature.numberOfArguments > 3) {
            continue;
        }

        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
        invocation.target = target;
        invocation.selector = selector;
        if (signature.numberOfArguments == 3) {
            UIGestureRecognizer *argRecognizer = recognizer;
            [invocation setArgument:&argRecognizer atIndex:2];
        }

        NSString *detail = [self _invokeGestureInvocation:invocation selectorName:selectorName target:target recognizer:recognizer injectLongPressState:NO error:error];
        if (detail || (error && *error)) {
            return detail;
        }
    }

    NSString *fallbackDetail = [self _invokeGestureRecognizerViaResponderChain:recognizer injectLongPressState:NO error:error];
    if (fallbackDetail || (error && *error)) {
        return fallbackDetail;
    }

    return nil;
}

- (NSString *)_invokeLongPressGestureRecognizer:(UILongPressGestureRecognizer *)recognizer error:(NSError **)error {
    NSArray<LookinTwoTuple *> *targetActions = [LKS_GestureTargetActionsSearcher getTargetActionsFromRecognizer:recognizer];
    for (LookinTwoTuple *tuple in targetActions) {
        LookinWeakContainer *container = [tuple.first isKindOfClass:[LookinWeakContainer class]] ? (LookinWeakContainer *)tuple.first : nil;
        NSObject *target = container.object;
        NSString *selectorName = [tuple.second isKindOfClass:[NSString class]] ? (NSString *)tuple.second : nil;
        if (!target || selectorName.length == 0 || [selectorName isEqualToString:@"NULL"]) {
            continue;
        }
        if (![self _isSemanticGestureTarget:target selectorName:selectorName recognizer:recognizer]) {
            continue;
        }
        SEL selector = NSSelectorFromString(selectorName);
        if (![target respondsToSelector:selector]) {
            continue;
        }

        NSMethodSignature *signature = [target methodSignatureForSelector:selector];
        if (!signature || signature.numberOfArguments > 3) {
            continue;
        }

        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
        invocation.target = target;
        invocation.selector = selector;
        if (signature.numberOfArguments == 3) {
            UIGestureRecognizer *argRecognizer = recognizer;
            [invocation setArgument:&argRecognizer atIndex:2];
        }

        NSString *detail = [self _invokeGestureInvocation:invocation selectorName:selectorName target:target recognizer:recognizer injectLongPressState:YES error:error];
        if (detail || (error && *error)) {
            return detail;
        }
    }

    NSString *fallbackDetail = [self _invokeGestureRecognizerViaResponderChain:recognizer injectLongPressState:YES error:error];
    if (fallbackDetail || (error && *error)) {
        return fallbackDetail;
    }

    return nil;
}

- (NSString *)_invokeGestureInvocation:(NSInvocation *)invocation selectorName:(NSString *)selectorName target:(NSObject *)target recognizer:(UIGestureRecognizer *)recognizer injectLongPressState:(BOOL)injectLongPressState error:(NSError **)error {
    NSNumber *originalState = nil;
    BOOL didOverrideState = NO;
    if (injectLongPressState && [recognizer isKindOfClass:[UILongPressGestureRecognizer class]]) {
        @try {
            originalState = [recognizer valueForKey:@"state"];
            [recognizer setValue:@(UIGestureRecognizerStateBegan) forKey:@"state"];
            didOverrideState = YES;
        } @catch (__unused NSException *exception) {
            didOverrideState = NO;
        }
    }

    @try {
        [invocation invoke];
        return [NSString stringWithFormat:@"Triggered %@ on %@ via %@", selectorName, NSStringFromClass(target.class), NSStringFromClass(recognizer.class)];
    } @catch (NSException *exception) {
        if (error) {
            NSString *message = [NSString stringWithFormat:LKS_Localized(@"%@ raised an exception while invoking %@."), NSStringFromClass(target.class), selectorName];
            *error = LookinErrorMake(message, exception.reason ?: @"");
        }
        return nil;
    } @finally {
        if (didOverrideState) {
            @try {
                [recognizer setValue:originalState forKey:@"state"];
            } @catch (__unused NSException *exception) {
            }
        }
    }
}

- (BOOL)_isSemanticGestureTarget:(NSObject *)target selectorName:(NSString *)selectorName recognizer:(UIGestureRecognizer *)recognizer {
    if (selectorName.length == 0) {
        return NO;
    }

    NSString *targetClassName = NSStringFromClass(target.class);
    NSString *recognizerClassName = NSStringFromClass(recognizer.class);

    if ([selectorName hasPrefix:@"_"]) {
        return NO;
    }
    if ([targetClassName hasPrefix:@"_"] || [recognizerClassName hasPrefix:@"_"]) {
        return NO;
    }
    if ([target isKindOfClass:[UIWindow class]]) {
        return NO;
    }
    if ([recognizer.view isKindOfClass:[UIWindow class]]) {
        return NO;
    }
    if ([targetClassName hasPrefix:@"UI"] || [targetClassName hasPrefix:@"NS"]) {
        return NO;
    }

    return YES;
}

- (NSString *)_invokeGestureRecognizerViaResponderChain:(UIGestureRecognizer *)recognizer injectLongPressState:(BOOL)injectLongPressState error:(NSError **)error {
    NSString *description = recognizer.description ?: @"";
    NSRange actionRange = [description rangeOfString:@"action="];
    if (actionRange.location == NSNotFound) {
        return nil;
    }
    NSUInteger start = NSMaxRange(actionRange);
    NSRange tailRange = NSMakeRange(start, description.length - start);
    NSRange endRange = [description rangeOfString:@"," options:0 range:tailRange];
    if (endRange.location == NSNotFound || endRange.location <= start) {
        return nil;
    }

    NSString *selectorName = [[description substringWithRange:NSMakeRange(start, endRange.location - start)] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (selectorName.length == 0 || [selectorName hasPrefix:@"_"]) {
        return nil;
    }
    SEL selector = NSSelectorFromString(selectorName);

    UIResponder *responder = recognizer.view;
    while (responder) {
        if ([responder respondsToSelector:selector]) {
            NSMethodSignature *signature = [(NSObject *)responder methodSignatureForSelector:selector];
            if (!signature || signature.numberOfArguments > 3) {
                return nil;
            }

            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
            invocation.target = responder;
            invocation.selector = selector;
            if (signature.numberOfArguments == 3) {
                UIGestureRecognizer *argRecognizer = recognizer;
                [invocation setArgument:&argRecognizer atIndex:2];
            }

            @try {
                if (injectLongPressState && [recognizer isKindOfClass:[UILongPressGestureRecognizer class]]) {
                    NSNumber *originalState = [recognizer valueForKey:@"state"];
                    [recognizer setValue:@(UIGestureRecognizerStateBegan) forKey:@"state"];
                    [invocation invoke];
                    [recognizer setValue:originalState forKey:@"state"];
                } else {
                    [invocation invoke];
                }
                return [NSString stringWithFormat:@"Triggered %@ on %@ via responder chain", selectorName, NSStringFromClass(responder.class)];
            } @catch (NSException *exception) {
                if (error) {
                    NSString *message = [NSString stringWithFormat:LKS_Localized(@"%@ raised an exception while invoking %@."), NSStringFromClass(responder.class), selectorName];
                    *error = LookinErrorMake(message, exception.reason ?: @"");
                }
                return nil;
            }
        }
        responder = responder.nextResponder;
    }

    return nil;
}

- (NSArray<NSString *> *)_methodNameListForClass:(Class)aClass hasArg:(BOOL)hasArg {
    NSSet<NSString *> *prefixesToVoid = [NSSet setWithObjects:@"_", @"CA_", @"cpl", @"mf_", @"vs_", @"pep_", @"isNS", @"avkit_", @"PG_", @"px_", @"pl_", @"nsli_", @"pu_", @"pxg_", nil];
    NSMutableArray<NSString *> *array = [NSMutableArray array];
    
    Class currentClass = aClass;
    while (currentClass) {
        NSString *className = NSStringFromClass(currentClass);
        BOOL isSystemClass = ([className hasPrefix:@"UI"] || [className hasPrefix:@"CA"] || [className hasPrefix:@"NS"]);
        
        unsigned int methodCount = 0;
        Method *methods = class_copyMethodList(currentClass, &methodCount);
        for (unsigned int i = 0; i < methodCount; i++) {
            NSString *selName = NSStringFromSelector(method_getName(methods[i]));
            
            if (!hasArg && [selName containsString:@":"]) {
                continue;
            }
            
            if (isSystemClass) {
                BOOL invalid = [prefixesToVoid lookin_any:^BOOL(NSString *prefix) {
                    return [selName hasPrefix:prefix];
                }];
                if (invalid) {
                    continue;
                }
            }
            if (selName.length && ![array containsObject:selName]) {
                [array addObject:selName];
            }
        }
        if (methods) free(methods);
        currentClass = [currentClass superclass];
    }

    return [array lookin_sortedArrayByStringLength];
}

/// Coerce a string value to the ObjC type described by typeEncoding and set it as an argument
/// on invocation at the given index. Returns NO and sets *error on failure.
- (BOOL)_setInvocation:(NSInvocation *)invocation
           argAtIndex:(NSUInteger)index
         typeEncoding:(const char *)typeEncoding
          valueString:(NSString *)valueString
                error:(NSError **)error {
    if (strcmp(typeEncoding, @encode(char)) == 0) {
        char v = (char)[valueString integerValue];
        [invocation setArgument:&v atIndex:index];
    } else if (strcmp(typeEncoding, @encode(int)) == 0) {
        int v = (int)[valueString integerValue];
        [invocation setArgument:&v atIndex:index];
    } else if (strcmp(typeEncoding, @encode(short)) == 0) {
        short v = (short)[valueString integerValue];
        [invocation setArgument:&v atIndex:index];
    } else if (strcmp(typeEncoding, @encode(long)) == 0) {
        long v = (long)[valueString longLongValue];
        [invocation setArgument:&v atIndex:index];
    } else if (strcmp(typeEncoding, @encode(long long)) == 0) {
        long long v = [valueString longLongValue];
        [invocation setArgument:&v atIndex:index];
    } else if (strcmp(typeEncoding, @encode(unsigned char)) == 0) {
        unsigned char v = (unsigned char)[valueString integerValue];
        [invocation setArgument:&v atIndex:index];
    } else if (strcmp(typeEncoding, @encode(unsigned int)) == 0) {
        unsigned int v = (unsigned int)[valueString longLongValue];
        [invocation setArgument:&v atIndex:index];
    } else if (strcmp(typeEncoding, @encode(unsigned short)) == 0) {
        unsigned short v = (unsigned short)[valueString longLongValue];
        [invocation setArgument:&v atIndex:index];
    } else if (strcmp(typeEncoding, @encode(unsigned long)) == 0) {
        unsigned long v = (unsigned long)[valueString longLongValue];
        [invocation setArgument:&v atIndex:index];
    } else if (strcmp(typeEncoding, @encode(unsigned long long)) == 0) {
        unsigned long long v = strtoull([valueString UTF8String], NULL, 0);
        [invocation setArgument:&v atIndex:index];
    } else if (strcmp(typeEncoding, @encode(float)) == 0) {
        float v = [valueString floatValue];
        [invocation setArgument:&v atIndex:index];
    } else if (strcmp(typeEncoding, @encode(double)) == 0) {
        double v = [valueString doubleValue];
        [invocation setArgument:&v atIndex:index];
    } else if (strcmp(typeEncoding, @encode(BOOL)) == 0) {
        BOOL v = ([valueString isEqualToString:@"YES"] || [valueString isEqualToString:@"true"] || [valueString isEqualToString:@"1"]) ? YES : [valueString boolValue];
        [invocation setArgument:&v atIndex:index];
    } else if (strcmp(typeEncoding, @encode(CGPoint)) == 0) {
        CGPoint v = CGPointFromString(valueString);
        [invocation setArgument:&v atIndex:index];
    } else if (strcmp(typeEncoding, @encode(CGSize)) == 0) {
        CGSize v = CGSizeFromString(valueString);
        [invocation setArgument:&v atIndex:index];
    } else if (strcmp(typeEncoding, @encode(CGRect)) == 0) {
        CGRect v = CGRectFromString(valueString);
        [invocation setArgument:&v atIndex:index];
    } else if (strcmp(typeEncoding, @encode(CGAffineTransform)) == 0) {
        CGAffineTransform v = CGAffineTransformFromString(valueString);
        [invocation setArgument:&v atIndex:index];
    } else if (strcmp(typeEncoding, @encode(UIEdgeInsets)) == 0) {
        UIEdgeInsets v = UIEdgeInsetsFromString(valueString);
        [invocation setArgument:&v atIndex:index];
    } else {
        // Handle object types and NSDirectionalEdgeInsets
        if (@available(iOS 11.0, *)) {
            if (strcmp(typeEncoding, @encode(NSDirectionalEdgeInsets)) == 0) {
                NSDirectionalEdgeInsets v = NSDirectionalEdgeInsetsFromString(valueString);
                [invocation setArgument:&v atIndex:index];
                return YES;
            }
        }
        NSString *typeStr = [[NSString alloc] lookin_safeInitWithUTF8String:typeEncoding];
        if ([typeStr hasPrefix:@"@"]) {
            __unsafe_unretained NSObject *objValue = nil;
            if ([typeStr isEqualToString:@"@"] || [typeStr isEqualToString:@"@\"NSString\""]) {
                objValue = valueString;
            } else if ([typeStr isEqualToString:@"@\"NSNumber\""]) {
                objValue = @([valueString doubleValue]);
            } else {
                // Try to resolve by OID
                long long possibleOid = [valueString longLongValue];
                if (possibleOid > 0 && [valueString longLongValue] != 0) {
                    objValue = [NSObject lks_objectWithOid:(unsigned long)possibleOid];
                    if (!objValue) {
                        NSString *notFoundMsg = [NSString stringWithFormat:LKS_Localized(@"No object found with OID %lld."), possibleOid];
                        *error = LookinErrorMake(notFoundMsg, @"");
                        return NO;
                    }
                } else {
                    NSString *cantConvertMsg = [NSString stringWithFormat:LKS_Localized(@"Can't convert \"%@\" to %@. Provide an OID (integer) to reference objects."), valueString, typeStr];
                    *error = LookinErrorMake(cantConvertMsg, @"");
                    return NO;
                }
            }
            [invocation setArgument:&objValue atIndex:index];
        } else {
            NSString *unsupportedMsg = [NSString stringWithFormat:LKS_Localized(@"Unsupported argument type encoding \"%s\"."), typeEncoding];
            *error = LookinErrorMake(unsupportedMsg, @"");
            return NO;
        }
    }
    return YES;
}

- (void)_handleInvokeWithObject:(NSObject *)obj selector:(SEL)selector args:(NSArray<NSString *> *)args resultDescription:(NSString **)description resultObject:(LookinObject **)resultObject error:(NSError **)error {
    if (![obj respondsToSelector:selector]) {
        NSString *message = [NSString stringWithFormat:LKS_Localized(@"%@ doesn't respond to %@."), NSStringFromClass(obj.class), NSStringFromSelector(selector)];
        *error = LookinErrorMake(message, @"");
        return;
    }
    NSMethodSignature *signature = [obj methodSignatureForSelector:selector];
    if (!signature) {
        NSString *message = [NSString stringWithFormat:LKS_Localized(@"Missing method signature for %@."), NSStringFromSelector(selector)];
        *error = LookinErrorMake(message, @"");
        return;
    }
    // numberOfArguments includes self (index 0) and _cmd (index 1); user args start at index 2
    NSUInteger expectedArgCount = signature.numberOfArguments - 2;
    if (args.count != expectedArgCount) {
        NSString *argCountMsg = [NSString stringWithFormat:LKS_Localized(@"%@ expects %lu argument(s), but %lu were provided."),
                                 NSStringFromSelector(selector),
                                 (unsigned long)expectedArgCount,
                                 (unsigned long)args.count];
        *error = LookinErrorMake(argCountMsg, @"");
        return;
    }

    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    [invocation setTarget:obj];
    [invocation setSelector:selector];
    [invocation retainArguments];

    for (NSUInteger i = 0; i < expectedArgCount; i++) {
        const char *argType = [signature getArgumentTypeAtIndex:i + 2];
        NSError *setError = nil;
        if (![self _setInvocation:invocation argAtIndex:i + 2 typeEncoding:argType valueString:args[i] error:&setError]) {
            *error = setError;
            return;
        }
    }

    @try {
        [invocation invoke];
    } @catch (NSException *exception) {
        NSString *message = [NSString stringWithFormat:LKS_Localized(@"%@ raised an exception when invoking %@."), NSStringFromClass(obj.class), NSStringFromSelector(selector)];
        *error = LookinErrorMake(message, exception.reason ?: @"");
        return;
    }

    const char *returnType = [signature methodReturnType];
    
    
    if (strcmp(returnType, @encode(void)) == 0) {
        //void, do nothing
        *description = LookinStringFlag_VoidReturn;
        
    } else if (strcmp(returnType, @encode(char)) == 0) {
        char charValue;
        [invocation getReturnValue:&charValue];
        *description = [NSString stringWithFormat:@"%@", @(charValue)];
        
    } else if (strcmp(returnType, @encode(int)) == 0) {
        int intValue;
        [invocation getReturnValue:&intValue];
        if (intValue == INT_MAX) {
            *description = @"INT_MAX";
        } else if (intValue == INT_MIN) {
            *description = @"INT_MIN";
        } else {
            *description = [NSString stringWithFormat:@"%@", @(intValue)];
        }
        
    } else if (strcmp(returnType, @encode(short)) == 0) {
        short shortValue;
        [invocation getReturnValue:&shortValue];
        if (shortValue == SHRT_MAX) {
            *description = @"SHRT_MAX";
        } else if (shortValue == SHRT_MIN) {
            *description = @"SHRT_MIN";
        } else {
            *description = [NSString stringWithFormat:@"%@", @(shortValue)];
        }
        
    } else if (strcmp(returnType, @encode(long)) == 0) {
        long longValue;
        [invocation getReturnValue:&longValue];
        if (longValue == NSNotFound) {
            *description = @"NSNotFound";
        } else if (longValue == LONG_MAX) {
            *description = @"LONG_MAX";
        } else if (longValue == LONG_MIN) {
            *description = @"LONG_MAX";
        } else {
            *description = [NSString stringWithFormat:@"%@", @(longValue)];
        }
        
    } else if (strcmp(returnType, @encode(long long)) == 0) {
        long long longLongValue;
        [invocation getReturnValue:&longLongValue];
        if (longLongValue == LLONG_MAX) {
            *description = @"LLONG_MAX";
        } else if (longLongValue == LLONG_MIN) {
            *description = @"LLONG_MIN";
        } else {
            *description = [NSString stringWithFormat:@"%@", @(longLongValue)];
        }
        
    } else if (strcmp(returnType, @encode(unsigned char)) == 0) {
        unsigned char ucharValue;
        [invocation getReturnValue:&ucharValue];
        if (ucharValue == UCHAR_MAX) {
            *description = @"UCHAR_MAX";
        } else {
            *description = [NSString stringWithFormat:@"%@", @(ucharValue)];
        }
        
    } else if (strcmp(returnType, @encode(unsigned int)) == 0) {
        unsigned int uintValue;
        [invocation getReturnValue:&uintValue];
        if (uintValue == UINT_MAX) {
            *description = @"UINT_MAX";
        } else {
            *description = [NSString stringWithFormat:@"%@", @(uintValue)];
        }
        
    } else if (strcmp(returnType, @encode(unsigned short)) == 0) {
        unsigned short ushortValue;
        [invocation getReturnValue:&ushortValue];
        if (ushortValue == USHRT_MAX) {
            *description = @"USHRT_MAX";
        } else {
            *description = [NSString stringWithFormat:@"%@", @(ushortValue)];
        }
        
    } else if (strcmp(returnType, @encode(unsigned long)) == 0) {
        unsigned long ulongValue;
        [invocation getReturnValue:&ulongValue];
        if (ulongValue == ULONG_MAX) {
            *description = @"ULONG_MAX";
        } else {
            *description = [NSString stringWithFormat:@"%@", @(ulongValue)];
        }
        
    } else if (strcmp(returnType, @encode(unsigned long long)) == 0) {
        unsigned long long ulongLongValue;
        [invocation getReturnValue:&ulongLongValue];
        if (ulongLongValue == ULONG_LONG_MAX) {
            *description = @"ULONG_LONG_MAX";
        } else {
            *description = [NSString stringWithFormat:@"%@", @(ulongLongValue)];
        }
        
    } else if (strcmp(returnType, @encode(float)) == 0) {
        float floatValue;
        [invocation getReturnValue:&floatValue];
        if (floatValue == FLT_MAX) {
            *description = @"FLT_MAX";
        } else if (floatValue == FLT_MIN) {
            *description = @"FLT_MIN";
        } else {
            *description = [NSString stringWithFormat:@"%@", @(floatValue)];
        }
        
    } else if (strcmp(returnType, @encode(double)) == 0) {
        double doubleValue;
        [invocation getReturnValue:&doubleValue];
        if (doubleValue == DBL_MAX) {
            *description = @"DBL_MAX";
        } else if (doubleValue == DBL_MIN) {
            *description = @"DBL_MIN";
        } else {
            *description = [NSString stringWithFormat:@"%@", @(doubleValue)];
        }
        
    } else if (strcmp(returnType, @encode(BOOL)) == 0) {
        BOOL boolValue;
        [invocation getReturnValue:&boolValue];
        *description = boolValue ? @"YES" : @"NO";
        
    } else if (strcmp(returnType, @encode(SEL)) == 0) {
        SEL selValue;
        [invocation getReturnValue:&selValue];
        *description = [NSString stringWithFormat:@"SEL(%@)", NSStringFromSelector(selValue)];
        
    } else if (strcmp(returnType, @encode(Class)) == 0) {
        Class classValue;
        [invocation getReturnValue:&classValue];
        *description = [NSString stringWithFormat:@"<%@>", NSStringFromClass(classValue)];
        
    } else if (strcmp(returnType, @encode(CGPoint)) == 0) {
        CGPoint targetValue;
        [invocation getReturnValue:&targetValue];
        *description = NSStringFromCGPoint(targetValue);

    } else if (strcmp(returnType, @encode(CGVector)) == 0) {
        CGVector targetValue;
        [invocation getReturnValue:&targetValue];
        *description = NSStringFromCGVector(targetValue);

    } else if (strcmp(returnType, @encode(CGSize)) == 0) {
        CGSize targetValue;
        [invocation getReturnValue:&targetValue];
        *description = NSStringFromCGSize(targetValue);

    } else if (strcmp(returnType, @encode(CGRect)) == 0) {
        CGRect rectValue;
        [invocation getReturnValue:&rectValue];
        *description = NSStringFromCGRect(rectValue);
        
    } else if (strcmp(returnType, @encode(CGAffineTransform)) == 0) {
        CGAffineTransform rectValue;
        [invocation getReturnValue:&rectValue];
        *description = NSStringFromCGAffineTransform(rectValue);
        
    } else if (strcmp(returnType, @encode(UIEdgeInsets)) == 0) {
        UIEdgeInsets targetValue;
        [invocation getReturnValue:&targetValue];
        *description = NSStringFromUIEdgeInsets(targetValue);
        
    } else if (strcmp(returnType, @encode(UIOffset)) == 0) {
        UIOffset targetValue;
        [invocation getReturnValue:&targetValue];
        *description = NSStringFromUIOffset(targetValue);
        
    } else {
        if (@available(iOS 11.0, tvOS 11.0, *)) {
            if (strcmp(returnType, @encode(NSDirectionalEdgeInsets)) == 0) {
                NSDirectionalEdgeInsets targetValue;
                [invocation getReturnValue:&targetValue];
                *description = NSStringFromDirectionalEdgeInsets(targetValue);
                return;
            }
        }
        
        NSString *argType_string = [[NSString alloc] lookin_safeInitWithUTF8String:returnType];
        if ([argType_string hasPrefix:@"@"] || [argType_string hasPrefix:@"^{"]) {
            __unsafe_unretained id returnObjValue;
            [invocation getReturnValue:&returnObjValue];
            
            if (returnObjValue) {
                *description = [NSString stringWithFormat:@"%@", returnObjValue];
                
                LookinObject *parsedLookinObj = [LookinObject instanceWithObject:returnObjValue];
                *resultObject = parsedLookinObj;
            } else {
                *description = @"nil";
            }
        } else {
            *description = [NSString stringWithFormat:LKS_Localized(@"%@ was invoked successfully, but Lookin can't parse the return value:%@"), NSStringFromSelector(selector), argType_string];
        }
    }
}

- (void)_submitResponseWithError:(NSError *)error requestType:(uint32_t)requestType tag:(uint32_t)tag channel:(Lookin_PTChannel *)channel {
    LookinConnectionResponseAttachment *attachment = [LookinConnectionResponseAttachment new];
    attachment.error = error;
    [[LKS_ConnectionManager sharedInstance] respond:attachment requestType:requestType tag:tag channel:channel];
}

- (void)_submitResponseWithData:(NSObject *)data requestType:(uint32_t)requestType tag:(uint32_t)tag channel:(Lookin_PTChannel *)channel {
    LookinConnectionResponseAttachment *attachment = [LookinConnectionResponseAttachment new];
    attachment.data = data;
    [[LKS_ConnectionManager sharedInstance] respond:attachment requestType:requestType tag:tag channel:channel];
}

@end

#endif /* SHOULD_COMPILE_LOOKIN_SERVER */
