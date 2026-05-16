//
//  ChatRootViewController+Send.h
//  发送：文本/图片/语音/视频/文件/名片/位置/收藏等入口与处理。
//

#import "ChatRootViewController.h"

@class QuoteMeta;
@class ContactMeta;
@class LocationMeta;
@class JSQMessage;

NS_ASSUME_NONNULL_BEGIN

@interface ChatRootViewController (Send)

/// 软键盘发送按钮
- (void)didPressSendButtonInKeybord:(NSString *)text;
/// 左侧加号按钮
- (void)didPressLeftButton:(UIButton *)sender;
/// 根据输入框内容刷新右侧发送/语音图标
- (void)jsq_refreshRightBarButtonIcon;
/// 刷新左侧加号图标
- (void)jsq_refreshLeftBarButtonIcon;
/// 图片选择完成（相册/拍照/贴纸等）
- (void)processImagePickerComplete:(UIImage *)photo withTag:(NSString *)tag;
/// 图片发送实现（含转发/引用）
- (void)processImagePickerCompleteImpl:(NSString *)fileNameWillUpload toChatType:(int)chatType toId:(NSString *)toId toName:(NSString *)toName forForward:(BOOL)forForward withTag:(NSString *)tag;
- (void)processImagePickerCompleteImpl:(NSString *)fileNameWillUpload toChatType:(int)chatType toId:(NSString *)toId toName:(NSString *)toName forForward:(BOOL)forForward withTag:(NSString *)tag quoteMeta:(nullable QuoteMeta *)quoteMeta;

/// 主文件重发/转发等会调用
- (void)processVoiceMessageSend:(NSString *)fileNameWillUpload toChatType:(int)chatType toId:(NSString *)toId toName:(NSString *)toName forForward:(BOOL)forForward quoteMeta:(nullable QuoteMeta *)quoteMeta;
- (void)processBigFileMessageSend:(NSString *)filePath fileName:(NSString *)fileName md5:(NSString *)fileMD5 fileLength:(long long)fileLength toChatType:(int)chatType toId:(NSString *)toId toName:(NSString *)toName forForward:(BOOL)forForward quoteMeta:(nullable QuoteMeta *)quoteMeta;
- (void)processShortVideoMessageSend:(NSString *)videoSavedFilePath fileName:(NSString *)fileName md5:(NSString *)fileMD5 fileLength:(long long)fileLength toChatType:(int)chatType toId:(NSString *)toId toName:(NSString *)toName forForward:(BOOL)forForward quoteMeta:(nullable QuoteMeta *)quoteMeta;
- (void)processContactChooseCompleteImpl:(ContactMeta *)cm toChatType:(int)chatType toId:(NSString *)toId toName:(NSString *)toName;
- (void)processLocationChooseComplete:(LocationMeta *)selectedLocation toChatType:(int)chatType toId:(NSString *)toId toName:(NSString *)toName forForward:(BOOL)forForward quoteMeta:(nullable QuoteMeta *)quoteMeta;

@end

NS_ASSUME_NONNULL_END
