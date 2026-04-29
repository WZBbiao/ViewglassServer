#ifdef SHOULD_COMPILE_LOOKIN_SERVER 

//
//  LookinAppInfo.m
//  qmuidemo
//
//  Created by Li Kai on 2018/11/3.
//  Copyright © 2018 QMUI Team. All rights reserved.
//



#import "LookinAppInfo.h"
#import "LKS_MultiplatformAdapter.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreImage/CoreImage.h>

static NSString * const CodingKey_AppIcon = @"1";
static NSString * const CodingKey_Screenshot = @"2";
static NSString * const CodingKey_DeviceDescription = @"3";
static NSString * const CodingKey_OsDescription = @"4";
static NSString * const CodingKey_AppName = @"5";
static NSString * const CodingKey_ScreenWidth = @"6";
static NSString * const CodingKey_ScreenHeight = @"7";
static NSString * const CodingKey_DeviceType = @"8";

@implementation LookinAppInfo

- (id)copyWithZone:(NSZone *)zone {
    LookinAppInfo *newAppInfo = [[LookinAppInfo allocWithZone:zone] init];
    newAppInfo.appIcon = self.appIcon;
    newAppInfo.appName = self.appName;
    newAppInfo.deviceDescription = self.deviceDescription;
    newAppInfo.osDescription = self.osDescription;
    newAppInfo.osMainVersion = self.osMainVersion;
    newAppInfo.deviceType = self.deviceType;
    newAppInfo.screenWidth = self.screenWidth;
    newAppInfo.screenHeight = self.screenHeight;
    newAppInfo.screenScale = self.screenScale;
    newAppInfo.appInfoIdentifier = self.appInfoIdentifier;
    return newAppInfo;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super init]) {
        
        self.serverVersion = [aDecoder decodeIntForKey:@"serverVersion"];
        self.serverReadableVersion = [aDecoder decodeObjectForKey:@"serverReadableVersion"];
        self.swiftEnabledInLookinServer = [aDecoder decodeIntForKey:@"swiftEnabledInLookinServer"];
        NSData *screenshotData = [aDecoder decodeObjectForKey:CodingKey_Screenshot];
        self.screenshot = [[LookinImage alloc] initWithData:screenshotData];
        
        NSData *appIconData = [aDecoder decodeObjectForKey:CodingKey_AppIcon];
        self.appIcon = [[LookinImage alloc] initWithData:appIconData];
        
        self.appName = [aDecoder decodeObjectForKey:CodingKey_AppName];
        self.appBundleIdentifier = [aDecoder decodeObjectForKey:@"appBundleIdentifier"];
        self.deviceDescription = [aDecoder decodeObjectForKey:CodingKey_DeviceDescription];
        self.osDescription = [aDecoder decodeObjectForKey:CodingKey_OsDescription];
        self.osMainVersion = [aDecoder decodeIntegerForKey:@"osMainVersion"];
        self.deviceType = [aDecoder decodeIntegerForKey:CodingKey_DeviceType];
        self.screenWidth = [aDecoder decodeDoubleForKey:CodingKey_ScreenWidth];
        self.screenHeight = [aDecoder decodeDoubleForKey:CodingKey_ScreenHeight];
        self.screenScale = [aDecoder decodeDoubleForKey:@"screenScale"];
        self.appInfoIdentifier = [aDecoder decodeIntegerForKey:@"appInfoIdentifier"];
        self.shouldUseCache = [aDecoder decodeBoolForKey:@"shouldUseCache"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeInt:self.serverVersion forKey:@"serverVersion"];
    [aCoder encodeObject:self.serverReadableVersion forKey:@"serverReadableVersion"];
    [aCoder encodeInt:self.swiftEnabledInLookinServer forKey:@"swiftEnabledInLookinServer"];
    
#if TARGET_OS_IPHONE
    NSData *screenshotData = UIImagePNGRepresentation(self.screenshot);
    [aCoder encodeObject:screenshotData forKey:CodingKey_Screenshot];
    
    NSData *appIconData = UIImagePNGRepresentation(self.appIcon);
    [aCoder encodeObject:appIconData forKey:CodingKey_AppIcon];
#elif TARGET_OS_MAC
    NSData *screenshotData = [self.screenshot TIFFRepresentation];
    [aCoder encodeObject:screenshotData forKey:CodingKey_Screenshot];
    
    NSData *appIconData = [self.appIcon TIFFRepresentation];
    [aCoder encodeObject:appIconData forKey:CodingKey_AppIcon];
#endif
    
    [aCoder encodeObject:self.appName forKey:CodingKey_AppName];
    [aCoder encodeObject:self.appBundleIdentifier forKey:@"appBundleIdentifier"];
    [aCoder encodeObject:self.deviceDescription forKey:CodingKey_DeviceDescription];
    [aCoder encodeObject:self.osDescription forKey:CodingKey_OsDescription];
    [aCoder encodeInteger:self.osMainVersion forKey:@"osMainVersion"];
    [aCoder encodeInteger:self.deviceType forKey:CodingKey_DeviceType];
    [aCoder encodeDouble:self.screenWidth forKey:CodingKey_ScreenWidth];
    [aCoder encodeDouble:self.screenHeight forKey:CodingKey_ScreenHeight];
    [aCoder encodeDouble:self.screenScale forKey:@"screenScale"];
    [aCoder encodeInteger:self.appInfoIdentifier forKey:@"appInfoIdentifier"];
    [aCoder encodeBool:self.shouldUseCache forKey:@"shouldUseCache"];
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }
    if (![object isKindOfClass:[LookinAppInfo class]]) {
        return NO;
    }
    if ([self isEqualToAppInfo:object]) {
        return YES;
    }
    return NO;
}

