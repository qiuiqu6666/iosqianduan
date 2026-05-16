//
//  CallViewController.h
//  RainbowChat4i
//
//  音视频通话UI界面。
//  支持呼出、来电、通话中 三种状态的UI展示和用户交互。
//

#import <UIKit/UIKit.h>
#import "CallManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface CallViewController : UIViewController

/// 通话类型
@property (nonatomic, assign) CallType callType;

/// 对方UID
@property (nonatomic, copy) NSString *remoteUserUid;

/// 对方昵称
@property (nonatomic, copy) NSString *remoteUserNickname;

/// 是否是主叫方（YES=呼出，NO=来电）
@property (nonatomic, assign) BOOL isCaller;

/// 是否从浮窗恢复（YES时跳过铃声播放等初始化逻辑）
@property (nonatomic, assign) BOOL isRestoringFromFloat;

/// 初始化方法
- (instancetype)initWithCallType:(CallType)callType
                   remoteUserUid:(NSString *)remoteUserUid
              remoteUserNickname:(NSString *)remoteUserNickname
                        isCaller:(BOOL)isCaller;

@end

NS_ASSUME_NONNULL_END
