#ifdef SHOULD_COMPILE_LOOKIN_SERVER 

//
//  LookinServer.m
//  LookinServer
//
//  Created by Li Kai on 2018/8/5.
//  https://lookin.work
//

#import "LKS_ConnectionManager.h"
#import "Lookin_PTChannel.h"
#import "LKS_RequestHandler.h"
#import "LookinConnectionResponseAttachment.h"
#import "LKS_ExportManager.h"
#import "LookinServerDefines.h"
#import "LKS_TraceManager.h"
#import "LKS_MultiplatformAdapter.h"

NSString *const LKS_ConnectionDidEndNotificationName = @"LKS_ConnectionDidEndNotificationName";

@interface LKS_ConnectionManager () <Lookin_PTChannelDelegate, NSNetServiceDelegate>

/// 正在监听端口、等待客户端连接的 channel（非 peer）
@property(nonatomic, strong) Lookin_PTChannel *listeningChannel_;

/// 当前所有已建立连接的 peer channels（GUI + CLI 可以同时存在）
@property(nonatomic, strong) NSMutableArray<Lookin_PTChannel *> *peerChannels_;

/// Bonjour service for zero-config LAN discovery (like Xcode wireless)
@property(nonatomic, strong) NSNetService *bonjourService_;

@property(nonatomic, strong) LKS_RequestHandler *requestHandler;

@end

@implementation LKS_ConnectionManager

+ (instancetype)sharedInstance {
    static LKS_ConnectionManager *sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[LKS_ConnectionManager alloc] init];
    });
    return sharedInstance;
}

+ (void)load {
    // 触发 init 方法
    [LKS_ConnectionManager sharedInstance];
}

- (instancetype)init {
    if (self = [super init]) {
        NSLog(@"%@ - Will launch. Framework version: %@", VIEWGLASS_SERVER_READABLE_NAME, LOOKIN_SERVER_READABLE_VERSION);

        _peerChannels_ = [NSMutableArray array];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handleApplicationDidBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handleWillResignActiveNotification) name:UIApplicationWillResignActiveNotification object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handleLocalInspect:) name:@"Lookin_2D" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handleLocalInspect:) name:@"Lookin_3D" object:nil];
        [[NSNotificationCenter defaultCenter] addObserverForName:@"Lookin_Export" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
            [[LKS_ExportManager sharedInstance] exportAndShare];
        }];
        [[NSNotificationCenter defaultCenter] addObserverForName:@"Lookin_RelationSearch" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
            [[LKS_TraceManager sharedInstance] addSearchTarger:note.object];
        }];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleGetLookinInfo:) name:@"GetLookinInfo" object:nil];
        
        self.requestHandler = [LKS_RequestHandler new];
    }
    return self;
}

- (void)_handleWillResignActiveNotification {
    self.applicationIsActive = NO;
    [self _stopBonjourService];

    for (Lookin_PTChannel *channel in [self.peerChannels_ copy]) {
        if (![channel isConnected]) {
            [channel close];
            [self.peerChannels_ removeObject:channel];
        }
    }
}

- (void)_handleApplicationDidBecomeActive {
    self.applicationIsActive = YES;
    [self searchPortToListenIfNoConnection];
}

- (void)searchPortToListenIfNoConnection {
    if (self.listeningChannel_) {
        NSLog(@"%@ - Abort to search ports. Already listening on a port.", VIEWGLASS_SERVER_READABLE_NAME);
        return;
    }
    NSLog(@"%@ - Searching port to listen...", VIEWGLASS_SERVER_READABLE_NAME);

    if ([self isiOSAppOnMac]) {
        [self _tryToListenOnPortFrom:LookinSimulatorIPv4PortNumberStart to:LookinSimulatorIPv4PortNumberEnd current:LookinSimulatorIPv4PortNumberStart retryCount:0];
    } else {
        [self _tryToListenOnPortFrom:LookinUSBDeviceIPv4PortNumberStart to:LookinUSBDeviceIPv4PortNumberEnd current:LookinUSBDeviceIPv4PortNumberStart retryCount:0];
    }
}

