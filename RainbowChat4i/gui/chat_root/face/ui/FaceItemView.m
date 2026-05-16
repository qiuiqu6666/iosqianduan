//telegram @wz662

#import "FaceItemView.h"
#import "FaceDataProvider.h"
#import "BasicTool.h"

@interface FaceItemView ()

@property (nonatomic, strong) UIImageView *imageView;

@property (nonatomic, strong) UILabel *titlLabel;


@end

@implementation FaceItemView


- (instancetype)init {
    if (self = [super init]) {
        self.imageView = [[UIImageView alloc] init];
        [self addSubview:self.imageView];
        
        self.titlLabel = [[UILabel alloc] init];
        self.titlLabel.font = [BasicTool getSystemFontOfSize:10];
        self.titlLabel.textColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0];
        self.titlLabel.adjustsFontSizeToFitWidth = YES;
        self.titlLabel.textAlignment = NSTextAlignmentCenter;
        [self addSubview:self.titlLabel];        
    }
    return self;
}

- (void)setEmoji:(FaceMeta *)emoji {
    _emoji = emoji;
    self.imageView.image = emoji.image;    
    self.titlLabel.text = emoji.desc.length>3? [emoji.desc substringWithRange:NSMakeRange(2, emoji.desc.length - 3)] : @""; // Freeman修改，以适应desc未空字符串或小于3个字符串的情况，使之不至于崩溃
    self.hidden = emoji == nil;
}

- (void)setIsShowTitle:(BOOL)isShowTitle {
    _isShowTitle = isShowTitle;
    UIViewContentMode contentMode = isShowTitle ? UIViewContentModeScaleAspectFit : UIViewContentModeCenter;
    self.imageView.contentMode = contentMode;
}

- (void)addTarget:(nullable id)target action:(SEL)action {
    for (UIGestureRecognizer *ges in self.gestureRecognizers) {
        [self removeGestureRecognizer:ges];
    }
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:target action:action];
    [self addGestureRecognizer:tap];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (self.isShowTitle) {
        self.imageView.frame = CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height - 15);
        self.titlLabel.frame = CGRectMake(0, CGRectGetMaxY(self.imageView.frame), self.bounds.size.width, 15);
    }else {
        self.imageView.frame = self.bounds;
        self.titlLabel.frame = CGRectZero;
    }
}

@end
