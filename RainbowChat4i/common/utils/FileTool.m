//telegram @wz662
#import "FileTool.h"
#import <AVFoundation/AVAsset.h>
#import <AVFoundation/AVAssetImageGenerator.h>
#import <AVFoundation/AVTime.h>

@implementation FileTool


// 获得指定文件路径或文件名的不包含扩展名的文件名
+ (NSString *)getFileNameWithoutExt:(NSString *)filePath
{
    //获得纯文件名，带后缀
    NSString *fileName  = [filePath lastPathComponent];            //例如：image.png
    //获得文件名，不带后缀
    NSString *fileNameNotExt = [fileName stringByDeletingPathExtension];//例如：image
//    //获得文件后缀
//    NSString *suffix    = [path pathExtension];                / /png
    return fileNameNotExt;
}

// 从指定沙箱路径处，读取视频文件的第一帧图片
+ (UIImage *) getVideoPreViewImageFromPath:(NSString *)fileFullPath
{
    NSURL *pathUrl = [[NSURL alloc] initFileURLWithPath:fileFullPath isDirectory:NO];
    return [FileTool getVideoPreViewImage:pathUrl];
}

// 从指定NSURL处，读取视频文件的第一帧图片
+ (UIImage *) getVideoPreViewImage:(NSURL *)pathURL
{
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:pathURL options:nil];
    AVAssetImageGenerator *assetGen = [[AVAssetImageGenerator alloc] initWithAsset:asset];
    assetGen.appliesPreferredTrackTransform = YES;
    
    CMTime time = CMTimeMakeWithSeconds(0.0, 600);
    NSError *error = nil;
    CMTime actualTime;
    UIImage *videoImage = nil;
    
    CGImageRef image = [assetGen copyCGImageAtTime:time actualTime:&actualTime error:&error];
    if(image != nil)
    {
        videoImage = [[UIImage alloc] initWithCGImage:image];
        CGImageRelease(image);
    }
    else
    {
        DDLogWarn(@"从路径%@中读取视频第一帧图片时出错了，原因是：%@", pathURL.path, error);
    }
    
    return videoImage;
}

//// 将UIImage对象保存为本地图片文件。
//+ (BOOL)saveImageToFile:(UIImage *)img toPath:(NSString *)destPath saveToPng:(BOOL)toPng jpgCompressionQuality:(CGFloat)quality
//{
//    if(img != nil)
//    {
//        NSData *imagedata = nil;
//        if(toPng)
//            // 保存为png格式
//            imagedata = UIImagePNGRepresentation(img);
//        else
//            // 保存为JEPG格式
//            imagedata = UIImageJPEGRepresentation(img, quality);
//
//        if(imagedata != nil)
//            return [imagedata writeToFile:destPath atomically:YES];
//    }
//
//    return NO;
//}

+ (BOOL)fileExists:(NSString *)filePath
{
    NSFileManager *fm=[NSFileManager defaultManager];
    return [fm fileExistsAtPath:filePath];
}

+ (BOOL)removeFile:(NSString *)filePath
{
    BOOL sucess = NO;

    NSFileManager *fm=[NSFileManager defaultManager];
    // 文件是否存在
    if([fm fileExistsAtPath:filePath])
    {
        NSError *error;
        sucess = [fm removeItemAtPath:filePath error:&error];
        if(error)
        {
            NSLog(@"[出错了] 删除文件 %@ 时出错了，错误信息：%@", filePath, error);
        }
    }
    return sucess;
}

// 创建目录（及其父目录）
+ (BOOL)tryCreateDirs:(NSString *)dirPath
{
    BOOL sucess = NO;

    NSFileManager *fileManager = [NSFileManager defaultManager];

    BOOL isDir = NO;
    // fileExistsAtPath 判断一个文件或目录是否有效，isDirectory判断是否一个目录
    BOOL existed = [fileManager fileExistsAtPath:dirPath isDirectory:&isDir];
    NSError *error;
    if ( !(isDir == YES && existed == YES) )
    {
        // 目录目录（如果中间目录不存在则也自动创建之）
        sucess = [fileManager createDirectoryAtPath:dirPath withIntermediateDirectories:YES attributes:nil error:&error];
        if(error)
        {
            NSLog(@"[出错了] 创建目录 %@ 时出错了，错误信息：%@", dirPath, error);
        }
    }

    NSLog(@"目录 %@ 创建成功了吗？%d", dirPath, sucess);

    return sucess;
}

// 获得文件大小的人类可读字符串形式
+ (NSString *)getConvenientFileSize:(long long)size// withScale:(int)scale
{
    NSString *ret = [NSString stringWithFormat:@"%lld字节",size];
    double temp= size/1024.0;
    if(temp>=1)
    {
        ret = [NSString stringWithFormat:@"%.2fKB", temp];
//        ret=roundEx(temp,scale)+"KB";
        temp=temp/1024.0;
        if(temp>=1)
        {
//            ret=roundEx(temp,scale)+"MB";
            ret = [NSString stringWithFormat:@"%.2fMB", temp];
            temp=temp/1024.0;
            if(temp>=1)
            {
//                ret=roundEx(temp,scale)+"GB";
                ret = [NSString stringWithFormat:@"%.2fGB", temp];
                temp=temp/1024.0;
                if(temp>=1)
                    ret = [NSString stringWithFormat:@"%.2fTB", temp];
            }
        }
    }

    return ret;
}

