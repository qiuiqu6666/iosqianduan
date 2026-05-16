//telegram @wz662
//
//  rbFileMediaItem.m
//  RainbowChat4i
//
//  Created by JackJiang.
//  Copyright © 2018年 JackJiang. All rights reserved.
//

#import "rbFileMediaItem.h"
#import "JSQMessagesBubbleImage.h"
#import "JSQMessagesBubbleImageFactory.h"
#import "BigFileViewerController.h"
#import "FileTool.h"
#import "ViewControllerFactory.h"


// 文件类型图标UIImageView的宽
#define kFileIconWidth    45//44
// 文件类型图标UIImageView的高
#define kFileIconHeight   45//54
// 文件图标与文本信息间的间距
#define kFileIconGap      5

// （该衬距是以收到的消息的UI为基准的哦）
//const UIEdgeInsets FileMediaItemControlInsets = {10, 15, 10, 8};// 衬距，以收到的消息气泡为准（上、左、下、右）
const UIEdgeInsets FileMediaItemControlInsets = {15, 17, 15, 13};// 衬距，以收到的消息气泡为准（上、左、下、右）


@interface rbFileMediaItem ()
// 整个ui父容器View
@property (strong, nonatomic) UIView *cachedMediaView;
// 文件名显示组件
@property (strong, nonatomic) UILabel *fileNameView;
// 文件类型图标显示组件
@property (strong, nonatomic) UIImageView *fileIconView;
// 文件大小显示组件
@property (strong, nonatomic) UILabel *fileSizeView;

// 文件消息元数据对象引用
@property (strong, nonatomic) FileMeta *fileMeta;

// 大文件上传进度条（本组件仅用于发出的消息时）
@property (strong, nonatomic) UIProgressView *progressView;

@end


@implementation rbFileMediaItem

#pragma mark - Initialization

- (instancetype)initWithData:(FileMeta *)fileMeta
{
    self = [super init];
    if (self) {
        _cachedMediaView = nil;
        _fileMeta = fileMeta;
    }
    return self;
}

- (void)dealloc
{
    _fileMeta = nil;

    [self clearCachedMediaViews];
}

- (void)clearCachedMediaViews
{
    _fileNameView = nil;
    _fileIconView = nil;
    _fileSizeView = nil;
    _progressView = nil;
    _cachedMediaView = nil;

    [super clearCachedMediaViews];
}


#pragma mark - Setters

- (void)setAppliesMediaViewMaskAsOutgoing:(BOOL)appliesMediaViewMaskAsOutgoing
{
    [super setAppliesMediaViewMaskAsOutgoing:appliesMediaViewMaskAsOutgoing];
    _cachedMediaView = nil;
}


//#pragma mark - Private
//
//// 点击了消息气泡进入文件查看的事件处理
//- (void)onViewFileContent:(UIButton *)sender
//{
//    if(_fileMeta != nil)
//    {
////        NSString *s = [NSString stringWithFormat:@"点击了查看文件：%@",_fileMeta.fileName];
////        AlertInfo(s);
//
////        ViewControllerFactory goBigFileViewerController:(UINavigationController *) fileName:(NSString *) fileDir:(NSString *) fileMd5:(NSString *) fileLength:(long) canDownload:(BOOL)
//    }
//}


#pragma mark - JSQMessageMediaData protocol

- (CGSize)mediaViewDisplaySize
{
    //return CGSizeMake(250.0f, 74.0f);
    return CGSizeMake(256.0f, 84.0f);
}

