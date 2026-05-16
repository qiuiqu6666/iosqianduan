//telegram @wz662
//
//  JoinGroupViewController.h
//  RainbowChat4i
//
//  Created by Jack Jiang on 2022/9/7.
//  Copyright © 2022 JackJiang. All rights reserved.
//

/**
 * 加入群聊界面实现类（当前用于扫描加群二维码和群名片加群时）。
 *
 * @author JackJiang
 * @since 5.0
 */

#import <UIKit/UIKit.h>
#import "CommonViewController.h"


/** 加群方式：通过扫描二维码加群 */
#define JOIN_BY_SCAN_QRCODE   0
/** 加群方式：通过分享的群名片加群 */
#define JOIN_BY_GROUP_CONTACT 1


@interface JoinGroupViewController : CommonViewController

/** 群头像显示组件 */
@property (weak, nonatomic) IBOutlet UIImageView *viewIcon;
/** 群名称显示组件 */
@property (weak, nonatomic) IBOutlet UILabel *viewName;
/** 群描述显示组件 */
@property (weak, nonatomic) IBOutlet UILabel *viewDesc;
/** 确认按钮 */
@property (weak, nonatomic) IBOutlet UIButton *btnOk;

/** 按钮事件 */
- (IBAction)clickOk:(id)sender;

/** 初始化方法 */
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil with:(NSString *)qrcodeValue joinBy:(int)by;

@end

