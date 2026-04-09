#ifdef SHOULD_COMPILE_LOOKIN_SERVER 

//
//  LKS_AttrGroupsMaker.m
//  LookinServer
//
//  Created by Li Kai on 2019/6/6.
//  https://lookin.work
//

#import "LKS_AttrGroupsMaker.h"
#import "LookinAttributesGroup.h"
#import "LookinAttributesSection.h"
#import "LookinAttribute.h"
#import "LookinDashboardBlueprint.h"
#import "LookinIvarTrace.h"
#import "UIColor+LookinServer.h"
#import "LookinServerDefines.h"

@implementation LKS_AttrGroupsMaker

+ (NSArray<LookinAttributesGroup *> *)attrGroupsForLayer:(CALayer *)layer {
    if (!layer) {
        NSAssert(NO, @"");
        return nil;
    }
    NSArray<LookinAttributesGroup *> *groups = [[LookinDashboardBlueprint groupIDs] lookin_map:^id(NSUInteger idx, LookinAttrGroupIdentifier groupID) {
        LookinAttributesGroup *group = [LookinAttributesGroup new];
        group.identifier = groupID;

        NSArray<LookinAttrSectionIdentifier> *secIDs = [LookinDashboardBlueprint sectionIDsForGroupID:groupID];
        group.attrSections = [secIDs lookin_map:^id(NSUInteger idx, LookinAttrSectionIdentifier secID) {
            LookinAttributesSection *sec = [LookinAttributesSection new];
            sec.identifier = secID;
            
            NSArray<LookinAttrIdentifier> *attrIDs = [LookinDashboardBlueprint attrIDsForSectionID:secID];
            sec.attributes = [attrIDs lookin_map:^id(NSUInteger idx, LookinAttrIdentifier attrID) {
                NSInteger minAvailableVersion = [LookinDashboardBlueprint minAvailableOSVersionWithAttrID:attrID];
                if (minAvailableVersion > 0 && (NSProcessInfo.processInfo.operatingSystemVersion.majorVersion < minAvailableVersion)) {
                    // iOS 版本过低不支持该属性
                    return nil;
                }
                
                id targetObj = nil;
                if ([LookinDashboardBlueprint isUIViewPropertyWithAttrID:attrID]) {
                    targetObj = layer.lks_hostView;
                } else {
                    targetObj = layer;
                }
                
                if (targetObj) {
                    Class targetClass = NSClassFromString([LookinDashboardBlueprint classNameWithAttrID:attrID]);
                    if (![targetObj isKindOfClass:targetClass]) {
                        return nil;
                    }
                    
                    LookinAttribute *attr = [self _attributeWithIdentifer:attrID targetObject:targetObj];
                    return attr;
                } else {
                    return nil;
                }
            }];
            
            if (sec.attributes.count) {
                return sec;
            } else {
                return nil;
            }
        }];
        
        if ([groupID isEqualToString:LookinAttrGroup_AutoLayout]) {
            // 这里特殊处理一下，如果 AutoLayout 里面不包含 Constraints 的话（只有 Hugging 和 Resistance），就丢弃掉这整个 AutoLayout 不显示
            BOOL hasConstraits = [group.attrSections lookin_any:^BOOL(LookinAttributesSection *obj) {
                return [obj.identifier isEqualToString:LookinAttrSec_AutoLayout_Constraints];
            }];
            if (!hasConstraits) {
                return nil;
            }
        }
        
        if (group.attrSections.count) {
            return group;
        } else {
            return nil;
        }
    }];
    
    LookinAttributesGroup *runtimeMetadataGroup = [self _runtimeMetadataGroupForLayer:layer];
    if (runtimeMetadataGroup) {
        return [groups arrayByAddingObject:runtimeMetadataGroup];
    }
    return groups;
}

