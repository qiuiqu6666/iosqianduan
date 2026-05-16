//telegram @wz662
/*
 * Copyright (C) 2019  即时通讯网(52im.net) & Jack Jiang.
 * The RainbowChat Project. All rights reserved.
 *
 * 【本产品为著作权产品，合法授权后，请在授权范围内放心使用，禁止外传！】
 * 授权说明请见：http://www.52im.net/thread-1115-1-1.html
 *
 * 【本系列产品在国家版权局的著作权登记信息如下】：
 * 1）国家版权局登记名（简称）和证书号：RainbowChat（软著登字第1220494号）
 * 2）国家版权局登记名（简称）和证书号：RainbowChat-Web（软著登字第3743440号）
 * 3）国家版权局登记名（简称）和证书号：RainbowAV（软著登字第2262004号）
 * 4）国家版权局登记名（简称）和证书号：MobileIMSDK-Web（软著登字第2262073号）
 * 5）国家版权局登记名（简称）和证书号：MobileIMSDK（软著登字第1220581号）
 * 著作权所有人：江顺/苏州网际时代信息科技有限公司
 *
 * 【违法或违规使用投诉和举报方式】：
 * 联系邮件：jack.jiang@52im.net
 * 联系微信：hellojackjiang
 * 联系QQ：413980957
 * 官方社区：http://www.52im.net
 */

#import <UIKit/UIKit.h>

@interface UIViewController (Ext)

- (IBAction)E_textFieldDidEndOnExit:(id)sender;

- (IBAction)E_clickBgToHideKeyboard:(id)sender;

- (void) E_showToastInfo:(NSString *)title withContent:(NSString *)content onParent:(UIView *)parentView;

@end
