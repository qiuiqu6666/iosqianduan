//telegram @wz662

#import "FaceBoardConfig.h"
#import "BasicTool.h"

@implementation FaceBoardConfig

+ (FaceBoardConfig *)defaultConfig {
    return [[FaceBoardConfig alloc] init];
}

- (instancetype)init {
    if (self = [super init]) {
        
        // tabbar
        BOOL isIphoneX = UIScreen.mainScreen.bounds.size.height >= 812;
        self.tabBarHeigh = isIphoneX ? 64 : 44;
        
        // sendBtn
        self.sendButtonBackgroundColor = [UIColor clearColor];//[UIColor lightGrayColor];////[UIColor colorWithRed:63/255.0 green:154/255.0 blue:252/255.0 alpha:1.0];
        self.sendButtonTitleColor = UI_DEFAULT_PLAINT_BUTTON_LIGHT_GREEN_COLOR;//UIColor.whiteColor;
        self.sendButtonWidth = 80;//60;
        self.sendButtonTitleFont = [UIFont fontWithName:@"Helvetica-BoldOblique" size:18];//[UIFont systemFontOfSize:18];
        self.sendButtonTitle = @"发送";
        self.sendButtonImage = nil;
        
        // pageControl
        self.pageControlHeigh = 20;
        self.pageIndicatorTintColor = HexColor(0xdededd);//[UIColor colorWithRed:0.8 green:0.8 blue:0.8 alpha:1.0];
        self.currentPageIndicatorTintColor = HexColor(0x7a7b7b);//[UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:1.0];
        
        // pageView（透明，使用系统 inputView 背景）
        self.pageViewBackgroundColor = [UIColor clearColor];
        // 注意：修改此衬距时，要与ChatRootViewController中initFaceBoard方法里rect的度连动，也就是改动本值的上下左右时，要相应的加和减rect的宽和高，不然就会影响表情单元的大小！
        self.pageViewEdgeInsets = UIEdgeInsetsMake(10, 0, 10, 0);//5, 5, 5, 5);//js改前原：15, 10, 5, 15);
//        self.pageViewDeleteButtonImage = [UIImage imageNamed:@"delete-emoji" inBundle:[NSBundle bundleForClass:self.class] compatibleWithTraitCollection:nil];
        self.pageViewDeleteButtonImage = [UIImage imageNamed:@"delete_emoji_normal"];
        self.pageViewDeleteButtonPressedImage = [UIImage imageNamed:@"delete_emoji_pressed"];
        self.emojiLineCount = 3;
        self.emojiColumnCount = 7;
        self.pageViewMinLineSpace = 17;//17;//5;
        self.pageViewMinColumnSpace = 5;
        
        // emoji preview
        self.emojiPreviewBgImage = [UIImage imageNamed:@"emoji-preview-bg" inBundle:[NSBundle bundleForClass:self.class] compatibleWithTraitCollection:nil];
        self.emojiPreviewSize = CGSizeMake(90, 136);
        self.emojiImageViewEdgeInsets = UIEdgeInsetsMake(15, 25, 5, 25);//UIEdgeInsetsMake(12, 21, 0, 21);
        self.emojiPreviewDescLabel_h = 15;
        self.emojiPreviewDescLabelFont = [BasicTool getSystemFontOfSize:14];
        self.emojiPreviewDescLabelTextColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0];
    }
    return self;
}


@end