+ (LookinAttribute *)_attributeWithIdentifer:(LookinAttrIdentifier)identifier targetObject:(id)target {
    if (!target) {
        NSAssert(NO, @"");
        return nil;
    }
    
    LookinAttribute *attribute = [LookinAttribute new];
    attribute.identifier = identifier;
    
    SEL getter = [LookinDashboardBlueprint getterWithAttrID:identifier];
    if (!getter) {
        NSAssert(NO, @"");
        return nil;
    }
    if (![target respondsToSelector:getter]) {
        // 比如某些 QMUI 的属性，不引入 QMUI 就会走到这个分支里
        return nil;
    }
    NSMethodSignature *signature = [target methodSignatureForSelector:getter];
    if (signature.numberOfArguments > 2) {
        NSAssert(NO, @"getter 不可以有参数");
        return nil;
    }
    if (strcmp([signature methodReturnType], @encode(void)) == 0) {
        NSAssert(NO, @"getter 返回值不能为 void");
        return nil;
    }
    
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    invocation.target = target;
    invocation.selector = getter;
    @try {
        [invocation invoke];
    } @catch (NSException *exception) {
        return nil;
    }
    
    const char *returnType = [signature methodReturnType];
    
    if (strcmp(returnType, @encode(char)) == 0) {
        char targetValue;
        [invocation getReturnValue:&targetValue];
        attribute.attrType = LookinAttrTypeChar;
        attribute.value = @(targetValue);
        
    } else if (strcmp(returnType, @encode(int)) == 0) {
        int targetValue;
        [invocation getReturnValue:&targetValue];
        attribute.value = @(targetValue);
        if ([LookinDashboardBlueprint enumListNameWithAttrID:identifier]) {
            attribute.attrType = LookinAttrTypeEnumInt;
        } else {
            attribute.attrType = LookinAttrTypeInt;
        }
        
    } else if (strcmp(returnType, @encode(short)) == 0) {
        short targetValue;
        [invocation getReturnValue:&targetValue];
        attribute.attrType = LookinAttrTypeShort;
        attribute.value = @(targetValue);
        
    } else if (strcmp(returnType, @encode(long)) == 0) {
        long targetValue;
        [invocation getReturnValue:&targetValue];
        attribute.value = @(targetValue);
        if ([LookinDashboardBlueprint enumListNameWithAttrID:identifier]) {
            attribute.attrType = LookinAttrTypeEnumLong;
        } else {
            attribute.attrType = LookinAttrTypeLong;
        }
        
    } else if (strcmp(returnType, @encode(long long)) == 0) {
        long long targetValue;
        [invocation getReturnValue:&targetValue];
        attribute.attrType = LookinAttrTypeLongLong;
        attribute.value = @(targetValue);
        
    } else if (strcmp(returnType, @encode(unsigned char)) == 0) {
        unsigned char targetValue;
        [invocation getReturnValue:&targetValue];
        attribute.attrType = LookinAttrTypeUnsignedChar;
        attribute.value = @(targetValue);
        
    } else if (strcmp(returnType, @encode(unsigned int)) == 0) {
        unsigned int targetValue;
        [invocation getReturnValue:&targetValue];
        attribute.attrType = LookinAttrTypeUnsignedInt;
        attribute.value = @(targetValue);
        
    } else if (strcmp(returnType, @encode(unsigned short)) == 0) {
        unsigned short targetValue;
        [invocation getReturnValue:&targetValue];
        attribute.attrType = LookinAttrTypeUnsignedShort;
        attribute.value = @(targetValue);
        
    } else if (strcmp(returnType, @encode(unsigned long)) == 0) {
        unsigned long targetValue;
        [invocation getReturnValue:&targetValue];
        attribute.attrType = LookinAttrTypeUnsignedLong;
        attribute.value = @(targetValue);
        
    } else if (strcmp(returnType, @encode(unsigned long long)) == 0) {
        unsigned long long targetValue;
        [invocation getReturnValue:&targetValue];
        attribute.attrType = LookinAttrTypeUnsignedLongLong;
        attribute.value = @(targetValue);
        
    } else if (strcmp(returnType, @encode(float)) == 0) {
        float targetValue;
        [invocation getReturnValue:&targetValue];
        attribute.attrType = LookinAttrTypeFloat;
        attribute.value = @(targetValue);
        
    } else if (strcmp(returnType, @encode(double)) == 0) {
        double targetValue;
        [invocation getReturnValue:&targetValue];
        attribute.attrType = LookinAttrTypeDouble;
        attribute.value = @(targetValue);
        
    } else if (strcmp(returnType, @encode(BOOL)) == 0) {
        BOOL targetValue;
        [invocation getReturnValue:&targetValue];
        attribute.attrType = LookinAttrTypeBOOL;
        attribute.value = @(targetValue);
        
    } else if (strcmp(returnType, @encode(SEL)) == 0) {
        SEL targetValue;
        [invocation getReturnValue:&targetValue];
        attribute.attrType = LookinAttrTypeSel;
        attribute.value = NSStringFromSelector(targetValue);
        
    } else if (strcmp(returnType, @encode(Class)) == 0) {
        Class targetValue;
        [invocation getReturnValue:&targetValue];
        attribute.attrType = LookinAttrTypeClass;
        attribute.value = NSStringFromClass(targetValue);
        
    } else if (strcmp(returnType, @encode(CGPoint)) == 0) {
        CGPoint targetValue;
        [invocation getReturnValue:&targetValue];
        attribute.attrType = LookinAttrTypeCGPoint;
        attribute.value = [NSValue valueWithCGPoint:targetValue];
        
    } else if (strcmp(returnType, @encode(CGVector)) == 0) {
        CGVector targetValue;
        [invocation getReturnValue:&targetValue];
        attribute.attrType = LookinAttrTypeCGVector;
        attribute.value = [NSValue valueWithCGVector:targetValue];
        
    } else if (strcmp(returnType, @encode(CGSize)) == 0) {
        CGSize targetValue;
        [invocation getReturnValue:&targetValue];
        attribute.attrType = LookinAttrTypeCGSize;
        attribute.value = [NSValue valueWithCGSize:targetValue];
        
    } else if (strcmp(returnType, @encode(CGRect)) == 0) {
        CGRect targetValue;
        [invocation getReturnValue:&targetValue];
        attribute.attrType = LookinAttrTypeCGRect;
        attribute.value = [NSValue valueWithCGRect:targetValue];
        
    } else if (strcmp(returnType, @encode(CGAffineTransform)) == 0) {
        CGAffineTransform targetValue;
        [invocation getReturnValue:&targetValue];
        attribute.attrType = LookinAttrTypeCGAffineTransform;
        attribute.value = [NSValue valueWithCGAffineTransform:targetValue];
        
    } else if (strcmp(returnType, @encode(UIEdgeInsets)) == 0) {
        UIEdgeInsets targetValue;
        [invocation getReturnValue:&targetValue];
        attribute.attrType = LookinAttrTypeUIEdgeInsets;
        attribute.value = [NSValue valueWithUIEdgeInsets:targetValue];
        
    } else if (strcmp(returnType, @encode(UIOffset)) == 0) {
        UIOffset targetValue;
        [invocation getReturnValue:&targetValue];
        attribute.attrType = LookinAttrTypeUIOffset;
        attribute.value = [NSValue valueWithUIOffset:targetValue];
        
    } else {
        NSString *argType_string = [[NSString alloc] lookin_safeInitWithUTF8String:returnType];
        if ([argType_string hasPrefix:@"@"]) {
            __unsafe_unretained id returnObjValue;
            [invocation getReturnValue:&returnObjValue];
            
            if (!returnObjValue && [LookinDashboardBlueprint hideIfNilWithAttrID:identifier]) {
                // 对于某些属性，若 value 为 nil 则不显示
                return nil;
            }
            
            attribute.attrType = [LookinDashboardBlueprint objectAttrTypeWithAttrID:identifier];
            if (attribute.attrType == LookinAttrTypeUIColor) {
                if (returnObjValue == nil) {
                    attribute.value = nil;
                } else if ([returnObjValue isKindOfClass:[UIColor class]] && [returnObjValue respondsToSelector:@selector(lks_rgbaComponents)]) {
                    attribute.value = [returnObjValue lks_rgbaComponents];
                } else {
                    // https://github.com/QMUI/LookinServer/issues/124
                    return nil;
                }
            } else {
                attribute.value = returnObjValue;
            }
            
        } else {
            NSAssert(NO, @"不支持解析该类型的返回值");
            return nil;
        }
    }
    
    return attribute;
}

