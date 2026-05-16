//telegram @wz662

#import "JSQMediaItem.h"
#import <AVFoundation/AVFoundation.h>

@class JSQAudioMediaItem;

NS_ASSUME_NONNULL_BEGIN


/**
 *  The `JSQAudioMediaItem` class is a concrete `JSQMediaItem` subclass that implements the `JSQMessageMediaData` protocol
 *  and represents an audio media message. An initialized `JSQAudioMediaItem` object can be passed
 *  to a `JSQMediaMessage` object during its initialization to construct a valid media message object.
 *  You may wish to subclass `JSQAudioMediaItem` to provide additional functionality or behavior.
 */
@interface JSQAudioMediaItem : JSQMediaItem <AVAudioPlayerDelegate, NSCopying>//NSCoding

/**
 *  Not a valid initializer.
 */
- (id)init NS_UNAVAILABLE;

/**
 *  Initializes and returns an audio media item having the given audioData.
 *
 *  @param audioFileName 语音留文件名（存于本地缓存中或服务端的文件名）.
 *
 *  @return An initialized `JSQAudioMediaItem`.
 *
 *  @discussion If the audio must be downloaded from the network,
 *  you may initialize a `JSQAudioMediaItem` with a `nil` audioData.
 *  Once the audio is available you can set the `audioData` property.
 */
- (instancetype)initWithData:(nullable NSString *)audioFileName;

/**
 响应语音文件点击的事件处理完整逻辑。
 
 @since 9.0
 */
- (void)onPlayButton:(UIButton *)sender;

- (void)requestVoiceToText;

/**
 * 发出通知：接收其它MediaItem发过来的“停止播放”通知
 * > 在聊天界面处于当前界面时：用此通知来保证聊天界面中一次只有一个语音在播放；
 * > 在聊天界面马上要不可见时：如果存在正在播放中的语音消息，则通知其停止播放（不然在后台还会播放的罗）。
 */
+ (void)stopPlayRequestNotificatin_POST:(NSString *)itemHashForDebug;

@end

FOUNDATION_EXPORT NSString * const RBVoiceTranscriptDidUpdateNotification;

NS_ASSUME_NONNULL_END