- (BOOL)isiOSAppOnMac {
#if TARGET_OS_SIMULATOR
    return YES;
#else
    if (@available(iOS 14.0, *)) {
        // isiOSAppOnMac 这个 API 看似在 iOS 14.0 上可用，但其实在 iOS 14 beta 上是不存在的、有 unrecognized selector 问题，因此这里要用 respondsToSelector 做一下保护
        NSProcessInfo *info = [NSProcessInfo processInfo];
        if ([info respondsToSelector:@selector(isiOSAppOnMac)] && [info isiOSAppOnMac]) {
            return YES;
        } else if ([info respondsToSelector:@selector(isMacCatalystApp)] && [info isMacCatalystApp]) {
            return YES;
        } else {
            return NO;
        }
    } else if (@available(iOS 13.0, tvOS 13.0, *)) {
        return [NSProcessInfo processInfo].isMacCatalystApp;
    }
    return NO;
#endif
}

- (void)_tryToListenOnPortFrom:(int)fromPort to:(int)toPort current:(int)currentPort retryCount:(int)retryCount {
    Lookin_PTChannel *channel = [Lookin_PTChannel channelWithDelegate:self];
    channel.targetPort = currentPort;
    [channel listenOnPort:currentPort IPv4Address:INADDR_ANY callback:^(NSError *error) {
        if (error) {
            if (currentPort < toPort) {
                // 尝试下一个端口
                NSLog(@"%@ - 0.0.0.0:%d is unavailable(%@). Will try anothor address ...", VIEWGLASS_SERVER_READABLE_NAME, currentPort, error);
                [self _tryToListenOnPortFrom:fromPort to:toPort current:(currentPort + 1) retryCount:retryCount];
            } else {
                // 所有端口都尝试完毕，全部失败
                // 可能是 Peertalk accept 连接后旧 socket 尚未完全释放导致的竞争，等待一段时间后重试
                if (retryCount < 3) {
                    NSTimeInterval delay = 0.3 * (retryCount + 1);
                    NSLog(@"%@ - All ports unavailable. Retry %d/3 in %.1fs...", VIEWGLASS_SERVER_READABLE_NAME, retryCount + 1, delay);
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        if (!self.listeningChannel_) {
                            [self _tryToListenOnPortFrom:fromPort to:toPort current:fromPort retryCount:retryCount + 1];
                        }
                    });
                } else {
                    NSLog(@"%@ - Connect failed in the end after %d retries.", VIEWGLASS_SERVER_READABLE_NAME, retryCount);
                }
            }

        } else {
            // 成功
            NSLog(@"%@ - Listening on 0.0.0.0:%d (WiFi/USB)", VIEWGLASS_SERVER_READABLE_NAME, currentPort);
            // 此时 channel 状态为 listening，独立保存，不计入 peerChannels_
            self.listeningChannel_ = channel;
            [self _publishBonjourServiceOnPort:currentPort];
        }
    }];
}

