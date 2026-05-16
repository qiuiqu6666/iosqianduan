//telegram @wz662
//
//  XYMenuView.m
//  XYMenu
//
//  Created by FireHsia on 2018/1/18.
//  Copyright © 2018年 FireHsia. All rights reserved.
//

#import "XYMenuView.h"
#import "XYMenuItem.h"

#define kXYMenuContentBackColor [UIColor colorWithRed:255.0f/255.0f green:255.0f/255.0f blue:255.0f/255.0f alpha:1.0f]//[UIColor colorWithWhite:0.4 alpha:1.0]
//#define kXYMenuContentLineColor [UIColor colorWithRed:201.0f/255.0f green:206.0f/255.0f blue:216.0f/255.0f alpha:1.0f]//[UIColor colorWithWhite:0.7 alpha:1.0]
#define kXYMenuContentLineColor [UIColor colorWithRed:232.0f/255.0f green:234.0f/255.0f blue:238.0f/255.0f alpha:1.0f]
#define kItemBtnTag 1001
// 顶部小3角的高度
static const CGFloat kTriangleHeight = 6;

// 顶部圆角半径 add by JackJiang v6.1
static const CGFloat kCorner = 12;//14;//16

@interface XYMenuView()
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) NSArray *imagesArr;
@property (nonatomic, strong) NSArray *titlesArr;
@property (nonatomic, assign) XYMenuType menuType;
@property (nonatomic, assign) BOOL isDown;
@property (nonatomic, copy) ItemClickBlock itemClickBlock;

@end

@implementation XYMenuView

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        _isDown = YES;
        self.backgroundColor = [UIColor clearColor];
        [self addSubview:self.contentView];
        self.contentView.frame = frame;
        self.layer.shadowRadius = kCorner;//2;
        self.layer.shadowColor = [UIColor colorWithRed:0.0f/255.0f green:0.0f/255.0f blue:0.0f/255.0f alpha:0.05f].CGColor;//[UIColor blackColor].CGColor;
        self.layer.shadowOpacity = 1;
        self.layer.shadowOffset = CGSizeMake(1, 1);
    }
    return self;
}

- (void)setImagesArr:(NSArray *)imagesArr titles:(NSArray *)titles withRect:(CGRect)rect withMenuType:(XYMenuType)menuType isDown:(BOOL)isDown withItemClickBlock:(ItemClickBlock)block
{
    _isDown = isDown;
    _menuType = menuType;
    _imagesArr = [NSArray arrayWithArray:imagesArr];
    _titlesArr = [NSArray arrayWithArray:titles];
    [self setMenuItemsWithRect:(CGRect)rect];
    if (block) {
        _itemClickBlock = block;
    }
    [self setNeedsDisplay];
}

- (instancetype)init
{
    return [self initWithFrame:CGRectZero];
}

- (void)drawRect:(CGRect)rect
{
    CGFloat kContentWidth = self.bounds.size.width;
    CGFloat kContentHeight = self.bounds.size.height;
    CGFloat kContentMidX = CGRectGetMidX(self.bounds);
    CGFloat triangleX;
    UIBezierPath *trianglePath = [UIBezierPath bezierPath];
    if (_isDown) {
        switch (_menuType) {
            case XYMenuLeftNormal:
            case XYMenuLeftNavBar:
            {
                triangleX = (kContentWidth / 4) - (kTriangleLength / 2);
            }
                break;
            case XYMenuRightNormal:
            case XYMenuRightNavBar:
            {
//                triangleX = kContentMidX + (kContentWidth / 4) - (kTriangleLength / 2);
                triangleX = kContentWidth -25.5f - (kTriangleLength / 2); // 修改箭头的x作标位置，以便能对准图标位置，而不产生偏移（25.5是一个实际偏移值增益）
            }
                break;
            default:
                triangleX = kContentMidX - (kTriangleLength / 2);
                break;
        }
        
        [trianglePath moveToPoint:CGPointMake(triangleX, kTriangleHeight)];
        [trianglePath addLineToPoint:CGPointMake(triangleX + (kTriangleLength / 2), 0)];
        [trianglePath addLineToPoint:CGPointMake(triangleX + kTriangleLength, kTriangleHeight)];
    }else {
        switch (_menuType) {
            case XYMenuLeftNormal:
            case XYMenuLeftNavBar:
            {
                triangleX = (kContentWidth / 4) - (kTriangleLength / 2);
            }
                break;
            case XYMenuRightNormal:
            case XYMenuRightNavBar:
            {
                triangleX = kContentMidX + (kContentWidth / 4) - (kTriangleLength / 2);
            }
                break;
            default:
                triangleX = kContentMidX - (kTriangleLength / 2);
                break;
        }
        [trianglePath moveToPoint:CGPointMake(triangleX, kContentHeight - kTriangleHeight)];
        [trianglePath addLineToPoint:CGPointMake(triangleX + (kTriangleLength / 2), kContentHeight)];
        [trianglePath addLineToPoint:CGPointMake(triangleX + kTriangleLength, kContentHeight - kTriangleHeight)];
    }
    
    [kXYMenuContentBackColor set];
    [trianglePath fill];
    
    if (_isDown) {
        UIBezierPath *radiusPath = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, kTriangleHeight, self.bounds.size.width, self.bounds.size.height - kTriangleHeight) cornerRadius:kCorner];//5
        [kXYMenuContentBackColor set];
        [radiusPath fill];
    }else {
        UIBezierPath *radiusPath = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height - kTriangleHeight) cornerRadius:kCorner];//5
        [kXYMenuContentBackColor set];
        [radiusPath fill];
    }
    
}

