#ifdef SHOULD_COMPILE_LOOKIN_SERVER

//
//  LKS_GestureTargetActionsSearcher.m
//  LookinServer
//
//  Created by likai.123 on 2023/9/11.
//

#import "LKS_GestureTargetActionsSearcher.h"
#import <objc/runtime.h>
#import "NSArray+Lookin.h"
#import "LookinTuple.h"
#import "LookinWeakContainer.h"

@implementation LKS_GestureTargetActionsSearcher

+ (NSArray<LookinTwoTuple *> *)getTargetActionsFromRecognizer:(UIGestureRecognizer *)recognizer {
    if (!recognizer) {
        return @[];
    }
    // KVC 要放到 try catch 里面防止 Crash
    @try {
        NSArray* targetsList = [recognizer valueForKey:@"_targets"];
        if (!targetsList || targetsList.count == 0) {
            return @[];
        }
        // 数组元素对象是 UIGestureRecognizerTarget*
        // 这个元素有两个属性，一个是名为 _target 的属性指向某个实例，另一个是名为 _action 的属性保存一个 SEL
        NSArray<LookinTwoTuple *>* ret = [targetsList lookin_map:^id(NSUInteger idx, id targetBox) {
            id targetObj = [targetBox valueForKey:@"_target"];
            if (!targetObj) {
                return nil;
            }
            SEL action = NULL;
            Ivar actionIvar = class_getInstanceVariable([targetBox class], "_action");
            if (actionIvar != NULL) {
                ptrdiff_t offset = ivar_getOffset(actionIvar);
                uint8_t *bytes = (__bridge void *)targetBox;
                action = *(SEL *)(bytes + offset);
            }
            if (action == NULL) {
                @try {
                    id actionValue = [targetBox valueForKey:@"_action"];
                    if ([actionValue isKindOfClass:[NSString class]]) {
                        action = NSSelectorFromString((NSString *)actionValue);
                    }
                } @catch (NSException *exception) {
                    // Ignore and fall back to NULL below.
                }
            }
            if (action == NULL) {
                NSString *description = recognizer.description ?: @"";
                NSRange actionRange = [description rangeOfString:@"action="];
                if (actionRange.location != NSNotFound) {
                    NSUInteger start = NSMaxRange(actionRange);
                    NSUInteger end = [description rangeOfString:@"," options:0 range:NSMakeRange(start, description.length - start)].location;
                    if (end != NSNotFound && end > start) {
                        NSString *selectorName = [description substringWithRange:NSMakeRange(start, end - start)];
                        selectorName = [selectorName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                        if (selectorName.length) {
                            action = NSSelectorFromString(selectorName);
                        }
                    }
                }
            }
            
            LookinTwoTuple* tuple = [LookinTwoTuple new];
            tuple.first = [LookinWeakContainer containerWithObject:targetObj];
            tuple.second = (action == NULL ? @"NULL" : NSStringFromSelector(action));
            return tuple;
        }];
        return ret;
    }
    @catch (NSException * e) {
        NSLog(@"LookinServer - %@", e);
        return @[];
    }
}

@end

#endif /* SHOULD_COMPILE_LOOKIN_SERVER */