+(NSString*)getFileMD5WithPath:(NSString*)path
{
#define FileHashDefaultChunkSizeForReadingData 1024*8
    return (__bridge_transfer NSString *)FileMD5HashCreateWithPath((__bridge CFStringRef)path, FileHashDefaultChunkSizeForReadingData);
}

CFStringRef FileMD5HashCreateWithPath(CFStringRef filePath,size_t chunkSizeForReadingData)
{
    // Declare needed variables
    CFStringRef result = NULL;
    CFReadStreamRef readStream = NULL;
    // Get the file URL
    CFURLRef fileURL =
    CFURLCreateWithFileSystemPath(kCFAllocatorDefault,
                                  (CFStringRef)filePath,
                                  kCFURLPOSIXPathStyle,
                                  (Boolean)false);
    if (!fileURL) goto done;
    // Create and open the read stream
    readStream = CFReadStreamCreateWithFile(kCFAllocatorDefault,
                                            (CFURLRef)fileURL);
    if (!readStream) goto done;
    bool didSucceed = (bool)CFReadStreamOpen(readStream);
    if (!didSucceed) goto done;
    // Initialize the hash object
    CC_MD5_CTX hashObject;
    CC_MD5_Init(&hashObject);
    // Make sure chunkSizeForReadingData is valid
    if (!chunkSizeForReadingData) {
        chunkSizeForReadingData = FileHashDefaultChunkSizeForReadingData;
    }
    // Feed the data to the hash object
    bool hasMoreData = true;
    while (hasMoreData) {
        uint8_t buffer[chunkSizeForReadingData];
        CFIndex readBytesCount = CFReadStreamRead(readStream,(UInt8 *)buffer,(CFIndex)sizeof(buffer));
        if (readBytesCount == -1) break;
        if (readBytesCount == 0) {
            hasMoreData = false;
            continue;
        }
        CC_MD5_Update(&hashObject,(const void *)buffer,(CC_LONG)readBytesCount);
    }
    // Check if the read operation succeeded
    didSucceed = !hasMoreData;
    // Compute the hash digest
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5_Final(digest, &hashObject);
    // Abort if the read operation failed
    if (!didSucceed) goto done;
    // Compute the string result
    char hash[2 * sizeof(digest) + 1];
    for (size_t i = 0; i < sizeof(digest); ++i) {
        snprintf(hash + (2 * i), 3, "%02x", (int)(digest[i]));
    }
    result = CFStringCreateWithCString(kCFAllocatorDefault,(const char *)hash,kCFStringEncodingUTF8);

done:
    if (readStream) {
        CFReadStreamClose(readStream);
        CFRelease(readStream);
    }
    if (fileURL) {
        CFRelease(fileURL);
    }
    return result;
}

+ (NSString*)getCachedPath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return [paths objectAtIndex:0];
}

+ (long long) fileSizeAtPath:(NSString*) filePath
{
    NSFileManager* manager = [NSFileManager defaultManager];
    if ([manager fileExistsAtPath:filePath]){
        return [[manager attributesOfItemAtPath:filePath error:nil] fileSize];
    }
    return 0;
}

+ (BOOL)renameFile:(NSString *)originalFilePath toFilePath:(NSString *)newFilePath
{
    NSFileManager  *fileManager =[NSFileManager defaultManager];

    // 如果要重命名的文件已存在，则先尝试删除之（否则API的move是会报错的哦）
    if([fileManager fileExistsAtPath:newFilePath])
    {
        DDLogWarn(@"【重命名文件】要重命名的目标文件%@ 已存在，马上删除之。", newFilePath);

        if ([fileManager removeItemAtPath:newFilePath error:nil] != YES)
            DDLogWarn(@"【重命名文件】已存在的文件%@ 删除失改，依然继续下一步吧。。", newFilePath);
        else
            DDLogDebug(@"【重命名文件】已存在的文件%@ 已成功删除，继续下一步。。。", newFilePath);
    }

    NSError *moveError = nil;
    //将一个文件移动到另一个文件
    [fileManager moveItemAtPath:originalFilePath toPath:newFilePath error:&moveError];

    if(moveError != nil)
    {
        DDLogWarn(@"【重命名文件】重命名 %@ 为 %@ 时出错了，错误原因：%@", originalFilePath, newFilePath, moveError);
        return NO;
    }
    else
    {
        DDLogDebug(@"【重命名文件】重命名 %@ 为 %@ 成功完成！", originalFilePath, newFilePath);
        return YES;
    }
}

+ (BOOL) copyFile:(NSString *)srcPath destPath:(NSString *)destPath
{
    BOOL sucess = YES;
    
    NSFileManager  *fileManager =[NSFileManager defaultManager];
    NSError *error = nil;
    sucess = [fileManager copyItemAtPath:srcPath toPath:destPath error:&error];
    
    if(!sucess)
       DDLogWarn(@"【复制文件】将文件 %@ 复制到 %@ 时出错了，错误原因：%@", srcPath, destPath, error);
    
    return sucess;
}

+ (NSData *) readBlockFromFile:(NSString *)filePath offset:(long long)offset blockSize:(long long)blockSize
{
    @try
    {
        NSFileHandle *fileHandler = [NSFileHandle fileHandleForReadingAtPath:filePath];
        [fileHandler seekToFileOffset:offset];
        
        NSData *data = [fileHandler readDataOfLength:(NSInteger)blockSize];
        [fileHandler closeFile];
        
        return data;
    }
    @catch (NSException *exception)
    {
        DDLogError(@"读取文件[%@]的过程中发生了异常，Exception: %@", filePath, exception);
        return nil;
    }
}

@end
