//telegram @wz662

#import "FacePreviewView.h"

@interface FacePreviewView ()

@property (nonatomic, strong) FaceBoardConfig *config;
// 预览中的表情图片
@property (nonatomic, strong) UIImageView *faceImageView;

@property (nonatomic, strong) UILabel *descriptionLabel;

@end

@implementation FacePreviewView

- (instancetype)initWithConfig:(FaceBoardConfig * _Nonnull)config {
    if (self = [super init]) {
        self.config = config;
               
        self.contentMode = UIViewContentModeCenter;
        self.faceImageView = [[UIImageView alloc] init];
        [self addSubview:self.faceImageView];
        
        self.descriptionLabel = [[UILabel alloc] init];
        self.descriptionLabel.font = config.emojiPreviewDescLabelFont;
        self.descriptionLabel.textColor = config.emojiPreviewDescLabelTextColor;
        self.descriptionLabel.textAlignment = NSTextAlignmentCenter;
        self.descriptionLabel.adjustsFontSizeToFitWidth = YES;
        [self addSubview:self.descriptionLabel];
    }
    return self;
}

- (void)setEmojiItemModel:(FaceMeta *)emojiModel {
    self.descriptionLabel.text = emojiModel.desc.length>3? [emojiModel.desc substringWithRange:NSMakeRange(2, emojiModel.desc.length - 3)] : @""; // Freeman修改，以适应desc未空字符串或小于3个字符串的情况，使之不至于崩溃
    self.image = self.config.emojiPreviewBgImage;
    self.faceImageView.image = emojiModel.image;
    self.faceImageView.contentMode = UIViewContentModeScaleAspectFit;//UIViewContentModeCenter;
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
       
    CGFloat emojiPreviewImage_w = 0;
    emojiPreviewImage_w = self.bounds.size.width - self.config.emojiImageViewEdgeInsets.left - self.config.emojiImageViewEdgeInsets.right;
    CGFloat x = (self.bounds.size.width - emojiPreviewImage_w) / 2.0;
    CGFloat y = self.config.emojiImageViewEdgeInsets.top;
    CGFloat label_h = self.config.emojiPreviewDescLabel_h;
    CGFloat labelOffset_y = self.config.emojiImageViewEdgeInsets.bottom;
    self.faceImageView.frame = CGRectMake(x, y, emojiPreviewImage_w, emojiPreviewImage_w);
    self.descriptionLabel.frame = CGRectMake(x, CGRectGetMaxY(self.faceImageView.frame) + labelOffset_y, emojiPreviewImage_w, label_h);

}



@end
