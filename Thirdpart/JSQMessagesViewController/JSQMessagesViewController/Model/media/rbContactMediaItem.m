//telegram @wz662
//
//  rbContactMediaItem.m
//  RainbowChat4i
//
//  Created by Jack Jiang.
//  Copyright © 2020 JackJiang. All rights reserved.
//

#import "rbContactMediaItem.h"
#import "JSQMessagesBubbleImage.h"
#import "JSQMessagesBubbleImageFactory.h"
#import "FileDownloadHelper.h"


// 头像UIImageView的宽
#define kContactIconWidth    48//44
// 头像UIImageView的高
//#define kContactIconHeight   54
// 头像与文本信息间的间距
#define kContactIconGap      10//5

// （该衬距是以收到的消息的UI为基准的哦），衬距以收到的消息气泡为准（上、左、下、右）
const UIEdgeInsets ContactMediaItemControlInsets = {10, 20, 10, 12};//{10, 15, 10, 8};


@interface rbContactMediaItem ()
// 整个ui父容器View
@property (strong, nonatomic) UIView *cachedMediaView;
// 昵称显示组件
@property (strong, nonatomic) UILabel *nickNameView;
// 头像显示组件
@property (strong, nonatomic) UIImageView *avatarIconView;
// uid显示组件
@property (strong, nonatomic) UILabel *uidView;

// 底部装饰：横线
@property (strong, nonatomic) UIView *lineView;
// 底部装饰：“个人名片”文字
@property (strong, nonatomic) UILabel *descView;

// 名片消息元数据对象引用
@property (strong, nonatomic) ContactMeta *contactMeta;

@end


@implementation rbContactMediaItem

#pragma mark - Initialization

- (instancetype)initWithData:(ContactMeta *)contactMeta
{
    self = [super init];
    if (self) {
        _cachedMediaView = nil;
        _contactMeta = contactMeta;
    }
    return self;
}

- (void)dealloc
{
    _contactMeta = nil;
    _image = nil;

    [self clearCachedMediaViews];
}

- (void)clearCachedMediaViews
{
    _nickNameView = nil;
    _avatarIconView = nil;
    _uidView = nil;
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
    //return CGSizeMake(240.0f, 74.0f);
    return CGSizeMake(256.0f, 105.0f);
}

- (UIView *)mediaView
{
    if (self.contactMeta != nil && self.cachedMediaView == nil)
    {
        BOOL isOutgoing = self.appliesMediaViewMaskAsOutgoing;
        BOOL isUserContact = (self.contactMeta.type == CONTACT_TYPE_USER);

        // create container view for the various controls
        CGSize mainSize = [self mediaViewDisplaySize];
        UIView * playView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, mainSize.width, mainSize.height)];
        playView.backgroundColor = [UIColor clearColor];
        playView.contentMode = UIViewContentModeCenter;
        playView.clipsToBounds = YES;

        playView.userInteractionEnabled = NO;
        // 添加消息气泡点击事件处理
