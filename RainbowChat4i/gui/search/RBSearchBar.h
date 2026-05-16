//telegram @wz662
//
//  RBSearchBar.h
//  RainbowChat4i
//
//  Created by Jack Jiang on 2022/9/21.
//  Copyright © 2022 JackJiang. All rights reserved.
//
/**
 自定义搜索框控件.
 
 @author Jack Jiang
 @since 6.0
 */

#import <UIKit/UIKit.h>

@protocol RBSearchBarDelegate;


// 自定义搜索框控件主接口
@interface RBSearchBar : UIView

@property (weak, nonatomic) IBOutlet UITextField *viewEdit;
@property (weak, nonatomic) IBOutlet UIImageView *viewClear;
@property (weak, nonatomic) IBOutlet UIButton *btnCancel;
@property (nonatomic, weak) id<RBSearchBarDelegate> delegate;

/**
 设置搜索关键字。
 */
- (void)setKeyword:(NSString *)s;

/**
 将搜索框的光标移到输入的内容末尾。
 */
- (void)setCursorToEnd;

@end


// 自定义搜索框控件的delegate接口
@protocol RBSearchBarDelegate <NSObject>
@required

/**
 当点击界面上的“取消”按钮时，调用此方法。
 */
- (void)cancelForRBSearchbar:(RBSearchBar *)searchBar;

/**
 当输入框内的文本内容改变时，调用此方法。
 */
- (void)searchTextChangedForRBSearchbar:(RBSearchBar *)searchBar withText:(NSString *)keyword;
@end






