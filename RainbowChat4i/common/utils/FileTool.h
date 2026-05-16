//telegram @wz662
#import <Foundation/Foundation.h>

@interface FileTool : NSObject

// 获得指定文件路径或文件名的不包含扩展名的文件名
+ (NSString *)getFileNameWithoutExt:(NSString *)filePath;

/// 从指定沙箱路径处，读取视频文件的第一帧图片。
///
/// @param fileFullPath 视频文件的完整沙箱路径
+ (UIImage*) getVideoPreViewImageFromPath:(NSString *)fileFullPath;

/// 从指定NSURL处，读取视频文件的第一帧图片。
///
/// @param pathURL 视频文件的URL路径
+ (UIImage*) getVideoPreViewImage:(NSURL *)pathURL;

///// 将UIImage对象保存为本地图片文件。
/////
///// @param img UIImage对象
///// @param destPath 要保存的沙箱完整文件路径
///// @param toPng YES表示将保存为PNG图片，否则保存为jpg图片
///// @param quality 当toPng=NO时，本参数表示jpg图片的保存质量（质量范围为：0.0~1.0，1.0表示最高质量）
//+ (BOOL)saveImageToFile:(UIImage *)img toPath:(NSString *)destPath saveToPng:(BOOL)toPng jpgCompressionQuality:(CGFloat)quality;

/**
 文件是否存在。

 @param filePath 文件绝对路径
 @return YES表示存在
 */
+ (BOOL)fileExists:(NSString *)filePath;

/**
 删除指定路径的文件。

 @param filePath 文件绝对路径
 @return YES表示删除成功
 */
+ (BOOL)removeFile:(NSString *)filePath;


/// 复制文件。
///
/// @param srcPath 源文件完整路径（含文件名）
/// @param destPath 要复制到的目地路径（含文件名）
/// @return YES表示复制成功，否则复制失败
/// @since 2.1
+ (BOOL) copyFile:(NSString *)srcPath destPath:(NSString *)destPath;

/**
 尝试创建目录（不存在则自动创建之，包括它的父目录）。

 @param dirPath 要创建的目录路径
 @return YES 表示创建成功，否则可能是出错了或者目录已经存在
 */
+ (BOOL)tryCreateDirs:(NSString *)dirPath;

/**
 * 获得文件大小的人类可读字符串形式.
 *
 * @param size 原文件大小，单位是byte(如表示该文件的长度是10240000)
 * @return 10240000字节的文件大小返回的字符串就是"10.00M"
 */
+ (NSString *)getConvenientFileSize:(long long)size;

+ (NSString*)getFileMD5WithPath:(NSString*)path;
+ (NSString*)getCachedPath;

/**
 *  单个文件的大小.
 *
 *  @param filePath 文件绝对路径
 *
 *  @return 如果文件存在则返回大小，否则返回0
 */
+ (long long) fileSizeAtPath:(NSString*) filePath;

+ (BOOL)renameFile:(NSString *)originalFilePath toFilePath:(NSString *)newFilePath;

/**
 从指定偏移处，读取指定长度的文件数据并返回。
 
 @param filePath 文件路径
 @param offset 读取起始偏移
 @param blockSize 读取的数据长度
 @since 2.1
 */
+ (NSData *) readBlockFromFile:(NSString *)filePath offset:(long long)offset blockSize:(long long)blockSize;

@end
