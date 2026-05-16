//telegram @wz662
//
//  RevokeCMDRecievedDTO.h
//  RainbowChat4i
//
//  Created by Jack Jiang on 2021/11/13.
//  Copyright © 2021 JackJiang. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * 本数据传输类目前仅用于撤回成功后，通过NotificationCenter通知给通知接收者时使用。
 *
 * @since 4.3
 * @author JackJiang
 */
@interface RevokeCMDRecievedDTO : NSObject

@property (nonatomic, retain) NSString *fpForRevokeCMD;
@property (nonatomic, retain) NSString *fpForRMessage;

@end