- (NSUInteger)hash {
    return self.appName.hash ^ self.deviceDescription.hash ^ self.osDescription.hash ^ self.deviceType;
}

- (BOOL)isEqualToAppInfo:(LookinAppInfo *)info {
    if (!info) {
        return NO;
    }
    if ([self.appName isEqualToString:info.appName] && [self.deviceDescription isEqualToString:info.deviceDescription] && [self.osDescription isEqualToString:info.osDescription] && self.deviceType == info.deviceType) {
        return YES;
    }
    return NO;
}

#if TARGET_OS_IPHONE

+ (LookinAppInfo *)currentInfoWithScreenshot:(BOOL)hasScreenshot icon:(BOOL)hasIcon localIdentifiers:(NSArray<NSNumber *> *)localIdentifiers {
    NSInteger selfIdentifier = [self getAppInfoIdentifier];
    if ([localIdentifiers containsObject:@(selfIdentifier)]) {
        LookinAppInfo *info = [LookinAppInfo new];
        info.appInfoIdentifier = selfIdentifier;
        info.shouldUseCache = YES;
        return info;
    }
    
    LookinAppInfo *info = [[LookinAppInfo alloc] init];
    info.serverReadableVersion = LOOKIN_SERVER_READABLE_VERSION;
#ifdef LOOKIN_SERVER_SWIFT_ENABLED
    info.swiftEnabledInLookinServer = 1;
#else
    info.swiftEnabledInLookinServer = -1;
#endif
    info.appInfoIdentifier = selfIdentifier;
    info.appName = [self appName];
    info.deviceDescription = [UIDevice currentDevice].name;
    info.appBundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    if ([self isSimulator]) {
        info.deviceType = LookinAppInfoDeviceSimulator;
    } else if ([LKS_MultiplatformAdapter isiPad]) {
        info.deviceType = LookinAppInfoDeviceIPad;
    } else {
        info.deviceType = LookinAppInfoDeviceOthers;
    }
    
    info.osDescription = [UIDevice currentDevice].systemVersion;
    
    NSString *mainVersionStr = [[[UIDevice currentDevice] systemVersion] componentsSeparatedByString:@"."].firstObject;
    info.osMainVersion = [mainVersionStr integerValue];
    
    CGSize screenSize = [LKS_MultiplatformAdapter mainScreenBounds].size;
    info.screenWidth = screenSize.width;
    info.screenHeight = screenSize.height;
    info.screenScale = [LKS_MultiplatformAdapter mainScreenScale];

    if (hasScreenshot) {
        info.screenshot = [self screenshotImage];
    }
    if (hasIcon) {
        info.appIcon = [self appIcon];
    }
    
    return info;
}

