//telegram @wz662

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface FaceBoardConfig : NSObject

// ------------------------ tabbar
// tabbar 高度
@property (nonatomic, assign) CGFloat tabBarHeigh;

// ------------------------ 发送按钮
// 发送按钮背景颜色
@property (nonatomic, strong) UIColor *sendButtonBackgroundColor;
// 发送文字字体
@property (nonatomic, assign) UIFont *sendButtonTitleFont;
// 发送按钮文字颜色
@property (nonatomic, strong) UIColor *sendButtonTitleColor;
// 发送按钮宽度
@property (nonatomic, assign) CGFloat sendButtonWidth;
// 发送按钮文字
@property (nonatomic, copy, nullable) NSString *sendButtonTitle;
// 发送按钮图片
@property (nonatomic, strong, nullable) UIImage *sendButtonImage;

// ------------------------ pageControl
// 指示器高度
@property (nonatomic, assign) CGFloat pageControlHeigh;
// 指示器未选中颜色
@property (nonatomic, strong) UIColor *pageIndicatorTintColor;
// 指示器选中颜色
@property (nonatomic, strong) UIColor *currentPageIndicatorTintColor;

// ------------------------ pageView
// 背景颜色
@property (nonatomic, strong) UIColor *pageViewBackgroundColor;
// 表情按钮边距
@property (nonatomic, assign) UIEdgeInsets pageViewEdgeInsets;
// 小表情行数
@property (nonatomic, assign) NSInteger emojiLineCount;
// 小表情列数
@property (nonatomic, assign) NSInteger emojiColumnCount;
// 最小行间距
@property (nonatomic, assign) CGFloat pageViewMinLineSpace;
// 最小列间距
@property (nonatomic, assign) CGFloat pageViewMinColumnSpace;
// 删除按钮图片
@property (nonatomic, strong) UIImage *pageViewDeleteButtonImage;
// 删除按钮图片(按下时)
@property (nonatomic, strong) UIImage *pageViewDeleteButtonPressedImage;


// ------------------------ previewView
// emoji 预览视图大小
@property (nonatomic, assign) CGSize emojiPreviewSize;
// emoji 预览背景图片
@property (nonatomic, strong) UIImage *emojiPreviewBgImage;
// emoji 预览图片边距 bottom为距离 descLabel 的距离
@property (nonatomic, assign) UIEdgeInsets emojiImageViewEdgeInsets;
// descLabel 高度
@property (nonatomic, assign) CGFloat emojiPreviewDescLabel_h;
// descLabel 字体
@property (nonatomic, strong) UIFont *emojiPreviewDescLabelFont;
// descLabel 文字颜色
@property (nonatomic, strong) UIColor *emojiPreviewDescLabelTextColor;

+ (FaceBoardConfig *)defaultConfig;

@end

NS_ASSUME_NONNULL_END