- (void)btnAction:(UIButton *)sender
{
    if (_itemClickBlock) {
        _itemClickBlock(sender.tag - 1000);
    }
}

- (void)showContentView
{
    self.contentView.hidden = NO;
    self.contentView.frame = self.bounds;
}

- (void)hideContentView
{
    self.contentView.hidden = YES;
}

#pragma mark --- 创建Items
- (void)setMenuItemsWithRect:(CGRect)rect
{
    NSArray *subViews = self.contentView.subviews;
    for (UIView *subV in subViews) {
        [subV removeFromSuperview];
    }
    CGFloat menuContentWidth = rect.size.width;
    CGFloat menuContentHeight = rect.size.height;
    NSInteger count = self.titlesArr.count;
    CGFloat kContentItemHeight = (menuContentHeight - kTriangleHeight) / count;
    for (int i = 0; i < count; i++) {
        UIButton *itemBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        itemBtn.backgroundColor = [UIColor clearColor];
        itemBtn.layer.cornerRadius = kCorner;//5;
        itemBtn.layer.masksToBounds = YES;
        itemBtn.tag = kItemBtnTag + i;
        [itemBtn addTarget:self action:@selector(btnAction:) forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:itemBtn];
        XYMenuItem *item = [[XYMenuItem alloc] initWithIconName:self.imagesArr[i] title:self.titlesArr[i]];
        item.userInteractionEnabled = NO;
        [self.contentView addSubview:item];
        if (_isDown) {
            [item setUpViewsWithRect:CGRectMake(0, (i * kContentItemHeight) + kTriangleHeight, menuContentWidth, kContentItemHeight)];
            itemBtn.frame = CGRectMake(0, (i * kContentItemHeight)+ kTriangleHeight , menuContentWidth, kContentItemHeight);
            if (i != 0) {
                CALayer *lineLayer = [[CALayer alloc] init];
                lineLayer.cornerRadius = 0.5;
                lineLayer.backgroundColor = kXYMenuContentLineColor.CGColor;
                lineLayer.frame = CGRectMake((kContentItemHeight / 3) - 4, (i * kContentItemHeight) + kTriangleHeight - 1, menuContentWidth - (kContentItemHeight * 2 / 3) + 8, 0.5);
                [self.contentView.layer addSublayer:lineLayer];
            }
        }else {
            [item setUpViewsWithRect:CGRectMake(0, (i * kContentItemHeight), menuContentWidth, kContentItemHeight)];
            itemBtn.frame = CGRectMake(0, (i * kContentItemHeight), menuContentWidth, kContentItemHeight);
            if (i != 0) {
                CALayer *lineLayer = [[CALayer alloc] init];
                lineLayer.cornerRadius = 0.5;
                lineLayer.backgroundColor = kXYMenuContentLineColor.CGColor;
                lineLayer.frame = CGRectMake((kContentItemHeight / 3) - 4, (i * kContentItemHeight) - 1, menuContentWidth - (kContentItemHeight * 2 / 3) + 8, 0.5);
                [self.contentView.layer addSublayer:lineLayer];
            }
        }
        UIImage *buttonHighlightedImage = [self buttonHighlightedImageWithSize:itemBtn.bounds.size];
        [itemBtn setImage:buttonHighlightedImage forState:UIControlStateHighlighted];
    }
}

- (UIImage *)buttonHighlightedImageWithSize:(CGSize)size
{
    UIImage *hightImage = [UIImage new];
    UIGraphicsBeginImageContextWithOptions(size, YES, [UIScreen mainScreen].scale);
    UIBezierPath *bezierPath = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, size.width, size.height) cornerRadius:0];//cornerRadius:5];
//    [[UIColor colorWithWhite:0.3 alpha:1.0] set];
    [[UIColor colorWithRed:241.0f/255.0f green:242.0f/255.0f blue:247.0f/255.0f alpha:1.0f] set];
    [bezierPath fill];
    hightImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return hightImage;
}

- (UIView *)contentView
{
    if (!_contentView) {
        _contentView = [[UIView alloc] init];
        _contentView.userInteractionEnabled = YES;
        _contentView.backgroundColor = [UIColor clearColor];
    }
    return _contentView;
}

@end