+ (NSString *)appName {
    NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
    NSString *displayName = [info objectForKey:@"CFBundleDisplayName"];
    NSString *name = [info objectForKey:@"CFBundleName"];
    return displayName.length ? displayName : name;
}

+ (UIImage *)appIcon {
#if TARGET_OS_TV
    return nil;
#else
    NSString *imageName;
    id CFBundleIcons = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIcons"];
    if ([CFBundleIcons respondsToSelector:@selector(objectForKey:)]) {
        id CFBundlePrimaryIcon = [CFBundleIcons objectForKey:@"CFBundlePrimaryIcon"];
        if ([CFBundlePrimaryIcon respondsToSelector:@selector(objectForKey:)]) {
            imageName = [[CFBundlePrimaryIcon objectForKey:@"CFBundleIconFiles"] lastObject];
        } else if ([CFBundlePrimaryIcon isKindOfClass:NSString.class]) {
            imageName = CFBundlePrimaryIcon;
        }
    }
    if (!imageName.length) {
        // 正常情况下拿到的 name 可能比如 “AppIcon60x60”。但某些情况可能为 nil，此时直接 return 否则 [UIImage imageNamed:nil] 可能导致 console 报 "CUICatalog: Invalid asset name supplied: '(null)'" 的错误信息
        return nil;
    }
    return [UIImage imageNamed:imageName];
#endif
}