+ (LookinAttributesGroup *)_runtimeMetadataGroupForLayer:(CALayer *)layer {
    UIView *view = layer.lks_hostView;
    if (!view) {
        return nil;
    }

    NSMutableArray<LookinAttribute *> *attributes = [NSMutableArray array];
    [self _appendStringAttribute:@"accessibilityIdentifier" value:view.accessibilityIdentifier to:attributes];
    [self _appendStringAttribute:@"accessibilityLabel" value:view.accessibilityLabel to:attributes];
    [self _appendStringAttribute:@"displayText" value:[self _displayTextForView:view] to:attributes];

    if (attributes.count == 0) {
        return nil;
    }

    LookinAttributesSection *section = [LookinAttributesSection new];
    section.identifier = LookinAttrSec_UserCustom;
    section.attributes = attributes.copy;

    LookinAttributesGroup *group = [LookinAttributesGroup new];
    group.identifier = LookinAttrGroup_UserCustom;
    group.userCustomTitle = @"viewglass_runtime";
    group.attrSections = @[section];
    return group;
}

+ (void)_appendStringAttribute:(NSString *)identifier value:(NSString *)value to:(NSMutableArray<LookinAttribute *> *)attributes {
    if (identifier.length == 0 || value.length == 0) {
        return;
    }

    LookinAttribute *attribute = [LookinAttribute new];
    attribute.identifier = identifier;
    attribute.displayTitle = identifier;
    attribute.attrType = LookinAttrTypeNSString;
    attribute.value = value;
    [attributes addObject:attribute];
}

+ (NSString *)_displayTextForView:(UIView *)view {
    if ([view isKindOfClass:[UIButton class]]) {
        UIButton *button = (UIButton *)view;
        NSString *title = [button titleForState:UIControlStateNormal];
        if (title.length > 0) {
            return title;
        }
    }

    if ([view isKindOfClass:[UILabel class]]) {
        NSString *text = ((UILabel *)view).text;
        if (text.length > 0) {
            return text;
        }
    }

    if ([view isKindOfClass:[UITextField class]]) {
        UITextField *textField = (UITextField *)view;
        if (textField.text.length > 0) {
            return textField.text;
        }
        if (textField.placeholder.length > 0) {
            return textField.placeholder;
        }
    }

    if ([view isKindOfClass:[UITextView class]]) {
        UITextView *textView = (UITextView *)view;
        if (textView.text.length > 0) {
            return textView.text;
        }
    }

    return nil;
}

@end

#endif /* SHOULD_COMPILE_LOOKIN_SERVER */
