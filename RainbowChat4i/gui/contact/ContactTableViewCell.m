//telegram @wz662
#import "ContactTableViewCell.h"

@implementation ContactTableViewCell

- (void)awakeFromNib {
    [super awakeFromNib];
    self.viewAvadar.clipsToBounds = YES;
    CGFloat s = MIN(CGRectGetWidth(self.viewAvadar.bounds), CGRectGetHeight(self.viewAvadar.bounds));
    if (s <= 0) {
        s = 40.f;
    }
    self.viewAvadar.layer.cornerRadius = s * 0.5f;
    self.viewAvadar.layer.masksToBounds = YES;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

@end