+ (UIImage *)screenshotImage {
    CGSize size = [LKS_MultiplatformAdapter mainScreenBounds].size;
    if (size.width <= 0 || size.height <= 0) {
        // *** Terminating app due to uncaught exception 'NSInternalInconsistencyException', reason: 'UIGraphicsBeginImageContext() failed to allocate CGBitampContext: size={0, 0}, scale=3.000000, bitmapInfo=0x2002. Use UIGraphicsImageRenderer to avoid this assert.'

        // https://github.com/hughkli/Lookin/issues/21
        return nil;
    }
    UIGraphicsBeginImageContextWithOptions(size, YES, 0.4);
    [self drawVisibleWindowsForScreenScreenshotAfterScreenUpdates:YES];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

+ (UIImage *)highResolutionScreenshotImage {
    CGSize size = [LKS_MultiplatformAdapter mainScreenBounds].size;
    if (size.width <= 0 || size.height <= 0) {
        return nil;
    }

    UIGraphicsBeginImageContextWithOptions(size, YES, 0);
    [self drawVisibleWindowsForScreenScreenshotAfterScreenUpdates:YES];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

+ (void)drawVisibleWindowsForScreenScreenshotAfterScreenUpdates:(BOOL)afterScreenUpdates {
    NSArray<UIWindow *> *windows = [self visibleWindowsForScreenScreenshot];
    CGRect screenBounds = [LKS_MultiplatformAdapter mainScreenBounds];
    CGContextRef context = UIGraphicsGetCurrentContext();

    for (UIWindow *window in windows) {
        CGRect drawRect = [window convertRect:window.bounds toWindow:nil];
        drawRect.origin.x -= screenBounds.origin.x;
        drawRect.origin.y -= screenBounds.origin.y;
        if (CGRectIsEmpty(drawRect) || drawRect.size.width <= 0 || drawRect.size.height <= 0) {
            continue;
        }

        BOOL drewHierarchy = [window drawViewHierarchyInRect:drawRect afterScreenUpdates:afterScreenUpdates];
        if (!drewHierarchy && context) {
            CGContextSaveGState(context);
            CGContextTranslateCTM(context, drawRect.origin.x, drawRect.origin.y);
            [window.layer renderInContext:context];
            CGContextRestoreGState(context);
        }
    }

    [self drawVisibleAVPlayerLayersForScreenScreenshotInWindows:windows screenBounds:screenBounds];
}

+ (void)drawVisibleAVPlayerLayersForScreenScreenshotInWindows:(NSArray<UIWindow *> *)windows screenBounds:(CGRect)screenBounds {
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (!context) {
        return;
    }

    for (UIWindow *window in windows) {
        [self drawVisibleAVPlayerLayersInLayer:window.layer window:window screenBounds:screenBounds];
    }
}

+ (void)drawVisibleAVPlayerLayersInLayer:(CALayer *)layer contextBounds:(CGRect)contextBounds {
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (!context || !layer || CGRectIsEmpty(contextBounds)) {
        return;
    }

    [self drawVisibleAVPlayerLayersInLayer:layer relativeToLayer:layer contextBounds:contextBounds];
}

+ (void)drawVisibleAVPlayerLayersInLayer:(CALayer *)layer relativeToLayer:(CALayer *)targetLayer contextBounds:(CGRect)contextBounds {
    if (!layer || layer.hidden || layer.opacity <= 0.01 || CGRectIsEmpty(layer.bounds)) {
        return;
    }

    if ([layer isKindOfClass:AVPlayerLayer.class]) {
        AVPlayerLayer *playerLayer = (AVPlayerLayer *)layer;
        CGRect rectInContext = [playerLayer convertRect:playerLayer.bounds toLayer:targetLayer];
        CGRect clippedRect = CGRectIntersection(contextBounds, rectInContext);
        if (!CGRectIsNull(clippedRect) && !CGRectIsEmpty(clippedRect)) {
            UIImage *frameImage = [self imageForAVPlayerLayer:playerLayer targetSize:clippedRect.size];
            if (frameImage) {
                [self drawAVPlayerFrameImage:frameImage inRect:rectInContext videoGravity:playerLayer.videoGravity];
            }
        }
    }

    NSArray<CALayer *> *sublayers = [layer.sublayers copy];
    for (CALayer *sublayer in sublayers) {
        [self drawVisibleAVPlayerLayersInLayer:sublayer relativeToLayer:targetLayer contextBounds:contextBounds];
    }
}

+ (void)drawVisibleAVPlayerLayersInLayer:(CALayer *)layer window:(UIWindow *)window screenBounds:(CGRect)screenBounds {
    if (!layer || layer.hidden || layer.opacity <= 0.01 || CGRectIsEmpty(layer.bounds)) {
        return;
    }

    if ([layer isKindOfClass:AVPlayerLayer.class]) {
        AVPlayerLayer *playerLayer = (AVPlayerLayer *)layer;
        CGRect rectInWindow = [playerLayer convertRect:playerLayer.bounds toLayer:window.layer];
        CGRect rectInScreen = [window convertRect:rectInWindow toWindow:nil];
        rectInScreen.origin.x -= screenBounds.origin.x;
        rectInScreen.origin.y -= screenBounds.origin.y;
        CGRect clippedRect = CGRectIntersection(CGRectMake(0, 0, screenBounds.size.width, screenBounds.size.height), rectInScreen);
        if (!CGRectIsNull(clippedRect) && !CGRectIsEmpty(clippedRect)) {
            UIImage *frameImage = [self imageForAVPlayerLayer:playerLayer targetSize:clippedRect.size];
            if (frameImage) {
                [self drawAVPlayerFrameImage:frameImage inRect:rectInScreen videoGravity:playerLayer.videoGravity];
            }
        }
    }

    NSArray<CALayer *> *sublayers = [layer.sublayers copy];
    for (CALayer *sublayer in sublayers) {
        [self drawVisibleAVPlayerLayersInLayer:sublayer window:window screenBounds:screenBounds];
    }
}

+ (UIImage *)imageForAVPlayerLayer:(AVPlayerLayer *)playerLayer targetSize:(CGSize)targetSize {
    AVPlayerItem *item = playerLayer.player.currentItem;
    if (!item || item.status == AVPlayerItemStatusFailed) {
        return nil;
    }

    UIImage *outputImage = [self currentVideoOutputImageForPlayerItem:item];
    if (outputImage && ![self imageLooksMostlyBlack:outputImage]) {
        return outputImage;
    }

    CMTime currentTime = [item currentTime];
    UIImage *currentImage = [self generatedImageForPlayerItem:item time:currentTime targetSize:targetSize];
    if (currentImage && ![self imageLooksMostlyBlack:currentImage]) {
        return currentImage;
    }

    NSArray<NSValue *> *fallbackTimes = [self fallbackTimesForPlayerItem:item currentTime:currentTime];
    for (NSValue *timeValue in fallbackTimes) {
        CMTime time = timeValue.CMTimeValue;
        UIImage *image = [self generatedImageForPlayerItem:item time:time targetSize:targetSize];
        if (image && ![self imageLooksMostlyBlack:image]) {
            return image;
        }
    }

    return outputImage ?: currentImage;
}

+ (UIImage *)currentVideoOutputImageForPlayerItem:(AVPlayerItem *)item {
    AVPlayerItemVideoOutput *videoOutput = nil;
    for (AVPlayerItemOutput *output in item.outputs) {
        if ([output isKindOfClass:AVPlayerItemVideoOutput.class]) {
            videoOutput = (AVPlayerItemVideoOutput *)output;
            break;
        }
    }

    BOOL temporaryOutput = NO;
    if (!videoOutput) {
        NSDictionary *attributes = @{
            (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)
        };
        videoOutput = [[AVPlayerItemVideoOutput alloc] initWithPixelBufferAttributes:attributes];
        [item addOutput:videoOutput];
        temporaryOutput = YES;
    }

    CVPixelBufferRef pixelBuffer = NULL;
    CMTime currentTime = item.currentTime;
    if (CMTIME_IS_VALID(currentTime)) {
        pixelBuffer = [videoOutput copyPixelBufferForItemTime:currentTime itemTimeForDisplay:NULL];
    }
    if (!pixelBuffer) {
        CMTime hostTime = [videoOutput itemTimeForHostTime:CACurrentMediaTime()];
        if (CMTIME_IS_VALID(hostTime)) {
            pixelBuffer = [videoOutput copyPixelBufferForItemTime:hostTime itemTimeForDisplay:NULL];
        }
    }

    UIImage *image = nil;
    if (pixelBuffer) {
        image = [self imageFromPixelBuffer:pixelBuffer];
        CVPixelBufferRelease(pixelBuffer);
    }

    if (temporaryOutput) {
        [item removeOutput:videoOutput];
    }
    return image;
}

+ (UIImage *)generatedImageForPlayerItem:(AVPlayerItem *)item time:(CMTime)time targetSize:(CGSize)targetSize {
    if (!item.asset || !CMTIME_IS_VALID(time)) {
        return nil;
    }
    AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:item.asset];
    generator.appliesPreferredTrackTransform = YES;
    generator.requestedTimeToleranceBefore = CMTimeMakeWithSeconds(0.5, 600);
    generator.requestedTimeToleranceAfter = CMTimeMakeWithSeconds(0.5, 600);
    CGFloat scale = [LKS_MultiplatformAdapter mainScreenScale];
    if (targetSize.width > 0 && targetSize.height > 0 && scale > 0) {
        generator.maximumSize = CGSizeMake(targetSize.width * scale, targetSize.height * scale);
    }

    NSError *error = nil;
    CGImageRef cgImage = [generator copyCGImageAtTime:time actualTime:NULL error:&error];
    if (!cgImage) {
        return nil;
    }
    UIImage *image = [UIImage imageWithCGImage:cgImage scale:[LKS_MultiplatformAdapter mainScreenScale] orientation:UIImageOrientationUp];
    CGImageRelease(cgImage);
    return image;
}

+ (NSArray<NSValue *> *)fallbackTimesForPlayerItem:(AVPlayerItem *)item currentTime:(CMTime)currentTime {
    NSMutableArray<NSValue *> *times = [NSMutableArray array];
    int32_t timescale = currentTime.timescale > 0 ? currentTime.timescale : 600;

    if (CMTIME_IS_VALID(currentTime)) {
        [times addObject:[NSValue valueWithCMTime:CMTimeAdd(currentTime, CMTimeMakeWithSeconds(1, timescale))]];
        [times addObject:[NSValue valueWithCMTime:CMTimeAdd(currentTime, CMTimeMakeWithSeconds(2, timescale))]];
    }

    [times addObject:[NSValue valueWithCMTime:CMTimeMakeWithSeconds(1, 600)]];

    CMTime duration = item.asset.duration;
    if (CMTIME_IS_NUMERIC(duration) && duration.value > 0) {
        Float64 seconds = CMTimeGetSeconds(duration);
        if (isfinite(seconds) && seconds > 2) {
            [times addObject:[NSValue valueWithCMTime:CMTimeMakeWithSeconds(seconds * 0.25, 600)]];
            [times addObject:[NSValue valueWithCMTime:CMTimeMakeWithSeconds(seconds * 0.5, 600)]];
        }
    }
    return times.copy;
}

+ (UIImage *)imageFromPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    if (!pixelBuffer) {
        return nil;
    }

    CIImage *ciImage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
    if (!ciImage) {
        return nil;
    }

    static CIContext *ciContext;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        ciContext = [CIContext contextWithOptions:nil];
    });

    CGRect rect = CGRectMake(0, 0, CVPixelBufferGetWidth(pixelBuffer), CVPixelBufferGetHeight(pixelBuffer));
    CGImageRef cgImage = [ciContext createCGImage:ciImage fromRect:rect];
    if (!cgImage) {
        return nil;
    }

    UIImage *image = [UIImage imageWithCGImage:cgImage scale:[LKS_MultiplatformAdapter mainScreenScale] orientation:UIImageOrientationUp];
    CGImageRelease(cgImage);
    return image;
}

