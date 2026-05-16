//telegram @wz662
//
//  QRCodeScheme.m
//  RainbowChat4i
//
//  Created by Jack Jiang on 2022/9/6.
//  Copyright © 2022 JackJiang. All rights reserved.
//

#import "QRCodeScheme.h"
#import "QueryFriendInfoAsync.h"
#import "ViewControllerFactory.h"
#import "QQLBXScanViewController.h"
#import "StyleDIY.h"
#import "JoinGroupViewController.h"

/** 2维码内容前缀：扫码添加好友 */
NSString * _Nonnull const QR_CODE_SCHEME_ADD_USER = @"52im_rainbowchat://add_user/";
/** 2维码内容前缀：扫码加群 */
NSString * _Nonnull const QR_CODE_PSCHEME_JOIN_GROUP = @"52im_rainbowchat://join_group/";


@implementation QRCodeScheme

+ (BOOL) isAddUserQRCode:(NSString *)scheme {
    return [QR_CODE_SCHEME_ADD_USER isEqualToString:scheme];
}

+ (BOOL) isJoinGroupQRCode:(NSString *)scheme {
    return [QR_CODE_PSCHEME_JOIN_GROUP isEqualToString:scheme];
}

+ (NSString *)constructCodeStr:(NSString *)scheme withValue:(NSString *)value {
    return [NSString stringWithFormat:@"%@%@",scheme, value];
}

// 构造指定用户的加好友2维码的字符串
+ (NSString *)constructAddUserCodeStr:(NSString *)uid {
    return [QRCodeScheme constructCodeStr:QR_CODE_SCHEME_ADD_USER withValue:uid];
}

// 构造指定群聊的加群2维码的字符串
+ (NSString *)constructJoinGroupCodeStr:(NSString *)gid sharedByUid:(NSString *)sharedByUid {
    return [QRCodeScheme constructCodeStr:QR_CODE_PSCHEME_JOIN_GROUP withValue:[QRCodeScheme constructJoinGroupCodeSubStr:gid sharedByUid:sharedByUid]];
}

+ (NSString *)constructJoinGroupCodeSubStr:(NSString *)gid sharedByUid:(NSString *)sharedByUid {
    return [NSString stringWithFormat:@"%@_%@", gid, sharedByUid];
}

// 解析2维码内容
+ (QRCodeData *)parseCodeData:(NSString *)qrcodeStr
{
    if(qrcodeStr != nil && [qrcodeStr length] > 0){
        @try {
            char *lastChar = "/";
            int lastIndex = [BasicTool lastIndex:qrcodeStr of:lastChar];
            if(lastIndex != -1) {
                QRCodeData *d = [[QRCodeData alloc] init];
                // 2维码内容前缀（形如“52im_rainbowchat://add_user/”）
                NSString *scheme = [qrcodeStr substringWithRange:NSMakeRange(0, lastIndex + 1)];
                // 2维码内容（形如“400069”）
                NSString *value = [qrcodeStr substringWithRange:NSMakeRange(lastIndex + 1, [qrcodeStr length]-(lastIndex+1))];
                
                // 设置
                d.scheme = scheme;
                d.value = value;
                
                NSLog(@"QRCodeScheme.parseCodeData的结果是，scheme=%@、value=%@", scheme, value);
                
                return d;
            } else {
                DDLogError(@"QRCodeScheme.parseCodeData时：无效的qrcodeStr=%@，无法完成解析！", qrcodeStr);
            }
        } @catch (NSException *exception){
            DDLogError(@"QRCodeScheme.parseCodeData时：无效的qrcodeStr=%@，Exception=%@", qrcodeStr, exception);
        }
    }
    return nil;
}

// 解析2维码扫码结果并进入相应和业务逻辑处理（主要用于从2维码扫描界面扫描完成后的回调结果处理）
+ (void)processQRCodeScanResult:(NSString *)originalQrcodeStr nav:(UINavigationController *)nav view:(UIView *)v vc:(UIViewController *)vc {
    if (originalQrcodeStr != nil) {
        QRCodeData *qrData = [QRCodeScheme parseCodeData:originalQrcodeStr];
        // 2维码内容前缀（形如“52im_rainbowchat://add_user/”）
        NSString *scheme = qrData.scheme;
        // 2维码内容（形如“400069”）
        NSString *value = qrData.value;
        
        if (![BasicTool isStringEmpty:[BasicTool trim:scheme]] && ![BasicTool isStringEmpty:[BasicTool trim:value]]) {
            if([QR_CODE_SCHEME_ADD_USER isEqualToString:scheme]) {
                // 进入用户资料界面
                [QueryFriendInfoAsync gotoWatchUserInfo:value withInfo:nil nav:nav view:v vc:vc addSource:@"qrcode"];
            } else if([QR_CODE_PSCHEME_JOIN_GROUP isEqualToString:scheme]) {
                // 进入加群确认界面
                [ViewControllerFactory goJoinGroupViewController:nav with:value joinBy:JOIN_BY_SCAN_QRCODE];
            } else {
                [BasicTool showAlertInfo:@"不支持的2维码内容！" parent:vc];
            }
        } else {
            [BasicTool showAlertInfo:@"无效的2维码！" parent:vc];
        }
    } else {
        [BasicTool showAlertInfo:@"无效的2维码！" parent:vc];
    }
}

/**
 * 进入本2维码扫描界面的统一工具方法。
 */
+ (void)gotoQrCodeScan:(UINavigationController *)nc scanComplete:(void (^)(NSString *))complete {
    
    // 如果栈中存在该界面则直接跳转过去（省的不断创建扫一扫界面，回退时体验不好）
    for (UIViewController *vc in nc.viewControllers) {
        if ([vc isKindOfClass:[QQLBXScanViewController class]]) {
            [nc popToViewController:vc animated:YES];
            return;
        }
    }
    
    QQLBXScanViewController *vc = [QQLBXScanViewController new];
    vc.libraryType = SLT_Native;
    vc.scanCodeType = SCT_QRCode;
    vc.style = [StyleDIY rainbowChatScanStyle];
    //镜头拉远拉近功能
    vc.isVideoZoom = NO;
    vc.hidesBottomBarWhenPushed = YES;
    // 设置扫描完成的结果回调
    vc.scanResult = complete;
    
    [nc pushViewController:vc animated:YES];
}

@end
