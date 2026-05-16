//telegram @wz662
#import "GroupsTableViewCell.h"
#import "Default.h"

/// 与 GroupsViewController 中分隔线左 inset 一致（头像区 + 间距）
static const CGFloat kRbGroupsSeparatorLeading = 68.f;

@interface GroupsTableViewCell ()
@property (nonatomic, strong) UIView *rbBottomHairline;
@end

@implementation GroupsTableViewCell

- (void)awakeFromNib {
    [super awakeFromNib];
    CGFloat hair = 1.0f / MAX((CGFloat)[UIScreen mainScreen].scale, 1.f);
    UIView *line = [[UIView alloc] initWithFrame:CGRectZero];
    line.translatesAutoresizingMaskIntoConstraints = NO;
    line.backgroundColor = UI_DEFAULT_TABLE_VIEW_DIVIDER_GRAY;
    line.userInteractionEnabled = NO;
    [self.contentView addSubview:line];
    self.rbBottomHairline = line;
    [NSLayoutConstraint activateConstraints:@[
        [line.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:kRbGroupsSeparatorLeading],
        [line.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [line.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],
        [line.heightAnchor constraintEqualToConstant:hair],
    ]];
}

- (void)rb_setHairlineBottomSeparatorHidden:(BOOL)hidden {
    self.rbBottomHairline.hidden = hidden;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (self.rbBottomHairline != nil && !self.rbBottomHairline.hidden) {
        [self.contentView bringSubviewToFront:self.rbBottomHairline];
    }
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

@end