+ (void)drawAVPlayerFrameImage:(UIImage *)image inRect:(CGRect)rect videoGravity:(AVLayerVideoGravity)videoGravity {
    if (!image || CGRectIsEmpty(rect)) {
        return;
    }

    CGRect drawRect = rect;
    CGSize imageSize = image.size;
    if (imageSize.width > 0 && imageSize.height > 0 && rect.size.width > 0 && rect.size.height > 0) {
        CGFloat imageAspect = imageSize.width / imageSize.height;
        CGFloat rectAspect = rect.size.width / rect.size.height;
        if ([videoGravity isEqualToString:AVLayerVideoGravityResizeAspect]) {
            if (imageAspect > rectAspect) {
                drawRect.size.height = rect.size.width / imageAspect;
                drawRect.origin.y += (rect.size.height - drawRect.size.height) / 2.0;
            } else {
                drawRect.size.width = rect.size.height * imageAspect;
                drawRect.origin.x += (rect.size.width - drawRect.size.width) / 2.0;
            }
        } else if ([videoGravity isEqualToString:AVLayerVideoGravityResizeAspectFill]) {
            if (imageAspect > rectAspect) {
                drawRect.size.width = rect.size.height * imageAspect;
                drawRect.origin.x += (rect.size.width - drawRect.size.width) / 2.0;
            } else {
                drawRect.size.height = rect.size.width / imageAspect;
                drawRect.origin.y += (rect.size.height - drawRect.size.height) / 2.0;
            }
        }
    }

    CGContextRef context = UIGraphicsGetCurrentContext();
    if (!context) {
        return;
    }
    CGContextSaveGState(context);
    UIRectClip(rect);
    CGContextSetBlendMode(context, kCGBlendModeLighten);
    [image drawInRect:drawRect];
    CGContextRestoreGState(context);
}

