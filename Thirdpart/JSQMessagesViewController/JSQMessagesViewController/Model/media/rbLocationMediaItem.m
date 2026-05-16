//telegram @wz662
//
//  rbContactMediaItem.m
//  RainbowChat4i
//
//  Created by Jack Jiang.
//  Copyright © 2020 JackJiang. All rights reserved.
//

#import "rbLocationMediaItem.h"
#import "JSQMessagesBubbleImage.h"
#import "JSQMessagesBubbleImageFactory.h"
#import "FileDownloadHelper.h"
#import "LocationUtils.h"
#import "BasicTool.h"


// UIImageView的宽
#define kLocationIconWidth    240
// UIImageView的高
#define kLocationIconHeight   100
// 气泡箭头那部分的宽度
//#define kLocationBlloonArrowGap      8

// （该衬距是以收到的消息的UI为基准的哦），衬距以收到的消息气泡为准（上、左、下、右）
const UIEdgeInsets LocationMediaItemControlInsets = {14, 17, 0, 9};//{10, 15, 10, 8};
// （该衬距是以收到的消息的UI为基准的哦），衬距以收到的消息气泡为准（上、左、下、右）
const UIEdgeInsets LocationMediaItemImgInsets = {0, 8.5, 4, 4};//{0, 11.5, 4, 4.5};


@interface rbLocationMediaItem ()
// 整个ui父容器View
@property (strong, nonatomic) UIView *cachedMediaView;
// 标题组件
@property (strong, nonatomic) UILabel *titleView;
// 地址组件
@property (strong, nonatomic) UILabel *addrView;
// 预览图组件
@property (strong, nonatomic) UIImageView *previewImgView;
// 装饰：横线
@property (strong, nonatomic) UIView *lineView;
// 装饰：圆角
@property (strong, nonatomic) UIImageView *roundImgView;
// 装饰：大头针
@property (strong, nonatomic) UIImageView *pinImgView;

// 名片消息元数据对象引用
@property (strong, nonatomic) LocationMeta *locationMeta;

@end


@implementation rbLocationMediaItem

#pragma mark - Initialization

- (instancetype)initWithData:(LocationMeta *)locationMeta
{
    self = [super init];
    if (self) {
        _cachedMediaView = nil;
        _locationMeta = locationMeta;
    }
    return self;
}

- (void)dealloc
{
    _locationMeta = nil;
    _image = nil;

    [self clearCachedMediaViews];
}

- (void)clearCachedMediaViews
{
    _titleView = nil;
    _previewImgView = nil;
    _addrView = nil;
    _lineView = nil;
    _roundImgView = nil;
    _pinImgView = nil;
    _cachedMediaView = nil;

    [super clearCachedMediaViews];
}


#pragma mark - Setters

- (void)setImage:(UIImage *)image
{
    _image = [image copy];
    _cachedMediaView = nil;
}

- (void)setAppliesMediaViewMaskAsOutgoing:(BOOL)appliesMediaViewMaskAsOutgoing
{
    [super setAppliesMediaViewMaskAsOutgoing:appliesMediaViewMaskAsOutgoing];
    _cachedMediaView = nil;
}


#pragma mark - JSQMessageMediaData protocol

- (CGSize)mediaViewDisplaySize
{
//    return CGSizeMake(240.0f, 105.0f);
    return CGSizeMake(kLocationIconWidth + LocationMediaItemImgInsets.left + LocationMediaItemImgInsets.right, 158.0f);
}

- (UIView *)mediaView
{
    if (self.locationMeta != nil && self.cachedMediaView == nil)
    {
        BOOL isOutgoing = self.appliesMediaViewMaskAsOutgoing;

        // create container view for the various controls
        CGSize mainSize = [self mediaViewDisplaySize];
        UIView * playView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, mainSize.width, mainSize.height)];
        playView.backgroundColor = [UIColor clearColor];
        playView.contentMode = UIViewContentModeCenter;
        playView.clipsToBounds = YES;
        playView.userInteractionEnabled = NO;
        // 添加消息气泡点击事件处理
//        [playView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onViewFileContent:)]];

        //# 气泡背景底图
        UIImageView *bubbleImageBgView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, mainSize.width, mainSize.height)];
        bubbleImageBgView.contentMode = UIViewContentModeScaleToFill;
        bubbleImageBgView.userInteractionEnabled = NO;
        JSQMessagesBubbleImageFactory *bubbleImageFactory = [[JSQMessagesBubbleImageFactory alloc] init];
        JSQMessagesBubbleImage *bubbleImageData =(isOutgoing?[bubbleImageFactory outgoingMessagesBubbleImage_wechatGreen]:[bubbleImageFactory incomingMessagesBubbleImage]);
        bubbleImageBgView.image = bubbleImageData.messageBubbleImage;
        bubbleImageBgView.highlightedImage = bubbleImageData.messageBubbleHighlightedImage;
        [playView addSubview:bubbleImageBgView];
        
        CGFloat leftInset, rightInset, topInset, bottomInset;
        if (isOutgoing) {
            leftInset = LocationMediaItemControlInsets.right;
            rightInset = LocationMediaItemControlInsets.left;
        } else {
            leftInset = LocationMediaItemControlInsets.left;
            rightInset = LocationMediaItemControlInsets.right;
        }
        topInset = LocationMediaItemControlInsets.top;
        bottomInset = LocationMediaItemControlInsets.bottom;
        
        CGFloat imgLeftInset, imgRightInset, imgBottomInset;
        if (isOutgoing) {
            imgLeftInset = LocationMediaItemImgInsets.right;//+0.5;// 0.5是个硬偏移量，因为ui上总差那么一点点，所以就硬编码调整一下
            imgRightInset = LocationMediaItemImgInsets.left;
        } else {
            imgLeftInset = LocationMediaItemImgInsets.left;
            imgRightInset = LocationMediaItemImgInsets.right;
        }
        imgBottomInset = LocationMediaItemImgInsets.bottom;
        
        //# 预览图组件
        CGSize imgSize = CGSizeMake(kLocationIconWidth, kLocationIconHeight);
        CGRect imgFrame = CGRectMake(imgLeftInset, mainSize.height - kLocationIconHeight - imgBottomInset, imgSize.width, imgSize.height);
        self.previewImgView = [[UIImageView alloc] initWithFrame:imgFrame];
        self.previewImgView.contentMode = UIViewContentModeScaleAspectFill;
        self.previewImgView.clipsToBounds = YES;
        // 绘制图片圆角（左下和右下圆角）
        [BasicTool roundView:self.previewImgView byRoundingCorners:(UIRectCornerBottomLeft | UIRectCornerBottomRight) cornerRadii:CGSizeMake(11.0, 11.0)];
