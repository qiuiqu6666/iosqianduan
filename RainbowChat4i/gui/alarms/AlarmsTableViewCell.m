//telegram @wz662
#import "AlarmsTableViewCell.h"
#import "Default.h"

/// 与置顶图标、未读角标统一的右侧槽位（右缘距 contentView 为 kRbAlarmsPinTrailing）
static const CGFloat kRbAlarmsPinTrailing = 15.f;
static const CGFloat kRbAlarmsUnreadDotSize = 11.f;
static const CGFloat kRbAlarmsPinIconSize = 16.f;
/// 与 AlarmsViewController 中分隔线左 inset 一致（头像区 15+61）
static const CGFloat kRbAlarmsSeparatorLeading = 76.f;

@interface AlarmsTableViewCell ()
@property (nonatomic, strong) UIView *rbBottomHairline;
@end

@implementation AlarmsTableViewCell

- (void)awakeFromNib {
    [super awakeFromNib];
    self.viewMsgContent.numberOfLines = 1;
    self.viewMsgContent.lineBreakMode = NSLineBreakByTruncatingTail;
    if (self.viewTitleRightFlagImageView != nil) {
        self.viewTitleRightFlagImageView.contentMode = UIViewContentModeScaleAspectFit;
        self.viewTitleRightFlagImageView.hidden = YES;
    }
    self.viewFlagNum2.translatesAutoresizingMaskIntoConstraints = NO;
    self.viewFlagDot.translatesAutoresizingMaskIntoConstraints = NO;
    if (self.viewAlwaystopIcon != nil) {
        UIImage *pinImg = self.viewAlwaystopIcon.image ?: [UIImage imageNamed:@"main_alarms_list_item_alwaytop"];
        if (pinImg != nil) {
            pinImg = [pinImg imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
            self.viewAlwaystopIcon.tintColor = nil;
            self.viewAlwaystopIcon.image = pinImg;
        } else {
            // 工程若未把 main_alarms_list_item_alwaytop 打进 target，imageNamed 为 nil → 用系统图钉兜底
            UIImage *sym = [UIImage systemImageNamed:@"pin.fill"];
            if (sym != nil) {
                self.viewAlwaystopIcon.image = [sym imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
                self.viewAlwaystopIcon.tintColor = [UIColor labelColor];
            }
        }
        self.viewAlwaystopIcon.contentMode = UIViewContentModeScaleAspectFit;
        self.viewAlwaystopIcon.alpha = 1.0;
        self.viewAlwaystopIcon.layer.zPosition = 2000.f;
        // 放在 cell 上而非 contentView 内：避免被同级 UILabel 盖住或被 contentView 裁剪；坐标在 layoutSubviews 用 convertRect 换算
        self.viewAlwaystopIcon.translatesAutoresizingMaskIntoConstraints = YES;
        self.viewAlwaystopIcon.autoresizingMask = UIViewAutoresizingNone;
        [self.viewAlwaystopIcon removeFromSuperview];
        [self addSubview:self.viewAlwaystopIcon];
    }
    if (self.viewFlagNum2 != nil) {
        self.viewFlagNum2.layer.zPosition = 1100.f;
    }
    if (self.viewFlagDot != nil) {
        self.viewFlagDot.layer.zPosition = 1100.f;
    }
    UIView *sb = [[UIView alloc] initWithFrame:CGRectZero];
    sb.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    sb.backgroundColor = UI_DEFAULT_TABLE_VIEW_SELECTED_BG_COLOR;
    self.selectedBackgroundView = sb;

    CGFloat hair = 1.0f / MAX((CGFloat)[UIScreen mainScreen].scale, 1.f);
    UIView *line = [[UIView alloc] initWithFrame:CGRectZero];
    line.translatesAutoresizingMaskIntoConstraints = NO;
    line.backgroundColor = UI_DEFAULT_TABLE_VIEW_DIVIDER_GRAY;
    line.userInteractionEnabled = NO;
    [self.contentView addSubview:line];
    self.rbBottomHairline = line;
    [NSLayoutConstraint activateConstraints:@[
        [line.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:kRbAlarmsSeparatorLeading],
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
    CGFloat midY = 0;
    if (self.viewMsgContent != nil && CGRectGetHeight(self.viewMsgContent.bounds) > 0.5) {
        midY = CGRectGetMidY(self.viewMsgContent.frame);
    } else {
        midY = CGRectGetMidY(self.contentView.bounds);
    }
    CGFloat rightX = CGRectGetWidth(self.contentView.bounds) - kRbAlarmsPinTrailing;

    if (self.viewAlwaystopIcon != nil && !self.viewAlwaystopIcon.hidden) {
        if (self.viewAlwaystopIcon.superview != self) {
            [self.viewAlwaystopIcon removeFromSuperview];
            [self addSubview:self.viewAlwaystopIcon];
        }
        CGFloat s = kRbAlarmsPinIconSize;
        CGFloat midPinY = midY;
        if (self.viewMsgContent != nil) {
            CGRect msgInCell = [self.contentView convertRect:self.viewMsgContent.frame toView:self];
            if (CGRectGetHeight(msgInCell) > 0.5) {
                midPinY = CGRectGetMidY(msgInCell);
            } else {
                midPinY = CGRectGetMidY(self.bounds);
            }
        } else {
            midPinY = CGRectGetMidY(self.bounds);
        }
        CGFloat x = CGRectGetWidth(self.bounds) - kRbAlarmsPinTrailing - s;
        self.viewAlwaystopIcon.frame = CGRectMake(x, midPinY - s * 0.5f, s, s);
        if (self.viewAlwaystopIcon.image == nil) {
            UIImage *sym = [UIImage systemImageNamed:@"pin.fill"];
            if (sym != nil) {
                self.viewAlwaystopIcon.image = [sym imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
                if (self.viewAlwaystopIcon.tintColor == nil) {
                    self.viewAlwaystopIcon.tintColor = [UIColor labelColor];
                }
            }
        }
        [self bringSubviewToFront:self.viewAlwaystopIcon];
        // UITableViewCell 在 super layoutSubviews 里可能调整子视图顺序，必须把置顶图固定叠在 contentView 之上，否则会出现「hidden=NO 但仍不可见」
        if (self.contentView != nil) {
            [self insertSubview:self.viewAlwaystopIcon aboveSubview:self.contentView];
        }
    }

    if (self.viewFlagDot != nil && !self.viewFlagDot.hidden) {
        CGFloat w = kRbAlarmsUnreadDotSize;
        self.viewFlagDot.frame = CGRectMake(rightX - w, midY - w * 0.5f, w, w);
    }
    if (self.viewFlagNum2 != nil && !self.viewFlagNum2.hidden) {
        CGSize sz = self.viewFlagNum2.bounds.size;
        if (sz.width < 1.f || sz.height < 1.f) {
            sz = self.viewFlagNum2.frame.size;
        }
        self.viewFlagNum2.frame = CGRectMake(rightX - sz.width, midY - sz.height * 0.5f, sz.width, sz.height);
    }

    if (self.viewFlagNum2 != nil && !self.viewFlagNum2.hidden) {
        [self.contentView bringSubviewToFront:self.viewFlagNum2];
    }
    if (self.viewFlagDot != nil && !self.viewFlagDot.hidden) {
        [self.contentView bringSubviewToFront:self.viewFlagDot];
    }
    if (self.rbBottomHairline != nil && !self.rbBottomHairline.hidden) {
        [self.contentView bringSubviewToFront:self.rbBottomHairline];
    }
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

@end