+ (BOOL)imageLooksMostlyBlack:(UIImage *)image {
    CGImageRef cgImage = image.CGImage;
    if (!cgImage) {
        return NO;
    }

    const size_t width = 16;
    const size_t height = 16;
    unsigned char pixels[width * height * 4];
    memset(pixels, 0, sizeof(pixels));

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pixels, width, height, 8, width * 4, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    if (!context) {
        return NO;
    }
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), cgImage);
    CGContextRelease(context);

    NSUInteger blackPixels = 0;
    NSUInteger visiblePixels = 0;
    for (NSUInteger idx = 0; idx < width * height; idx++) {
        unsigned char *pixel = &pixels[idx * 4];
        CGFloat red = pixel[0] / 255.0;
        CGFloat green = pixel[1] / 255.0;
        CGFloat blue = pixel[2] / 255.0;
        CGFloat alpha = pixel[3] / 255.0;
        if (alpha <= 0.05) {
            continue;
        }
        visiblePixels += 1;
        CGFloat maxChannel = MAX(red, MAX(green, blue));
        CGFloat sum = red + green + blue;
        if (maxChannel < 0.08 && sum < 0.18) {
            blackPixels += 1;
        }
    }
    if (visiblePixels == 0) {
        return NO;
    }
    return ((CGFloat)blackPixels / (CGFloat)visiblePixels) > 0.9;
}

