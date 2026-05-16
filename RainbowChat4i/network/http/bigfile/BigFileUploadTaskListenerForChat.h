//telegram @wz662
/**
 * 大文件上传状态监听器实现类（专用于聊天界面中）。
 *
 * @since 2.1
 */

#import <Foundation/Foundation.h>
#import "BigFileUploadTask.h"
#import "JSQMessage.h"

@interface BigFileUploadTaskListenerForChat : NSObject<BigFileUploadTaskDelegate>

- (id)initWith:(JSQMessage *)entityInChatListView;
- (void) setFileUploadedSucessObserver:(ObserverCompletion)fileUploadedSucessObserver;
- (ObserverCompletion) getFileUploadedSucessObserver;

@end

