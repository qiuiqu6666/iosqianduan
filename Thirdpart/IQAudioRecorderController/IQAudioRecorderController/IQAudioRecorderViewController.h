//telegram @wz662

#import <UIKit/UIKit.h>
#import <CoreAudio/CoreAudioTypes.h>
#import <AVFoundation/AVAudioSettings.h>
@class IQAudioRecorderViewController;


typedef NS_ENUM(NSUInteger, IQAudioFormat) {
    IQAudioFormatDefault,  //   kAudioFormatMPEG4AAC    .m4a
    IQAudioFormat_m4a       = kAudioFormatMPEG4AAC,  //.m4a
    IQAudioFormat_caf       = kAudioFormatLinearPCM,  //.caf
};

typedef NS_ENUM(NSUInteger, IQAudioQuality) {
    IQAudioQualityDefault   = -1,
    IQAudioQualityMin       = AVAudioQualityMin,
    IQAudioQualityLow       = AVAudioQualityLow,
    IQAudioQualityMedium    = AVAudioQualityMedium,
    IQAudioQualityHigh      = AVAudioQualityHigh,
    IQAudioQualityMax       = AVAudioQualityMax,
};


@protocol IQAudioRecorderViewControllerDelegate <NSObject>

@required
/**
 Returns the temporary recorded filePath, you need to copy the recorded file to your own location and don't rely on the filePath anymore. You need to dismiss controller yourself.
 */
-(void)audioRecorderController:(nonnull IQAudioRecorderViewController*)controller didFinishWithAudioAtPath:(nonnull NSString*)filePath;

@optional
/**
 Optional method to determine if user taps on Cancel button. If you implement this delegate then you need to dismiss controller yourself.
 */
-(void)audioRecorderControllerDidCancel:(nonnull IQAudioRecorderViewController*)controller;

@end



@interface IQAudioRecorderViewController : UIViewController

/**
 Title to show on navigationBar
 */
@property(nullable, nonatomic,copy) NSString *title;

/** 发送按钮上的文字颜色 */
@property(nullable, nonatomic,copy) UIColor *sendButtonTextColor;
/** 发送按钮上的文字 */
@property(nullable, nonatomic,copy) NSString *sendButtonText;
/** 取消按钮上的文字 */
@property(nullable, nonatomic,copy) NSString *cancelButtonText;
/** 发送按钮的背景图（就是那个大圆形按钮图）*/
@property(nullable, nonatomic,copy) UIImage *sendButtonImage;
/** 发送按钮的背景图按下效果（就是那个大圆形按钮图）*/
@property(nullable, nonatomic,copy) UIImage *sendButtonImageHighlight;


///--------------------------
/// @name Delegate callback
///--------------------------

/**
 IQAudioRecorderController delegate.
 */
@property(nullable, nonatomic, weak) id<IQAudioRecorderViewControllerDelegate> delegate;


///--------------------------
/// @name Audio Settings
///--------------------------

/**
 Maximum duration of the audio file to be recorded.
 */
@property(nonatomic) NSTimeInterval maximumRecordDuration;

/**
 Audio format. default is IQAudioFormat_m4a.
 */
@property(nonatomic,assign) IQAudioFormat audioFormat;

/**
 sampleRate should be floating point in Hertz.
 */
@property(nonatomic,assign) CGFloat sampleRate;

/**
 Number of channels.
 */
@property(nonatomic,assign) NSInteger numberOfChannels;

/**
 Audio quality.
 */
@property(nonatomic,assign) IQAudioQuality audioQuality;

/**
 bitRate.
 */
@property(nonatomic,assign) NSInteger bitRate;

//@end
//
//
//@interface UIViewController (IQAudioRecorderViewController)


///--------------------------
/// @name 其它实用方法
///--------------------------

/**
 amr转换方法（将本类中录制的原始音频，转换成amr格式并存到指定路径处）。

 @param originalAudioFilePath 本类中录制的原始音频文件绝对路径
 @param destAMRFileDir 转换成amr格式后存放到的目标绝对路径
 @return 返回转换成功后最终的amr存放路径
 */
+ (NSString *)convertCAFtoAMR:(NSString *)originalAudioFilePath toDir:(NSString *)destAMRFileDir;

//- (void)presentAudioRecorderViewControllerAnimated:(nonnull IQAudioRecorderViewController *)audioRecorderViewController;
//- (void)presentBlurredAudioRecorderViewControllerAnimated:(nonnull IQAudioRecorderViewController *)audioRecorderViewController;

/**
 进入语音录制界面。

 @param parent 语音录制界面打开时依赖的父界面
 @param delegate 语音留制结果delegate实现对象
 @param maxDuration 允许的最长录制时间，本参数为<=0的值表示不限制
 @param sendButtonText 确认按钮上的文字，本参数为nil将使用默认文字
 @param cancelButtonText 取消按钮上的文字，本参数为nil将使用默认文字
 @param sendButtonImage 发送按钮的背景图（就是那个大圆形按钮图），本参数为nil将使用默认的红色背景图
 @param sendButtonImageHighlight 发送按钮的背景图按下效果（就是那个大圆形按钮图），本参数为nil将使用默认的红色背景图
 @param sendButtonTextColor 确认按钮上的文字颜色，本参数为nil将使用默认文字颜色——白色
 */
+ (void)presentBlurredAudioRecorderViewControllerAnimated2:(UIViewController *)parent delegate:(id<IQAudioRecorderViewControllerDelegate>)delegate maxDuration:(NSTimeInterval)maxDuration sendButtonText:(NSString *)sendButtonText cancelButtonText:(NSString *)cancelButtonText sendButtonImage:(UIImage *)sendButtonImage sendButtonImageHighlight:(UIImage *)sendButtonImageHighlight sendButtonTextColor:(UIColor *)sendButtonTextColor;

@end
