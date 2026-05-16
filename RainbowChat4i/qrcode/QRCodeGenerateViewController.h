//telegram @wz662
//
//  QRCodeGenerateViewController.h
//  RainbowChat4i
//
//  Created by Jack Jiang on 2022/9/8.
//  Copyright © 2022 JackJiang. All rights reserved.
//

/**
 * "我的二维码"和"群二维码"界面。
 *
 * @author JackJiang
 * @since 5.0
 */

#import <UIKit/UIKit.h>
#import "CommonViewController.h"

@interface QRCodeGenerateViewController : CommonViewController

/** 2维码及其辅助内容的父layout，当前主要用于将2维码保存到系统相册时（保存的就是这个layout view对象内容） */
@property (weak, nonatomic) IBOutlet UIView *layoutContent;
///** 主背景半透明边框效果的图片 */
//@property (weak, nonatomic) IBOutlet UIImageView *layoutContentBg;
/** 主背景的宽度约束，利于用此值的设置可以让AutoLayout下能自适应并设置屏幕宽度 */
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *layoutContent_width;

/** 标签：头像 */
@property (weak, nonatomic) IBOutlet UIImageView *viewAvatar;
/** 标签：昵称/群名称 */
@property (weak, nonatomic) IBOutlet UILabel *nameTextView;
/** 标签：描述 */
@property (weak, nonatomic) IBOutlet UILabel *descView;
/** 昵称/群名称距离右边的距离约束，利于用此值的设置可以让AutoLayout下能自适应距离 */
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *nameTextView_rightGap;

/** 标签：性别（仅用于“我的二维码”界面时显示） */
@property (weak, nonatomic) IBOutlet UIImageView *sexView;

/** 图片：2维码中间的logo图 */
@property (weak, nonatomic) IBOutlet UIImageView *viewAvatarLogo;
/** 图片：2维码图 */
@property (weak, nonatomic) IBOutlet UIImageView *viewQrcode;

/** 布局：2维码下方的描述区域 */
@property (weak, nonatomic) IBOutlet UIView *viewQrBottomDesc;
/** 标签：2维码下方描述文字第一行 */
@property (weak, nonatomic) IBOutlet UILabel *labelDescLine1;
/** 标签：2维码下方描述文字第二行 */
@property (weak, nonatomic) IBOutlet UILabel *labelDescLine2;
/** 布局：2维码上的logo父布局 */
@property (weak, nonatomic) IBOutlet UIView *layoutQrLogo;

/** 保存图片按钮 */
@property (weak, nonatomic) IBOutlet UIButton *btnSaveImage;
/** 扫一扫按钮 */
@property (weak, nonatomic) IBOutlet UIButton *btnScan;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil withScheme:(NSString *)scheme andId:(NSString *)theId;

/** 保存图片按钮点击事件 */
- (IBAction)clickSaveImage:(id)sender;
/** 扫一扫按钮点击事件 */
- (IBAction)clickScan:(id)sender;

@end
