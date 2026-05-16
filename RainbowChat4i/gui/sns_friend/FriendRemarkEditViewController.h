//telegram @wz662
//
//  FriendRemarkEditViewController.h
//  RainbowChat4i
//
//  Created by Jack Jiang on 2021/12/4.
//  Copyright © 2021 JackJiang. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface FriendRemarkEditViewController : UIViewController<UITextViewDelegate>

/* 备注输入框 */
@property (nonatomic, strong) UITextField *editRemark;
/* 手机号码输入框 */
@property (nonatomic, strong) UITextField *editMobileNum;
/* 更多描述输入框 */
@property (nonatomic, strong) UITextView *editMoreDesc;

- (id)initWithUid:(NSString *)friendUid;
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil withUid:(NSString *)friendUid;

@end