- (UIView *)mediaView
{
    if (self.fileMeta != nil && self.cachedMediaView == nil)
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

        // 气泡背景底图
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
            leftInset = FileMediaItemControlInsets.right;
            rightInset = FileMediaItemControlInsets.left;
        } else {
            leftInset = FileMediaItemControlInsets.left;
            rightInset = FileMediaItemControlInsets.right;
        }
        topInset = FileMediaItemControlInsets.top;
        bottomInset = FileMediaItemControlInsets.bottom;
        
        // 文件图标组件
        self.fileIconView = [[UIImageView alloc] initWithFrame:CGRectMake(mainSize.width - kFileIconWidth - rightInset
                                                                          , (mainSize.height - kFileIconHeight)/2
                                                                          , kFileIconWidth
                                                                          , kFileIconHeight)];
        // 因图标AI素材不好修改圆角半径，所以只好在代码中处理了 @since v7.0
        self.fileIconView.layer.cornerRadius = 8;//5;
        self.fileIconView.layer.masksToBounds = YES;
        [playView addSubview:self.fileIconView];
        
        // 文件名显示组件
        CGSize fileNameSize = CGSizeMake(mainSize.width - kFileIconWidth - rightInset - leftInset - kFileIconGap, 15);
        CGRect fileNameFrame = CGRectMake(leftInset
                                          , topInset + 10
                                          , fileNameSize.width
                                          , fileNameSize.height);
        self.fileNameView = [[UILabel alloc] initWithFrame:fileNameFrame];
        self.fileNameView.textAlignment = NSTextAlignmentLeft;
        self.fileNameView.lineBreakMode = NSLineBreakByTruncatingMiddle;
        self.fileNameView.textColor = HexColor(0x212327);
        self.fileNameView.font = [UIFont systemFontOfSize:15];
        [playView addSubview:self.fileNameView];
        
        // 文件大小显示组件
        CGSize fileSizeSize = CGSizeMake(mainSize.width - kFileIconWidth - rightInset - leftInset - kFileIconGap, 13);
        CGRect fileSizeFrame = CGRectMake(leftInset
                                          , CGRectGetMaxY(fileNameFrame) + 10
                                          , fileSizeSize.width
                                          , fileSizeSize.height);
        self.fileSizeView = [[UILabel alloc] initWithFrame:fileSizeFrame];
        self.fileSizeView.textAlignment = NSTextAlignmentLeft;
        //            self.progressLabel.adjustsFontSizeToFitWidth = YES;
        self.fileSizeView.lineBreakMode = NSLineBreakByTruncatingMiddle;
        self.fileSizeView.textColor = HexColor(0x999b9f);// 0x4e94ff
        self.fileSizeView.font = [UIFont systemFontOfSize:13];
        [playView addSubview:self.fileSizeView];
        
        // 数据显示
        NSString *fileName = self.fileMeta.fileName;
//      NSString *fileMd5 = self.fileMeta.fileMd5;
        long fileLength = self.fileMeta.fileLength;
        self.fileIconView.image = [BigFileViewerController getFileIconByExtention:self.fileMeta.fileName bigImage:NO];//YES
        self.fileNameView.text = fileName;
        self.fileSizeView.text = [FileTool getConvenientFileSize:fileLength];
        
        if(isOutgoing)
        {
            self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
            self.progressView.frame = CGRectMake(leftInset, mainSize.height - 12,
                                                 mainSize.width - leftInset - rightInset, self.progressView.frame.size.height);
            self.progressView.tintColor = UI_DEFAULT_BIGFILE_PROGRESS_FORGROUND_LIGHT_GREEN_COLOR;//UI_DEFAULT_BIGFILE_PROGRESS_FORGROUND_LIGHT_GREEN_COLOR;//[UIColor jsq_messageBubbleBlueColor];
            self.progressView.hidden = YES;// 默认是不可见的
            
            self.progressView.progress = 0.0f;
            
            [playView addSubview:self.progressView];
        }
        
        self.cachedMediaView = playView;
    }
    
    return self.cachedMediaView;
}

- (void)refreshUploadProgress:(SendStatusSecondary)sendStatusSecondary sendStatusSecondaryProgress:(int)progress
{
//    NSLog(@">>>>>>>>>>>>>>>>>>>>> 正在调用refreshUploadProgress，sendStatusSecondary=%ld、progress=%d", (long)sendStatusSecondary, progress);
    
    float progress_f = progress * 0.01f;
    
    switch(sendStatusSecondary)
    {
        case SendStatusSecondary_PROCESS_OK:
            self.progressView.progress = progress_f;
        case SendStatusSecondary_NONE:
        {
            // 关闭上传进度提示ui
            self.progressView.hidden = YES;
            self.progressView.progress = 0.0f;
            break;
        }
        // 如果是“等待处理“状态下的消息则意味着接下来需要：先上传到服务端、再发送消息给好友
        case SendStatusSecondary_PENDING:
        {
            // 显示上传进度提示ui
            self.progressView.hidden = NO;
            break;
        }
        case SendStatusSecondary_PROCESSING:
        {
            // 显示上传进度提示ui
            self.progressView.hidden = NO;
            self.progressView.progress = progress_f;
            break;
        }
        case SendStatusSecondary_PROCESS_FAILD:
        {
            // 关闭上传进度提示ui
            self.progressView.hidden = YES;
            break;
        }
    }
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
