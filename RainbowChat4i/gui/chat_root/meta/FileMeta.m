//telegram @wz662
/**
 * 收到的文件消息文件信息元数据.
 *
 * @author JackJiang
 * @since 4.3
 */

#import "FileMeta.h"
#import "EVAToolKits.h"

@implementation FileMeta

- (id)init
{
    if(self = [super init])
    {
        // 属性初始化
        self.fileLength = 0;
    }
    return self;
}

+ (id)initWith:(NSString *)fileName fileMd5:(NSString *)fileMd5 fileLength:(long long)fileLength
{
    FileMeta * tm = [[FileMeta alloc] init];

    tm.fileName = fileName;
    tm.fileMd5 = fileMd5;
    tm.fileLength = fileLength;
//  tm.filePath = filePath;

    return tm;
}

+ (FileMeta *)fromJSON:(NSString *)jsonOfFileMeta
{
    return [EVAToolKits fromJSON:jsonOfFileMeta withClazz:[FileMeta class]];
}

@end