//      [playView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onViewFileContent:)]];

        // 气泡背景底图
        UIImageView *bubbleImageBgView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, mainSize.width, mainSize.height)];
        bubbleImageBgView.contentMode = UIViewContentModeScaleToFill;
        bubbleImageBgView.userInteractionEnabled = NO;
        // 与文本气泡一致：背景图 view 再做一次垂直翻转，保持尾巴位置完全对齐
        bubbleImageBgView.transform = CGAffineTransformMakeScale(1.0, -1.0);
        JSQMessagesBubbleImageFactory *bubbleImageFactory = [[JSQMessagesBubbleImageFactory alloc] init];
        JSQMessagesBubbleImage *bubbleImageData = (isOutgoing
                                                   ? [bubbleImageFactory outgoingMessagesBubbleImage_light]
                                                   : [bubbleImageFactory incomingMessagesBubbleImage_white]);
        bubbleImageBgView.image = bubbleImageData.messageBubbleImage;
        bubbleImageBgView.highlightedImage = bubbleImageData.messageBubbleHighlightedImage;
        [playView addSubview:bubbleImageBgView];
        
        CGFloat leftInset, rightInset, topInset, bottomInset;
        if (isOutgoing) {
            leftInset = ContactMediaItemControlInsets.right;
            rightInset = ContactMediaItemControlInsets.left;
        } else {
            leftInset = ContactMediaItemControlInsets.left;
            rightInset = ContactMediaItemControlInsets.right;
        }
        topInset = ContactMediaItemControlInsets.top;
        bottomInset = ContactMediaItemControlInsets.bottom;
        
        // 头像组件
        self.avatarIconView = [[UIImageView alloc] initWithFrame:CGRectMake(leftInset
                                                                            // 4是个硬编码量
                                                                          , topInset + 4//(mainSize.height - kContactIconWidth)/2
                                                                          , kContactIconWidth
                                                                          , kContactIconWidth)];
        // 图片圆角
        self.avatarIconView.layer.cornerRadius = kContactIconWidth/2;
        self.avatarIconView.layer.masksToBounds = YES;
        [playView addSubview:self.avatarIconView];
        
        // 昵称显示组件
        CGSize fileNameSize = CGSizeMake(mainSize.width - kContactIconWidth - rightInset - leftInset - kContactIconGap, 16);
        CGRect fileNameFrame = CGRectMake(leftInset + kContactIconWidth + kContactIconGap
                                          , topInset + 10
                                          , fileNameSize.width
                                          , fileNameSize.height);
        self.nickNameView = [[UILabel alloc] initWithFrame:fileNameFrame];
        self.nickNameView.textAlignment = NSTextAlignmentLeft;
        self.nickNameView.lineBreakMode = NSLineBreakByTruncatingMiddle;
        self.nickNameView.textColor = HexColor(0x212121);
        self.nickNameView.font = [UIFont systemFontOfSize:15];
        [playView addSubview:self.nickNameView];
        
        // uid显示组件
        CGSize fileSizeSize = CGSizeMake(mainSize.width - kContactIconWidth - rightInset - leftInset - kContactIconGap, 13);
        CGRect fileSizeFrame = CGRectMake(leftInset + kContactIconWidth + kContactIconGap
                                          , CGRectGetMaxY(fileNameFrame) + 10
                                          , fileSizeSize.width
                                          , fileSizeSize.height);
        self.uidView = [[UILabel alloc] initWithFrame:fileSizeFrame];
        self.uidView.textAlignment = NSTextAlignmentLeft;
//      self.progressLabel.adjustsFontSizeToFitWidth = YES;
        self.uidView.lineBreakMode = NSLineBreakByTruncatingMiddle;
        self.uidView.textColor = HexColor(0x999b9f);// 0x4e94ff
        self.uidView.font = [UIFont systemFontOfSize:13];
        [playView addSubview:self.uidView];
        
        // 底部装饰UI - “个人名片”文字
        CGSize descSize = CGSizeMake(mainSize.width - rightInset - leftInset, 13);// 13是个硬编码量
        CGRect descFrame = CGRectMake(leftInset
                                          , mainSize.height - bottomInset - descSize.height
                                          , descSize.width
                                          , descSize.height);
        self.descView = [[UILabel alloc] initWithFrame:descFrame];
        self.descView.textAlignment = NSTextAlignmentLeft;
        self.descView.lineBreakMode = NSLineBreakByTruncatingMiddle;
        self.descView.textColor = HexColor(0x979ca6);
        self.descView.font = [UIFont systemFontOfSize:11];
        self.descView.text = (isUserContact ? @"个人名片":@"群名片");
        [playView addSubview:self.descView];
        
        
        
        // 底部装饰UI - 横线
        CGSize lineSize = CGSizeMake(mainSize.width - rightInset - leftInset, 0.5f);
        CGRect lineFrame = CGRectMake(leftInset
                                          , CGRectGetMinY(descFrame) - 8 // 8是个硬偏移量
                                          , lineSize.width
                                          , lineSize.height);
        self.lineView = [[UIView alloc] initWithFrame:lineFrame];
        self.lineView.backgroundColor = HexColor(0xe8eaee);
        [playView addSubview:self.lineView];
        
        // 数据显示
        NSString *nickName = self.contactMeta.nickName;
        NSString *uid = self.contactMeta.uid;
        self.avatarIconView.image = (self.image != nil? self.image : [UIImage imageNamed:(isUserContact ? @"chat_avatar_default" : @"groupchat_groups_icon_default")]);
        self.nickNameView.text = nickName;
        // 显示额外信息
        if(self.contactMeta.desc != nil){
            self.uidView.text = self.contactMeta.desc;
        }
        // else是为了兼容老版本，因为老版本没有desc字段
        else {
            self.uidView.text = [NSString stringWithFormat:(isUserContact?@"UID: %@":@"群ID: %@"), uid];
        }
        
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
    return super.hash;
}

@end
