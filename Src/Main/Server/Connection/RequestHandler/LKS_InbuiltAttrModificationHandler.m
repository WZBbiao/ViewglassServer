#ifdef SHOULD_COMPILE_LOOKIN_SERVER 

//
//  LKS_InbuiltAttrModificationHandler.m
//  LookinServer
//
//  Created by Li Kai on 2019/6/12.
//  https://lookin.work
//

#import "LKS_InbuiltAttrModificationHandler.h"
#import "UIColor+LookinServer.h"
#import "LookinAttributeModification.h"
#import "LKS_AttrGroupsMaker.h"
#import "LookinDisplayItemDetail.h"
#import "LookinStaticAsyncUpdateTask.h"
#import "LookinServerDefines.h"
#import "LKS_CustomAttrGroupsMaker.h"

@implementation LKS_InbuiltAttrModificationHandler

+ (NSError *)_exceptionErrorWithReceiver:(NSObject *)receiver selector:(SEL)selector reason:(NSString *)reason {
    NSString *errorMsg = [NSString stringWithFormat:LKS_Localized(@"<%@: %p>: an exception was raised when invoking %@. (%@)"), NSStringFromClass(receiver.class), receiver, NSStringFromSelector(selector), reason ?: @""];
    return [NSError errorWithDomain:LookinErrorDomain code:LookinErrCode_Exception userInfo:@{
        NSLocalizedDescriptionKey: LKS_Localized(@"The modification may failed."),
        NSLocalizedRecoverySuggestionErrorKey: errorMsg
    }];
}

+ (NSError *)_invalidValueErrorWithReceiver:(NSObject *)receiver selector:(SEL)selector attrType:(LookinAttrType)attrType expected:(NSString *)expected actualValue:(id)value {
    NSString *actualClass = value ? NSStringFromClass([value class]) : @"nil";
    NSString *errorMsg = [NSString stringWithFormat:LKS_Localized(@"%@ on <%@: %p> expects %@ for attrType %ld, but got %@."), NSStringFromSelector(selector), NSStringFromClass(receiver.class), receiver, expected, (long)attrType, actualClass];
    return [NSError errorWithDomain:LookinErrorDomain code:LookinErrCode_ModifyValueTypeInvalid userInfo:@{
        NSLocalizedDescriptionKey: LKS_Localized(@"The modification value is invalid."),
        NSLocalizedRecoverySuggestionErrorKey: errorMsg
    }];
}

+ (NSNumber *)_numberValueFromModification:(LookinAttributeModification *)modification receiver:(NSObject *)receiver error:(NSError **)error {
    if ([modification.value isKindOfClass:[NSNumber class]]) {
        return (NSNumber *)modification.value;
    }
    if (error) {
        *error = [self _invalidValueErrorWithReceiver:receiver selector:modification.setterSelector attrType:modification.attrType expected:@"NSNumber" actualValue:modification.value];
    }
    return nil;
}

+ (NSValue *)_structValueFromModification:(LookinAttributeModification *)modification receiver:(NSObject *)receiver displayName:(NSString *)displayName error:(NSError **)error {
    id value = modification.value;
    if ([value isKindOfClass:[NSValue class]]) {
        return (NSValue *)value;
    }
    if (error) {
        *error = [self _invalidValueErrorWithReceiver:receiver selector:modification.setterSelector attrType:modification.attrType expected:displayName actualValue:value];
    }
    return nil;
}

+ (NSString *)_stringValueFromModification:(LookinAttributeModification *)modification receiver:(NSObject *)receiver allowNil:(BOOL)allowNil error:(NSError **)error {
    id value = modification.value;
    if (!value && allowNil) {
        return nil;
    }
    if ([value isKindOfClass:[NSString class]]) {
        return (NSString *)value;
    }
    if (error) {
        *error = [self _invalidValueErrorWithReceiver:receiver selector:modification.setterSelector attrType:modification.attrType expected:@"NSString" actualValue:value];
    }
    return nil;
}

+ (NSArray<NSNumber *> *)_rgbaValueFromModification:(LookinAttributeModification *)modification receiver:(NSObject *)receiver error:(NSError **)error {
    id value = modification.value;
    if ([value isKindOfClass:[NSArray class]]) {
        NSArray *rgba = (NSArray *)value;
        if (rgba.count == 4) {
            BOOL isValid = YES;
            for (id component in rgba) {
                if (![component isKindOfClass:[NSNumber class]]) {
                    isValid = NO;
                    break;
                }
            }
            if (isValid) {
                return rgba;
            }
        }
    }
    if (error) {
        *error = [self _invalidValueErrorWithReceiver:receiver selector:modification.setterSelector attrType:modification.attrType expected:@"RGBA NSArray<NSNumber *> with 4 items" actualValue:value];
    }
    return nil;
}

