//telegram @wz662
//
//  ShortVideoRecordViewController.h
//  AVFoundationTest
//
//  Created by Jack Jiang on 2019/10/19.
//  Copyright © 2019 wqb. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface ShortVideoRecordViewController : UIViewController

/** 录制视频容器 */
@property (weak, nonatomic) IBOutlet UIView *viewVideoContainer;
/** 对焦图标 */
@property (weak, nonatomic) IBOutlet UIImageView *imgFocusCursor;
/** REC图标 */
@property (weak, nonatomic) IBOutlet UIImageView *imgRecording;
/** 录制视频时长标签 */
@property (weak, nonatomic) IBOutlet UILabel *lbRecordTime;
/** 摄像头切换按钮 */
@property (weak, nonatomic) IBOutlet UIButton *btnCameraSwitch;
/** 开始/结束录制按钮 */
@property (weak, nonatomic) IBOutlet UIButton *btnRecordControl;

@property (weak, nonatomic) IBOutlet UIButton *btnClose;

/** 底部操作按钮组件父view的高度约束（当运行于刘海屏iPhone时，要加上safeArea的高度，这样就能让底部操作区的背景充满整个底部，好看一点）  */
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *bottomContainerHeightConstraint;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil withSaveDir:(NSString *)saveDir;

@end


@interface ShortVideoRecordedDTO : NSObject

/** 录制完成的短视频的保存路径（绝对路径） */
@property (nonatomic, retain) NSString *savedPath;
/** 录制完成的短视频的时长（单位：秒） */
@property (nonatomic, assign) int duration;
/** 此视频是否是以最长录制时间完成的 */
@property (nonatomic, assign) BOOL reachedMaxRecordTime;

@end

