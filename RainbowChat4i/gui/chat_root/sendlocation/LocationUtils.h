//telegram @wz662
#import <Foundation/Foundation.h>
#import <AMapSearchKit/AMapSearchKit.h>


// 定位超时时间，最低2s，此处设置为10s（增加超时时间以避免GPS信号弱时定位失败）
#define DefaultLocationTimeout  10
// 逆地理编码超时时间，最低2s，此处设置为5s
#define DefaultReGeocodeTimeout 5
// 地图默认缩放级别
#define DefaultZoomLevel        14

#define GV_BACK_MYSELF_LOCATION_IMG_BLACK @"chatting_location_gps_black"
#define GV_BACK_MYSELF_LOCATION_IMG_RED   @"chatting_location_gps_red"


@interface LocationUtils : NSObject

/**
 * 获得下载指定位置消息的预览图片2进制数据的完整http地址.
 * <p>
 * 形如：“http://192.168.0.190:8080/rainbowchat_pro/BinaryDownloader?action=location_d
 *      &user_uid=400007&file_name=ae48f32af4094439b513557824f2c04c.jpg”。
 *
 * @param file_name 要下载的图片文件名
 * @param needDump 是否需要转储：true表示需要转储，否则不需要. 转储是用于图片消息接收方在打开了该图片消息完整图后
 * 通知服务端将此图进行转储（转储的可能性有2种：直接删除掉、移到其它存储位置），转储的目的是防止大量用户的大量图片
 * 被读过后还存储在服务器上，加大了服务器的存储压力。<b>注意：</b><u>读取缩略图时无需转储！</u>
 * @return 完整的http文件下载地址
 */
+ (NSString *)getPreviewImageDownloadURL:(NSString *)file_name dump:(BOOL)needDump;

/**
 * 获得指定位置消息的预览图片的完整http地址（通过高德地图提供的静态地图服务实现）.
 * <p>
 * 形如：“https://restapi.amap.com/v3/staticmap?
 * location=120.546825,31.304756&zoom=14&scale=1&size=720*300&key=4fb238d0544f80f40fb3cd057d268a5f”。
 *
 * @return 完整的高德地图静态图片http地址
 */
+ (NSString *)getPreviewImageDownloadURL2:(double)longitude lat:(double)latitude;

// 位置预览图片文件上传
+ (void)uploadLocationPreviewFile:(NSString *)fileName completeFail:(void (^)(NSError *error))failure completeSucess:(void (^)(id responseObject))success;

/**
 * 保存位置预览图片到本地文件。
 *
 * @param bitmap 见 https://lbs.amap.com/api/ios-sdk/guide/interaction-with-map/map-screenshot
 * @param status state表示地图此时是否完整，0-不完整，1-完整
 * @param locationTitle 位置的描述，本参数可为空
 */
+ (void)saveMapScreenShot:(UIImage *)bitmap status:(NSInteger)status locationTitle:(NSString *)locationTitle fileSavedName:(NSString *)fileSavedName complete:(void (^)(BOOL sucess, NSString *imgFilePath))block;

// 返回地图预览截图的目录（结尾带反斜线）
+ (NSString *)getLocationPreviewFileSavedDirHasSlash;

// 返回地图预览截图的目录
+ (NSString *)getLocationPreviewFileSavedDir;

/**
 * 生成一个地图预览截图的文件名。
 *
 * 注：此截图理论上不可能发生重复，所以只需要保证文件名的唯一性，而无需像文件消息那样用文件数据的md5码来命名，
 * 所以目前为了简单起见，就直接用UUID就行了，但如果你觉得有必要用此图文件的md5码命名（实际无必要），自行修改即可。
 *
 * @return locationPreviewFileName
 */
+ (NSString *)generateLocationPreviewFileName;

+ (NSString *)getPOIItemName:(NSString *)name;

+ (NSString *)getPOIItemAddr:(NSString *)addr lng:(double)longitude lat:(double)latitude;

+ (AMapPOI *)changeToPoiItem:(AMapReGeocodeSearchResponse *)reGeoResult location:(AMapGeoPoint *)location;

+ (NSString *)errorDescriptionWithCode:(NSInteger)errorCode;

@end
