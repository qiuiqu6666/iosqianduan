//telegram @wz662
#import <Foundation/Foundation.h>
#import "VoieceDownloadStatus.h"

@interface PhotosOrVoiecesDTO : NSObject

/** 资源id */
@property (nonatomic, retain) NSString *resource_id;
/** 上传者的uid */
@property (nonatomic, retain) NSString *user_uid;
/** 资源类型：“0”表示个人照片、“1”表示个人语音介绍 */
@property (nonatomic, retain) NSString *res_type;
/** 资源文件名 */
@property (nonatomic, retain) NSString *res_file_name;
/** 资源大小(人类可读) */
@property (nonatomic, retain) NSString *res_human_size;
/** 资源大小(单位:字节) */
@property (nonatomic, retain) NSString *res_size;
/** 被下载查看次数 */
@property (nonatomic, retain) NSString *view_count;
/** 上传时间 */
@property (nonatomic, retain) NSString *create_time;

/** 语音文件的下载进度（此属性仅用于个人语音介绍时） */
@property (nonatomic, retain) VoieceDownloadStatus *downloadStatus;

@end
