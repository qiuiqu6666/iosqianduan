//
//  CallIncomingPopupManager.h
//  RainbowChat4i
//
//  来电顶部卡片弹窗（前台时的快捷接听 UI）。
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "CallManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface CallIncomingPopupManager : NSObject <CallManagerDelegate, UIGestureRecognizerDelegate>

+ (instancetype)sharedInstance;

/// 显示来电顶部卡片。
- (void)showWithCallType:(CallType)callType
           remoteUserUid:(NSString *)remoteUserUid
      remoteUserNickname:(NSString *)remoteUserNickname;

/// 隐藏来电顶部卡片。
- (void)hide;

@end

NS_ASSUME_NONNULL_END

