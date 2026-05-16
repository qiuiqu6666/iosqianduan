//telegram @wz662
/**
 * 收到的文件消息文件信息元数据.
 *
 * @author JackJiang
 * @since 4.3
 */

#import <Foundation/Foundation.h>

@interface FileMeta : NSObject

/** 文件名（收到的消息时） */
@property (nonatomic, retain) NSString *fileName;
/** 文件md5码 */
@property (nonatomic, retain) NSString *fileMd5;
/** 文件长度（单位：字节） */
@property (nonatomic, assign) long fileLength;

// 20191009日取消本字段：原因是RinbowChat支持跨少箱的文件发送，而每次启动app后，因ios的文件系统安全机制，引用的这些文件原沙箱路径都是会变动的，
// 所以本字段已无意义。另外：app自已的沙箱目录地址也是会在每次app重启后变动。总之，ios里的目录不应被持久化，否则原目录会因已变动而读取不到文件。
/** 文件绝对路径，含文件名 (对于收到的文件来说，在它还没下载完成前，这个路径指向的文件是不存在的哦) */
//@property (nonatomic, retain) NSString *filePath;

+ (id)initWith:(NSString *)fileName fileMd5:(NSString *)fileMd5 fileLength:(long long)fileLength;

+ (FileMeta *)fromJSON:(NSString *)jsonOfFileMeta;

@end
