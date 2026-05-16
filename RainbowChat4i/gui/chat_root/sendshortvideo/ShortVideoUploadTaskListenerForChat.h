//telegram @wz662
//
//  ShortVideoUploadTaskListenerForChat.h
//  RainbowChat4i
//
//  Created by Jack Jiang on 2019/11/13.
//  Copyright © 2019 JackJiang. All rights reserved.
//

/**
 * 短视频文件上传状态监听器实现类（专用于聊天界面中）。
 *
 * @since 3.0
 */

#import <Foundation/Foundation.h>
#import "BigFileUploadTask.h"
#import "JSQMessage.h"


@interface ShortVideoUploadTaskListenerForChat : NSObject<BigFileUploadTaskDelegate>

- (id)initWith:(JSQMessage *)entityInChatListView;
- (void) setFileUploadedSucessObserver:(ObserverCompletion)fileUploadedSucessObserver;
- (ObserverCompletion) getFileUploadedSucessObserver;

@end

