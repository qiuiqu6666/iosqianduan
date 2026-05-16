//telegram @wz662
//
//  ShortVideoPlayViewController.h
//  AVFoundationTest
//
//  Created by Jack Jiang on 2019/10/19.
//  Copyright © 2019 wqb. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "HWVideoProgress.h"
#import "CommonViewController.h"


/*
 * 短视频来源常量定义.
 */
typedef NS_ENUM(NSUInteger, VideoDataType) {
    /** 视频文件来自本地文件 */
    VideoDataType_FILE_PATH = 0,
    /** 视频文件来自Http网络 */
    VideoDataType_URL       = 2,
};


/*
* 短视频播放完成时要调用的block定义.
*/
typedef void(^ShortVideoPlayCompletionBlock)(BOOL withError);



@interface ShortVideoPlayViewController : CommonViewController

#pragma mark - 视频播放器的UI组件

// 视频显示相关UI的顶层父组件
@property (weak, nonatomic) IBOutlet UIView *player_layoutVideoView;
// 视频预览图层
@property (weak, nonatomic) IBOutlet UIView *player_viewVideo;
// 播放/暂停按钮
@property (weak, nonatomic) IBOutlet UIButton *player_btnPlay;
// 播放进度
@property (weak, nonatomic) IBOutlet HWVideoProgress *player_progressPlaying;
// 视频当前播放时长
@property (weak, nonatomic) IBOutlet UILabel *player_lbCurrentVideoTime;
// 视频总时长
@property (weak, nonatomic) IBOutlet UILabel *player_lbTotalVideoTime;

@property (weak, nonatomic) IBOutlet UIButton *player_btnClose;


#pragma mark - 无视频或视频下载时的UI组件

@property (weak, nonatomic) IBOutlet UIView *noVideo_layoutOfNoVideo;
@property (weak, nonatomic) IBOutlet UIImageView *noVideo_viewIcon;
@property (weak, nonatomic) IBOutlet HWVideoProgress *noVideo_progressForDownload;
@property (weak, nonatomic) IBOutlet UILabel *noVideo_viewHint;


#pragma mark - 主类方法相关

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil duaration:(int)durationWithSecond videoDataType:(VideoDataType)videoDataType videoDataSrc:(NSString *)videoDataSrc savedDir:(NSString *)savedDir;

// 初始化方法（支持多个视频的左右滑动切换）
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil videoDataArray:(NSArray<NSDictionary *> *)videoDataArray currentIndex:(NSInteger)currentIndex savedDir:(NSString *)savedDir;

@end


#pragma mark - VideoPlayWrapper UI封装

@interface VideoPlayWrapper : NSObject

- (id)initWith:(UIView *)viewVideo btnPlay:(UIButton *)btnPlay progressPlaying:(HWVideoProgress *)progressPlaying lbCurrentVideoTime:(UILabel *)lbCurrentVideoTime lbTotalVideoTime:(UILabel *)lbTotalVideoTime videoDuration:(NSInteger)videoDuration withCompletion:(ShortVideoPlayCompletionBlock)playCompletetion;

- (void)initGUI;
- (void)initPlay:(NSString *)videoFilePath;

// 播放视频
- (void)doPlay;
// 恢复播放视频
- (void)doResume;
// 暂停播放视频
- (void)doPause;
// 停止播放视频
- (void)doStop;
// 是否正在播放中
- (BOOL)isPlaying;
// 移除相应的观察者和通知监听
- (void)removeObserversAndNotification;

/// 切换会话内另一条短视频前：拆掉当前 AVPlayer/Layer，并按新时长重建进度区 UI 与 seek 手势（不重复绑定点击播放）。
- (void)rb_resetPlayerShellAndSeekUIForNewDeclaredDuration:(NSInteger)seconds;

/// 列表左右滑切换须优先于横向快进 pan：pan 仅在 swipe 识别失败后生效。
- (void)rb_requirePlaylistSwipeGesturesToFailBeforeSeekPan:(NSArray<UISwipeGestureRecognizer *> *)swipes;

/// 横向快进所用 pan（宿主可设置 delegate，与纵向退出等手势分流）。
- (nullable UIPanGestureRecognizer *)rb_seekPanGestureRecognizer;

@end


#pragma mark - NoVideoWrapper UI封装

@interface NoVideoWrapper : NSObject

- (id)initWith:(UIView *)layoutVideoView layoutOfNoVideo:(UIView *)layoutOfNoVideo viewIcon:(UIImageView *)viewIcon progressForDownload:(HWVideoProgress *)progressForDownload viewHint:(UILabel *)viewHint;

- (NoVideoWrapper *)setVisible:(BOOL)visible;
- (NoVideoWrapper *)setVisible:(BOOL)visible progressVisible:(BOOL)progressVisible;
- (NoVideoWrapper *)setProgress:(CGFloat)progressOf1;
- (NoVideoWrapper *)setText:(NSString *)text;
- (NoVideoWrapper *)setIcon:(NSString *)imgName;

@end
