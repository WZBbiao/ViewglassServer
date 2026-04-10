#ifdef SHOULD_COMPILE_LOOKIN_SERVER 

//
//  Lookin.h
//  Lookin
//
//  Created by Li Kai on 2018/8/5.
//  https://lookin.work
//

#import <UIKit/UIKit.h>

extern NSString *const LKS_ConnectionDidEndNotificationName;

@class LookinConnectionResponseAttachment;
@class Lookin_PTChannel;

@interface LKS_ConnectionManager : NSObject

+ (instancetype)sharedInstance;

@property(nonatomic, assign) BOOL applicationIsActive;

/// 将响应发送回发起请求的 channel（多客户端路由）
- (void)respond:(LookinConnectionResponseAttachment *)data requestType:(uint32_t)requestType tag:(uint32_t)tag channel:(Lookin_PTChannel *)channel;

/// 推送通知广播给所有已连接的客户端
- (void)pushData:(NSObject *)data type:(uint32_t)type;

@end

#endif /* SHOULD_COMPILE_LOOKIN_SERVER */