//        UIBezierPath *maskPath = [UIBezierPath bezierPathWithRoundedRect:self.previewImgView.bounds
//                                             byRoundingCorners:(UIRectCornerBottomLeft | UIRectCornerBottomRight)
//                                                   cornerRadii:CGSizeMake(12.0, 12.0)];
//        CAShapeLayer *maskLayer = [[CAShapeLayer alloc] init];
//        maskLayer.path = maskPath.CGPath;
//        self.previewImgView.layer.mask = maskLayer;
        [playView addSubview:self.previewImgView];
        
        //# 装饰UI - 横线
        CGSize lineSize = CGSizeMake(imgSize.width, 0.5f);
        CGRect lineFrame = CGRectMake(CGRectGetMinX(imgFrame), CGRectGetMinY(imgFrame), lineSize.width, lineSize.height);
        self.lineView = [[UIView alloc] initWithFrame:lineFrame];
        self.lineView.backgroundColor = HexColor(0xe8eaee);
        [playView addSubview:self.lineView];
        
        //# 装饰UI - 底部圆角
        CGSize roundImgSize = CGSizeMake(imgSize.width, 8);
        CGRect roundImgFrame = CGRectMake(CGRectGetMinX(imgFrame), CGRectGetMaxY(imgFrame) - roundImgSize.height, imgSize.width, roundImgSize.height);
        self.roundImgView = [[UIImageView alloc] initWithFrame:roundImgFrame];
        self.roundImgView.contentMode = UIViewContentModeScaleToFill;
        self.roundImgView.image = [UIImage imageNamed:@"chatting_location_msg_ballon_bottom_round"];
        [BasicTool setStretchImage:self.roundImgView capInsets:UIEdgeInsetsMake(0, 5, 5, 5) img:self.roundImgView.image];
        [playView addSubview:self.roundImgView];
        
        //# 装饰UI - 大头针
        CGSize pinImgSize = CGSizeMake(17, 33);
        CGRect pinImgFrame = CGRectMake(imgLeftInset + kLocationIconWidth/2 - pinImgSize.width/2, CGRectGetMinY(imgFrame) + kLocationIconHeight/2 - pinImgSize.height, pinImgSize.width, pinImgSize.height);
        self.pinImgView = [[UIImageView alloc] initWithFrame:pinImgFrame];
        self.pinImgView.contentMode = UIViewContentModeScaleToFill;
        self.pinImgView.image = [UIImage imageNamed:@"chatting_location_current_pin_medium_icon"];
        [playView addSubview:self.pinImgView];
        
        //# 标题显示组件
        CGSize fileNameSize = CGSizeMake(mainSize.width - rightInset - leftInset, 16);
        CGRect fileNameFrame = CGRectMake(leftInset, topInset, fileNameSize.width, fileNameSize.height);
        self.titleView = [[UILabel alloc] initWithFrame:fileNameFrame];
        self.titleView.textAlignment = NSTextAlignmentLeft;
        self.titleView.lineBreakMode = NSLineBreakByTruncatingMiddle;
        self.titleView.textColor = HexColor(0x2c2f36);
        self.titleView.font = [UIFont systemFontOfSize:15];
        [playView addSubview:self.titleView];
        
        //# 地址显示组件
        CGSize fileSizeSize = CGSizeMake(mainSize.width - rightInset - leftInset, 12);
        CGRect fileSizeFrame = CGRectMake(leftInset, CGRectGetMaxY(fileNameFrame) + 4 , fileSizeSize.width, fileSizeSize.height);
        self.addrView = [[UILabel alloc] initWithFrame:fileSizeFrame];
        self.addrView.textAlignment = NSTextAlignmentLeft;
        //            self.progressLabel.adjustsFontSizeToFitWidth = YES;
        self.addrView.lineBreakMode = NSLineBreakByTruncatingMiddle;
        self.addrView.textColor = HexColor(0x979ca6);
        self.addrView.font = [UIFont systemFontOfSize:12];
        [playView addSubview:self.addrView];
        
        //# 数据显示
        NSString *title = [LocationUtils getPOIItemName:self.locationMeta.locationTitle];
        NSString *addr = [LocationUtils getPOIItemAddr:self.locationMeta.locationContent lng:self.locationMeta.longitude lat:self.locationMeta.latitude];
        self.titleView.text = title;
        self.addrView.text = addr;
        self.previewImgView.image = (self.image != nil? self.image : [UIImage imageNamed:@"chatting_location_preview_default"]);
        
        self.cachedMediaView = playView;
    }
    
    return self.cachedMediaView;
}

- (NSUInteger)mediaHash
{
    return self.hash;
}

- (NSUInteger)hash
{
    return super.hash;// ^ self.audioData.hash;
}

@end