+ (void)handleModification:(LookinAttributeModification *)modification completion:(void (^)(LookinDisplayItemDetail *data, NSError *error))completion {
    if (!completion) {
        NSAssert(NO, @"");
        return;
    }
    if (!modification || ![modification isKindOfClass:[LookinAttributeModification class]]) {
        completion(nil, LookinErr_Inner);
        return;
    }
    
    NSObject *receiver = [NSObject lks_objectWithOid:modification.targetOid];
    if (!receiver) {
        completion(nil, LookinErr_ObjNotFound);
        return;
    }
    
    if (![receiver respondsToSelector:modification.setterSelector]) {
        NSString *msg = [NSString stringWithFormat:LKS_Localized(@"%@ does not respond to %@"), NSStringFromClass(receiver.class), NSStringFromSelector(modification.setterSelector)];
        completion(nil, LookinErrorMake(msg, @""));
        return;
    }

    NSMethodSignature *setterSignature = [receiver methodSignatureForSelector:modification.setterSelector];
    if (!setterSignature || setterSignature.numberOfArguments != 3) {
        NSString *msg = [NSString stringWithFormat:LKS_Localized(@"Invalid setter signature for %@ on %@"), NSStringFromSelector(modification.setterSelector), NSStringFromClass(receiver.class)];
        completion(nil, LookinErrorMake(msg, @""));
        return;
    }

    NSInvocation *setterInvocation = [NSInvocation invocationWithMethodSignature:setterSignature];
    setterInvocation.target = receiver;
    setterInvocation.selector = modification.setterSelector;
    NSError *validationError = nil;
    
    @try {
        switch (modification.attrType) {
        case LookinAttrTypeNone:
        case LookinAttrTypeVoid: {
            completion(nil, LookinErr_Inner);
            return;
        }
        case LookinAttrTypeChar: {
            NSNumber *numberValue = [self _numberValueFromModification:modification receiver:receiver error:&validationError];
            if (!numberValue) { break; }
            char expectedValue = numberValue.charValue;
            [setterInvocation setArgument:&expectedValue atIndex:2];
            break;
        }
        case LookinAttrTypeInt:
        case LookinAttrTypeEnumInt: {
            NSNumber *numberValue = [self _numberValueFromModification:modification receiver:receiver error:&validationError];
            if (!numberValue) { break; }
            int expectedValue = numberValue.intValue;
            [setterInvocation setArgument:&expectedValue atIndex:2];
            break;
        }
        case LookinAttrTypeShort: {
            NSNumber *numberValue = [self _numberValueFromModification:modification receiver:receiver error:&validationError];
            if (!numberValue) { break; }
            short expectedValue = numberValue.shortValue;
            [setterInvocation setArgument:&expectedValue atIndex:2];
            break;
        }
        case LookinAttrTypeLong:
        case LookinAttrTypeEnumLong: {
            NSNumber *numberValue = [self _numberValueFromModification:modification receiver:receiver error:&validationError];
            if (!numberValue) { break; }
            long expectedValue = numberValue.longValue;
            [setterInvocation setArgument:&expectedValue atIndex:2];
            break;
        }
        case LookinAttrTypeLongLong: {
            NSNumber *numberValue = [self _numberValueFromModification:modification receiver:receiver error:&validationError];
            if (!numberValue) { break; }
            long long expectedValue = numberValue.longLongValue;
            [setterInvocation setArgument:&expectedValue atIndex:2];
            break;
        }
        case LookinAttrTypeUnsignedChar: {
            NSNumber *numberValue = [self _numberValueFromModification:modification receiver:receiver error:&validationError];
            if (!numberValue) { break; }
            unsigned char expectedValue = numberValue.unsignedCharValue;
            [setterInvocation setArgument:&expectedValue atIndex:2];
            break;
        }
        case LookinAttrTypeUnsignedInt: {
            NSNumber *numberValue = [self _numberValueFromModification:modification receiver:receiver error:&validationError];
            if (!numberValue) { break; }
            unsigned int expectedValue = numberValue.unsignedIntValue;
            [setterInvocation setArgument:&expectedValue atIndex:2];
            break;
        }
        case LookinAttrTypeUnsignedShort: {
            NSNumber *numberValue = [self _numberValueFromModification:modification receiver:receiver error:&validationError];
            if (!numberValue) { break; }
            unsigned short expectedValue = numberValue.unsignedShortValue;
            [setterInvocation setArgument:&expectedValue atIndex:2];
            break;
        }
        case LookinAttrTypeUnsignedLong: {
            NSNumber *numberValue = [self _numberValueFromModification:modification receiver:receiver error:&validationError];
            if (!numberValue) { break; }
            unsigned long expectedValue = numberValue.unsignedLongValue;
            [setterInvocation setArgument:&expectedValue atIndex:2];
            break;
        }
        case LookinAttrTypeUnsignedLongLong: {
            NSNumber *numberValue = [self _numberValueFromModification:modification receiver:receiver error:&validationError];
            if (!numberValue) { break; }
            unsigned long long expectedValue = numberValue.unsignedLongLongValue;
            [setterInvocation setArgument:&expectedValue atIndex:2];
            break;
        }
        case LookinAttrTypeFloat: {
            NSNumber *numberValue = [self _numberValueFromModification:modification receiver:receiver error:&validationError];
            if (!numberValue) { break; }
            float expectedValue = numberValue.floatValue;
            [setterInvocation setArgument:&expectedValue atIndex:2];
            break;
        }
        case LookinAttrTypeDouble: {
            NSNumber *numberValue = [self _numberValueFromModification:modification receiver:receiver error:&validationError];
            if (!numberValue) { break; }
            double expectedValue = numberValue.doubleValue;
            [setterInvocation setArgument:&expectedValue atIndex:2];
            break;
        }
        case LookinAttrTypeBOOL: {
            NSNumber *numberValue = [self _numberValueFromModification:modification receiver:receiver error:&validationError];
            if (!numberValue) { break; }
            BOOL expectedValue = numberValue.boolValue;
            [setterInvocation setArgument:&expectedValue atIndex:2];
            break;
        }
        case LookinAttrTypeSel: {
            NSString *stringValue = [self _stringValueFromModification:modification receiver:receiver allowNil:NO error:&validationError];
            if (!stringValue) { break; }
            SEL expectedValue = NSSelectorFromString(stringValue);
            [setterInvocation setArgument:&expectedValue atIndex:2];
            break;
        }
        case LookinAttrTypeClass: {
            NSString *stringValue = [self _stringValueFromModification:modification receiver:receiver allowNil:NO error:&validationError];
            if (!stringValue) { break; }
            Class expectedValue = NSClassFromString(stringValue);
            [setterInvocation setArgument:&expectedValue atIndex:2];
            break;
        }
        case LookinAttrTypeCGPoint: {
            NSValue *structValue = [self _structValueFromModification:modification receiver:receiver displayName:@"NSValue(CGPoint)" error:&validationError];
            if (!structValue) { break; }
            CGPoint expectedValue = structValue.CGPointValue;
            [setterInvocation setArgument:&expectedValue atIndex:2];
            break;
        }
        case LookinAttrTypeCGVector: {
            NSValue *structValue = [self _structValueFromModification:modification receiver:receiver displayName:@"NSValue(CGVector)" error:&validationError];
            if (!structValue) { break; }
            CGVector expectedValue = structValue.CGVectorValue;
            [setterInvocation setArgument:&expectedValue atIndex:2];
            break;
        }
        case LookinAttrTypeCGSize: {
            NSValue *structValue = [self _structValueFromModification:modification receiver:receiver displayName:@"NSValue(CGSize)" error:&validationError];
            if (!structValue) { break; }
            CGSize expectedValue = structValue.CGSizeValue;
            [setterInvocation setArgument:&expectedValue atIndex:2];
            break;
        }
        case LookinAttrTypeCGRect: {
            NSValue *structValue = [self _structValueFromModification:modification receiver:receiver displayName:@"NSValue(CGRect)" error:&validationError];
            if (!structValue) { break; }
            CGRect expectedValue = structValue.CGRectValue;
            [setterInvocation setArgument:&expectedValue atIndex:2];
            break;
        }
        case LookinAttrTypeCGAffineTransform: {
            NSValue *structValue = [self _structValueFromModification:modification receiver:receiver displayName:@"NSValue(CGAffineTransform)" error:&validationError];
            if (!structValue) { break; }
            CGAffineTransform expectedValue = structValue.CGAffineTransformValue;
            [setterInvocation setArgument:&expectedValue atIndex:2];
            break;
        }
        case LookinAttrTypeUIEdgeInsets: {
            NSValue *structValue = [self _structValueFromModification:modification receiver:receiver displayName:@"NSValue(UIEdgeInsets)" error:&validationError];
            if (!structValue) { break; }
            UIEdgeInsets expectedValue = structValue.UIEdgeInsetsValue;
            [setterInvocation setArgument:&expectedValue atIndex:2];
            break;
        }
        case LookinAttrTypeUIOffset: {
            NSValue *structValue = [self _structValueFromModification:modification receiver:receiver displayName:@"NSValue(UIOffset)" error:&validationError];
            if (!structValue) { break; }
            UIOffset expectedValue = structValue.UIOffsetValue;
            [setterInvocation setArgument:&expectedValue atIndex:2];
            break;
        }
        case LookinAttrTypeCustomObj:
        case LookinAttrTypeNSString: {
            NSObject *expectedValue = modification.value;
            [setterInvocation setArgument:&expectedValue atIndex:2];
            [setterInvocation retainArguments];
            break;
        }
        case LookinAttrTypeUIColor: {
            NSArray<NSNumber *> *rgba = [self _rgbaValueFromModification:modification receiver:receiver error:&validationError];
            if (!rgba) { break; }
            UIColor *expectedValue = [UIColor lks_colorFromRGBAComponents:rgba];
            [setterInvocation setArgument:&expectedValue atIndex:2];
            [setterInvocation retainArguments];
            break;
        }
        default: {
            completion(nil, LookinErr_Inner);
            return;
        }
        }
    } @catch (NSException *exception) {
        validationError = [self _invalidValueErrorWithReceiver:receiver selector:modification.setterSelector attrType:modification.attrType expected:@"A compatible value for the requested attribute type" actualValue:modification.value];
    }

    if (validationError) {
        completion(nil, validationError);
        return;
    }
    
    NSError *error = nil;
    @try {
        [setterInvocation invoke];
    } @catch (NSException *exception) {
        error = [self _exceptionErrorWithReceiver:receiver selector:modification.setterSelector reason:exception.reason];
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (error) {
            completion(nil, error);
            return;
        }

        CALayer *layer = nil;
        if ([receiver isKindOfClass:[CALayer class]]) {
            layer = (CALayer *)receiver;
        } else if ([receiver isKindOfClass:[UIView class]]) {
            layer = ((UIView *)receiver).layer;
        } else {
            completion(nil, LookinErr_ObjNotFound);
            return;
        }
        // 比如试图更改 frame 时，这个改动很有可能触发用户业务的 relayout，因此这时 dispatch 一下以确保拿到的 attrGroups 数据是最新的
        LookinDisplayItemDetail *detail = [LookinDisplayItemDetail new];
        detail.displayItemOid = modification.targetOid;
        @try {
            detail.attributesGroupList = [LKS_AttrGroupsMaker attrGroupsForLayer:layer];

            NSString *version = modification.clientReadableVersion;
            if (version.length > 0 && [version lookin_numbericOSVersion] >= 10004) {
                LKS_CustomAttrGroupsMaker *maker = [[LKS_CustomAttrGroupsMaker alloc] initWithLayer:layer];
                [maker execute];
                detail.customAttrGroupList = [maker getGroups];
            }

            detail.frameValue = [NSValue valueWithCGRect:layer.frame];
            detail.boundsValue = [NSValue valueWithCGRect:layer.bounds];
            detail.hiddenValue = [NSNumber numberWithBool:layer.isHidden];
            detail.alphaValue = @(layer.opacity);
        } @catch (NSException *exception) {
            NSError *refreshError = [self _exceptionErrorWithReceiver:receiver selector:modification.getterSelector ?: modification.setterSelector reason:exception.reason];
            completion(nil, refreshError);
            return;
        }

        completion(detail, error);
    });
}