+ (NSArray<UIWindow *> *)visibleWindowsForScreenScreenshot {
    NSMutableArray<UIWindow *> *candidates = [NSMutableArray array];
    CGRect screenBounds = [LKS_MultiplatformAdapter mainScreenBounds];

    for (UIWindow *window in [LKS_MultiplatformAdapter allWindows]) {
        if (!window || window.hidden || window.alpha <= 0.01) {
            continue;
        }
        if (window.bounds.size.width <= 0 || window.bounds.size.height <= 0) {
            continue;
        }
        CGRect screenRect = [window convertRect:window.bounds toWindow:nil];
        if (!CGRectIntersectsRect(screenBounds, screenRect)) {
            continue;
        }
        [candidates addObject:window];
    }

    BOOL hasRenderableAppWindow = NO;
    for (UIWindow *window in candidates) {
        if (window.rootViewController || window.subviews.count > 0) {
            hasRenderableAppWindow = YES;
            break;
        }
    }

    NSMutableArray<UIWindow *> *windows = [NSMutableArray arrayWithCapacity:candidates.count];
    for (UIWindow *window in candidates) {
        if ([self windowLooksLikeNonVisualSystemOverlay:window screenBounds:screenBounds]) {
            continue;
        }
        if (hasRenderableAppWindow && [self windowLooksLikeEmptyFullscreenOverlay:window screenBounds:screenBounds]) {
            continue;
        }
        [windows addObject:window];
    }

    [windows sortUsingComparator:^NSComparisonResult(UIWindow *lhs, UIWindow *rhs) {
        if (lhs.windowLevel < rhs.windowLevel) {
            return NSOrderedAscending;
        }
        if (lhs.windowLevel > rhs.windowLevel) {
            return NSOrderedDescending;
        }
        return NSOrderedSame;
    }];

    if (windows.count == 0) {
        UIWindow *keyWindow = [LKS_MultiplatformAdapter keyWindow];
        if (keyWindow) {
            [windows addObject:keyWindow];
        }
    }
    return windows.copy;
}

+ (BOOL)windowLooksLikeNonVisualSystemOverlay:(UIWindow *)window screenBounds:(CGRect)screenBounds {
    CGRect screenRect = [window convertRect:window.bounds toWindow:nil];
    CGRect intersection = CGRectIntersection(screenBounds, screenRect);
    if (CGRectIsNull(intersection) || CGRectIsEmpty(intersection)) {
        return NO;
    }
    CGFloat screenArea = screenBounds.size.width * screenBounds.size.height;
    if (screenArea <= 0) {
        return NO;
    }
    CGFloat coverage = (intersection.size.width * intersection.size.height) / screenArea;
    if (coverage < 0.9) {
        return NO;
    }

    NSArray<NSString *> *classNames = @[
        NSStringFromClass(window.class) ?: @"",
        NSStringFromClass(window.rootViewController.class) ?: @"",
        NSStringFromClass(window.rootViewController.view.class) ?: @""
    ];
    for (NSString *className in classNames) {
        if ([className containsString:@"UITrackingElementWindow"] ||
            [className containsString:@"UITrackingWindow"]) {
            return YES;
        }
    }
    return NO;
}

+ (BOOL)windowLooksLikeEmptyFullscreenOverlay:(UIWindow *)window screenBounds:(CGRect)screenBounds {
    if (window.rootViewController || window.subviews.count > 0) {
        return NO;
    }
    CGRect screenRect = [window convertRect:window.bounds toWindow:nil];
    CGRect intersection = CGRectIntersection(screenBounds, screenRect);
    if (CGRectIsNull(intersection) || CGRectIsEmpty(intersection)) {
        return NO;
    }
    CGFloat screenArea = screenBounds.size.width * screenBounds.size.height;
    if (screenArea <= 0) {
        return NO;
    }
    CGFloat coverage = (intersection.size.width * intersection.size.height) / screenArea;
    return coverage > 0.9 && window.windowLevel >= UIWindowLevelNormal;
}

+ (BOOL)isSimulator {
    if (TARGET_OS_SIMULATOR) {
        return YES;
    }
    return NO;
}

#endif

+ (NSInteger)getAppInfoIdentifier {
    static dispatch_once_t onceToken;
    static NSInteger identifier = 0;
    dispatch_once(&onceToken,^{
        identifier = [[NSDate date] timeIntervalSince1970];
    });
    return identifier;
}

@end

#endif /* SHOULD_COMPILE_LOOKIN_SERVER */