- (void)dealloc {
    [self _stopBonjourService];
    [self.listeningChannel_ close];
    for (Lookin_PTChannel *channel in self.peerChannels_) {
        [channel close];
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Bonjour

/// Publish a Bonjour service so CLI/agents on the LAN can auto-discover this app.
- (void)_publishBonjourServiceOnPort:(int)port {
    [self _stopBonjourService];
    NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier] ?: @"unknown";
    self.bonjourService_ = [[NSNetService alloc] initWithDomain:@""
                                                          type:@"_lookin._tcp."
                                                          name:bundleId
                                                          port:port];
    // TXT record carries metadata for the CLI to display before full handshake.
    NSDictionary<NSString *, NSData *> *txt = @{
        @"bundleId": [bundleId dataUsingEncoding:NSUTF8StringEncoding],
        @"appName": [([[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"] ?: @"") dataUsingEncoding:NSUTF8StringEncoding],
        @"version": [LOOKIN_SERVER_READABLE_VERSION dataUsingEncoding:NSUTF8StringEncoding]
    };
    [self.bonjourService_ setTXTRecordData:[NSNetService dataFromTXTRecordDictionary:txt]];
    self.bonjourService_.delegate = self;
    [self.bonjourService_ publish];
    NSLog(@"%@ - Publishing Bonjour _lookin._tcp. on port %d (name: %@)", VIEWGLASS_SERVER_READABLE_NAME, port, bundleId);
}

- (void)_stopBonjourService {
    if (self.bonjourService_) {
        [self.bonjourService_ stop];
        self.bonjourService_ = nil;
    }
}

- (void)netServiceDidPublish:(NSNetService *)sender {
    NSLog(@"%@ - Bonjour published: %@ on port %d", VIEWGLASS_SERVER_READABLE_NAME, sender.name, (int)sender.port);
}

- (void)netService:(NSNetService *)sender didNotPublish:(NSDictionary<NSString *, NSNumber *> *)errorDict {
    NSLog(@"%@ - Bonjour publish failed: %@", VIEWGLASS_SERVER_READABLE_NAME, errorDict);
}

- (void)respond:(LookinConnectionResponseAttachment *)data requestType:(uint32_t)requestType tag:(uint32_t)tag channel:(Lookin_PTChannel *)channel {
    [self _sendData:data frameOfType:requestType tag:tag toChannel:channel];
}

- (void)pushData:(NSObject *)data type:(uint32_t)type {
    for (Lookin_PTChannel *channel in [self.peerChannels_ copy]) {
        [self _sendData:data frameOfType:type tag:0 toChannel:channel];
    }
}

- (void)_sendData:(NSObject *)data frameOfType:(uint32_t)frameOfType tag:(uint32_t)tag toChannel:(Lookin_PTChannel *)channel {
    if (channel) {
        NSData *archivedData = [NSKeyedArchiver archivedDataWithRootObject:data];
        dispatch_data_t payload = [archivedData createReferencingDispatchData];

        [channel sendFrameOfType:frameOfType tag:tag withPayload:payload callback:^(NSError *error) {
            if (error) {
            }
        }];
    }
}

#pragma mark - Lookin_PTChannelDelegate

- (BOOL)ioFrameChannel:(Lookin_PTChannel*)channel shouldAcceptFrameOfType:(uint32_t)type tag:(uint32_t)tag payloadSize:(uint32_t)payloadSize {
    if (![self.peerChannels_ containsObject:channel]) {
        return NO;
    } else if ([self.requestHandler canHandleRequestType:type]) {
        return YES;
    } else {
        [channel close];
        return NO;
    }
}

- (void)ioFrameChannel:(Lookin_PTChannel*)channel didReceiveFrameOfType:(uint32_t)type tag:(uint32_t)tag payload:(Lookin_PTData*)payload {
    id object = nil;
    if (payload) {
        id unarchivedObject = [NSKeyedUnarchiver unarchiveObjectWithData:[NSData dataWithContentsOfDispatchData:payload.dispatchData]];
        if ([unarchivedObject isKindOfClass:[LookinConnectionAttachment class]]) {
            LookinConnectionAttachment *attachment = (LookinConnectionAttachment *)unarchivedObject;
            object = attachment.data;
        } else {
            object = unarchivedObject;
        }
    }
    [self.requestHandler handleRequestType:type tag:tag object:object channel:channel];
}

/// 当 Client 端链接成功时，该方法会被调用，然后 channel 的状态会变成 connected
- (void)ioFrameChannel:(Lookin_PTChannel*)channel didAcceptConnection:(Lookin_PTChannel*)otherChannel fromAddress:(Lookin_PTAddress*)address {
    NSLog(@"%@ - New client connected. Listening channel:%@ peer:%@", VIEWGLASS_SERVER_READABLE_NAME, channel.debugTag, otherChannel.debugTag);

    otherChannel.targetPort = address.port;
    [self.peerChannels_ addObject:otherChannel];
    NSLog(@"%@ - Total connected clients: %lu", VIEWGLASS_SERVER_READABLE_NAME, (unsigned long)self.peerChannels_.count);

    // 不在这里主动 nil listeningChannel_，也不在这里重新监听。
    // Peertalk 在 accept 后会内部 cancel 监听 channel，触发 didEndWithError，
    // 届时再重新监听以接受下一个客户端（避免 socket 尚未释放就绑定同一端口）。
}

/// 连接断开时的处理
- (void)ioFrameChannel:(Lookin_PTChannel*)channel didEndWithError:(NSError*)error {
    if (channel == self.listeningChannel_) {
        // 监听 channel 结束（Peertalk 在 accept 一个新连接后会内部 cancel 它）
        NSLog(@"%@ - Listening channel ended: %@", VIEWGLASS_SERVER_READABLE_NAME, channel.debugTag);
        self.listeningChannel_ = nil;
        // 现在老 socket 已释放，可以安全地重新绑定同一端口、继续等待下一个客户端
        [self searchPortToListenIfNoConnection];
        return;
    }

    if (![self.peerChannels_ containsObject:channel]) {
        NSLog(@"%@ - Ignore unknown channel end: %@", VIEWGLASS_SERVER_READABLE_NAME, channel.debugTag);
        return;
    }

    // 某个 peer（GUI 或 CLI）断开了
    [self.peerChannels_ removeObject:channel];
    NSLog(@"%@ - Client disconnected:%@ error:%@ remaining:%lu", VIEWGLASS_SERVER_READABLE_NAME,
          channel.debugTag, error, (unsigned long)self.peerChannels_.count);

    [[NSNotificationCenter defaultCenter] postNotificationName:LKS_ConnectionDidEndNotificationName object:self];

    // 确保持续处于监听状态，等待下一个客户端
    [self searchPortToListenIfNoConnection];
}

#pragma mark - Handler

- (void)_handleLocalInspect:(NSNotification *)note {
    UIAlertController  *alertController = [UIAlertController  alertControllerWithTitle:@"ViewglassServer" message:@"Failed to run local inspection. The feature has been removed. Please use the computer version of Lookin or consider SDKs like FLEX for similar functionality."  preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction  = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
    [alertController addAction:okAction];
    UIWindow *keyWindow = [LKS_MultiplatformAdapter keyWindow];
    UIViewController *rootViewController = [keyWindow rootViewController];
    [rootViewController presentViewController:alertController animated:YES completion:nil];
    
    NSLog(@"%@ - Failed to run local inspection. The feature has been removed. Please use the computer version of Lookin or consider SDKs like FLEX for similar functionality.", VIEWGLASS_SERVER_READABLE_NAME);
}

- (void)handleGetLookinInfo:(NSNotification *)note {
    NSDictionary* userInfo = note.userInfo;
    if (!userInfo) {
        return;
    }
    NSMutableDictionary* infoWrapper = userInfo[@"infos"];
    if (![infoWrapper isKindOfClass:[NSMutableDictionary class]]) {
        NSLog(@"%@ - GetLookinInfo failed. Params invalid.", VIEWGLASS_SERVER_READABLE_NAME);
        return;
    }
    infoWrapper[@"lookinServerVersion"] = LOOKIN_SERVER_READABLE_VERSION;
}

@end

/// 这个类使得用户可以通过 NSClassFromString(@"Lookin") 来判断 LookinServer 是否被编译进了项目里

@interface Lookin : NSObject

@end

@implementation Lookin

@end

#endif /* SHOULD_COMPILE_LOOKIN_SERVER */