+ (void)handlePatchWithTasks:(NSArray<LookinStaticAsyncUpdateTask *> *)tasks block:(void (^)(LookinDisplayItemDetail *data))block {
    if (!block) {
        NSAssert(NO, @"");
        return;
    }
    [tasks enumerateObjectsUsingBlock:^(LookinStaticAsyncUpdateTask * _Nonnull task, NSUInteger idx, BOOL * _Nonnull stop) {
        LookinDisplayItemDetail *itemDetail = [LookinDisplayItemDetail new];
        itemDetail.displayItemOid = task.oid;
        id object = [NSObject lks_objectWithOid:task.oid];
        if (!object || ![object isKindOfClass:[CALayer class]]) {
            block(itemDetail);
            return;
        }
        
        CALayer *layer = object;
        if (task.taskType == LookinStaticAsyncUpdateTaskTypeSoloScreenshot) {
            UIImage *image = [layer lks_soloScreenshotWithLowQuality:NO];
            itemDetail.soloScreenshot = image;
        } else if (task.taskType == LookinStaticAsyncUpdateTaskTypeGroupScreenshot) {
            UIImage *image = [layer lks_groupScreenshotWithLowQuality:NO];
            itemDetail.groupScreenshot = image;
        }
        block(itemDetail);
    }];
}

@end

#endif /* SHOULD_COMPILE_LOOKIN_SERVER */
