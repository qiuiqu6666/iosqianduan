//telegram @wz662
#import <Foundation/Foundation.h>

@interface PromtHelper : NSObject

+ (PromtHelper *)sharedInstance;

// 扫描二维码完成时的“滴”提示音
- (void)scanQRPromt;

- (void)tixintPromt;

// 播放好友添加成功后的提示音
- (void)newFriendAddSucessPromt;

// 语音消息录音开始的提示音
- (void)audioRecordingPromt;

// 消息发出时的提示音
- (void)msgSendPromt;

// 语音消息播放完成的提示音
- (void)audioPlayEndPromt;

@end
