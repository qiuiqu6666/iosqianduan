//telegram @wz662
//
//  QRCodeScheme.h
//  RainbowChat4i
//
//  Created by Jack Jiang on 2022/9/6.
//  Copyright © 2022 JackJiang. All rights reserved.
//

/**
 * 2维码编码前缀常量定义类。
 *
 * @author JackJiang
 * @since 5.0
 */

#import <Foundation/Foundation.h>
#import "QRCodeData.h"

@interface QRCodeScheme : NSObject

/** 2维码内容前缀：扫码添加好友 */
extern NSString * _Nonnull const QR_CODE_SCHEME_ADD_USER;
/** 2维码内容前缀：扫码加群 */
extern NSString * _Nonnull const QR_CODE_PSCHEME_JOIN_GROUP;

+ (BOOL) isAddUserQRCode:(NSString *)scheme;

+ (BOOL) isJoinGroupQRCode:(NSString *)scheme;

/**
 * 构造指定用户的加好友2维码的字符串。
 *
 * @param uid 用户uid
 * @return 将用于生成2维码的字符串
 */
+ (NSString *)constructAddUserCodeStr:(NSString *)uid;

/**
 * 构造指定群聊的加群2维码的字符串。
 *
 * @param gid 群id
 * @param sharedByUid 二维码分享者的uid
 * @return 将用于生成2维码的字符串
 */
+ (NSString *_Nonnull)constructJoinGroupCodeStr:(NSString *_Nonnull)gid sharedByUid:(NSString *_Nonnull)sharedByUid;

+ (NSString *_Nonnull)constructJoinGroupCodeSubStr:(NSString *_Nonnull)gid sharedByUid:(NSString *_Nonnull)sharedByUid;
    
/**
 * 解析2维码内容。
 *
 * @param qrcodeStr 扫描出的原始二维码字符串，形如：“52im_rainbowchat://add_user/400069”
 * @return 成功解析则返回QRCodeData对象，否则返回nil
 */
+ (QRCodeData *_Nonnull)parseCodeData:(NSString *_Nonnull)qrcodeStr;

/**
 * 解析2维码扫码结果并进入相应和业务逻辑处理（主要用于从2维码扫描界面扫描完成后的回调结果处理）。
 *
 * @param originalQrcodeStr 扫描出的原始2维码字符串，形如"52im_rainbowchat://add_user/400069"
 */
+ (void)processQRCodeScanResult:(NSString *)originalQrcodeStr nav:(UINavigationController *)nav view:(UIView *)v vc:(UIViewController *)vc;

/**
 * 进入本2维码扫描界面的统一工具方法。
 */
+ (void)gotoQrCodeScan:(UINavigationController *)nc scanComplete:(void (^)(NSString *))complete;

@end
