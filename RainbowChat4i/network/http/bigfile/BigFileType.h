//telegram @wz662
//
//  BigFileType.h
//  RainbowChat4i
//
//  Created by Jack Jiang on 2019/10/4.
//  Copyright © 2019 JackJiang. All rights reserved.
//

#import <Foundation/Foundation.h>

#ifndef BigFileType_h
#define BigFileType_h

/**
 * 大文件类型。
 * <p>
 * 本常量表中的常量定义，与数据库表“大文件资源表/missu_big_files”中
 * 的字段“res_type”字段中的常量定义保持严格一！
 *
 * @since 2.1
*/
typedef NS_ENUM(NSInteger, BigFileType){
    /** 大文件类型：普通大文件 */
    BigFileType_COMMON_BIG_FILE = 0,
    /**
     * 大文件类型：短视频文件。
     * 按照微信、易信、RainbowChat中的压缩率，10秒短视频约为1.3MB至4MB左右，对于移动弱网络来说，这也算是大文件了）。
     */
    BigFileType_SHORT_VIDEO     = 1,
};



#endif /* BigFileType_h */
