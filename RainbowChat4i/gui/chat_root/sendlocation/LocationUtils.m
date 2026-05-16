//telegram @wz662
@import AMapSearchKit;
#import "LocationUtils.h"
#import "FileTool.h"
#import "IMClientManager.h"
#import "FileUploadHelper.h"

#define kErrorInfoUrl @"http://lbs.amap.com/api/ios-sdk/guide/map-tool/errorcode/"

/** 位置的预览图片压缩质量（0~1.0的量，0表最大压缩，1.0表不压缩，默认0.75是参考微信的压缩率），改变此值将影响发送的图片文件大小、显示清晰度 */
#define LOCATION_PREVIEW_IMG_COMPRESS_QUALITY    0.50//0.75
/** 位置的预览图片缩放最大尺寸，改变此值将影要发送的图片文件大小 */
#define LOCATION_PREVIEW_IMG_COMPRESS_MAX_WIDTH  480


@implementation LocationUtils

// 获得下载指定位置消息的预览图片2进制数据的完整http地址.
+ (NSString *)getPreviewImageDownloadURL:(NSString *)file_name dump:(BOOL)needDump
{
    NSString *fileURL = nil;
    if( [[IMClientManager sharedInstance] localUserInfo] != nil)
    {
        fileURL = [NSString stringWithFormat:@"%@?action=location_d&user_uid=%@&file_name=%@&need_dump=%@", BBONERAY_DOWNLOAD_CONTROLLER_URL_ROOT, [[IMClientManager sharedInstance] localUserInfo].user_uid, file_name, (needDump?@"1":@"0")];
    }
    return fileURL;
}

// 获得指定位置消息的预览图片的完整http地址（通过高德地图提供的静态地图服务实现）.
+ (NSString *)getPreviewImageDownloadURL2:(double)longitude lat:(double)latitude
{
    NSString *statidMapPreviewURL = [NSString stringWithFormat:@"https://restapi.amap.com/v3/staticmap?location=%f,%f&zoom=14&scale=2&size=240*100&key=%@", longitude, latitude, GAODE_WEBSERVICE_KEY];
    return statidMapPreviewURL;
}

// 位置预览图片文件上传
+ (void)uploadLocationPreviewFile:(NSString *)fileName completeFail:(void (^)(NSError *error))failure completeSucess:(void (^)(id responseObject))success
{
    NSString *uid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    NSString *previewSavedPath = [NSString stringWithFormat:@"%@/%@", [LocationUtils getLocationPreviewFileSavedDir], fileName];
    
    // 额外参数
    NSMutableDictionary *parameter = [NSMutableDictionary dictionary];
    parameter[@"user_uid"] = uid;
    parameter[@"file_name"] = fileName;
    // 通过 Authorization header 传递 token（由 FileUploadHelper 中 setupAuthorization 设置）
    
    [FileUploadHelper uploadFileImpl:previewSavedPath
                     withName:fileName
                       andUrl:LOCATION_PREVIEW_UPLOADER_CONTROLLER_URL_ROOT
                andParameters:parameter
                     progress:^(NSProgress * _Nonnull uploadProgress) {
                         //打印下上传进度
                         DDLogDebug(@"【位置消息-截图-上传】上传进度> %lf", 1.0 * uploadProgress.completedUnitCount / uploadProgress.totalUnitCount);
                     }
                      success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
                          //请求成功
                          DDLogDebug(@"【位置消息-截图-上传】文件上传成功【OK】：%@", responseObject);

                          if(success)
                              success(responseObject);
                      }
                      failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                          //请求失败
                          DDLogDebug(@"【位置消息-截图-上传】文件上传失败【NO】：%@", error);

                          if(failure)
                              failure(error);
                      }
    ];
}

// 保存位置预览图片到本地文件
+ (void)saveMapScreenShot:(UIImage *)bitmap status:(NSInteger)status locationTitle:(NSString *)locationTitle fileSavedName:(NSString *)fileSavedName complete:(void (^)(BOOL sucess, NSString *imgFilePath))block
{
    BOOL sucess = NO;
    NSString *imgFilePath = nil;
    
    if(nil == bitmap)
    {
        DDLogWarn(@"【位置消息-截图-保存】bitmap为空，没有成功截到位置预览图！");
        if(block)
            block(NO, nil);
        return;
    }
    
    // 预览图的文件名（本地保存的名）
    NSString *fileName = fileSavedName;
    
    if(fileName == nil)
    {
        DDLogWarn(@"【位置消息-截图-保存】要保存的fileName为空，位置预览图无法成功保存哦！");
        if(block)
            block(NO, nil);
        return;
    }
    
    DDLogWarn(@"【位置消息-截图-保存】要保存的文件名为：%@，预览图保存进入下一步.....", fileName);
    
    
    // 将图片进行尺寸压缩和质量压缩，不然默认图可能会太大，占内存不说，ui上看起来也很难看
    NSString *filePathAfterCompress = [BasicTool imageCompressForQualityAndWidth:bitmap
                                                                   targetQuality:LOCATION_PREVIEW_IMG_COMPRESS_QUALITY
                                                                     targetWidth:LOCATION_PREVIEW_IMG_COMPRESS_MAX_WIDTH
                                                                       saveToDir:[LocationUtils getLocationPreviewFileSavedDir]
                                                                       savedName:fileName];
    DDLogDebug(@"【位置消息-截图-保存】图片压缩保存完成（成功了吗？%d），压缩后保存的路径为：%@", (filePathAfterCompress != nil), filePathAfterCompress);
    
    // 图片压缩并保存成功
    if(filePathAfterCompress != nil)
    {
        sucess = YES;
        imgFilePath = filePathAfterCompress;
    }
    
    if(block)
        block(sucess, imgFilePath);
}

// 返回地图预览截图的目录（结尾带反斜线）
+ (NSString *)getLocationPreviewFileSavedDirHasSlash
{
    NSString *dir = [LocationUtils getLocationPreviewFileSavedDir];
    return dir ==  nil? nil : [NSString stringWithFormat:@"%@/", dir];
}

// 返回地图预览截图的目录
+ (NSString *)getLocationPreviewFileSavedDir
{
    NSString *dir = [NSString stringWithFormat:@"%@%@", [FileTool getCachedPath], DIR_KCHAT_LOCATION_RELATIVE_DIR];
    return dir;
}

// 生成一个地图预览截图的文件名
+ (NSString *)generateLocationPreviewFileName
{
    NSString *uuid = [[NSUUID UUID] UUIDString];
    if(uuid != nil)
    {
        NSString *uuidReplaced = [uuid stringByReplacingOccurrencesOfString:@"-" withString:@""];
        return [NSString stringWithFormat:@"%@.jpg", uuidReplaced];
    }
    return nil;
}

+ (NSString *)getPOIItemName:(NSString *)name
{
    return [BasicTool isStringEmpty:name]?@"位置":name;
}

+ (NSString *)getPOIItemAddr:(NSString *)addr lng:(double)longitude lat:(double)latitude
{
    return [BasicTool isStringEmpty:addr]?[NSString stringWithFormat:@"经度：%f 纬度：%f", longitude, latitude]:addr;
}

+ (AMapPOI *)changeToPoiItem:(AMapReGeocodeSearchResponse *)reGeoResult location:(AMapGeoPoint *)location
{
    if (nil != reGeoResult.regeocode)
    {
        AMapReGeocode *regeocode = reGeoResult.regeocode;
        
        DDLogDebug(@"【位置消息-changeToPoiItem】formattedAddress=%@, addressComponent.country=%@, addressComponent.province=%@, addressComponent.city=%@, addressComponent.district=%@, addressComponent.township=%@, addressComponent.neighborhood=%@, addressComponent.building=%@, addressComponent.streetNumber.street=%@, addressComponent.streetNumber.street=%@"
                   , regeocode.formattedAddress
                   , regeocode.addressComponent.country
                   
                   , regeocode.addressComponent.province
                   , regeocode.addressComponent.city
                   , regeocode.addressComponent.district
                   , regeocode.addressComponent.township
                   , regeocode.addressComponent.neighborhood
                   , regeocode.addressComponent.building
                   , regeocode.addressComponent.streetNumber.street
                   , regeocode.addressComponent.streetNumber.number);
        
        NSString *title = nil;
        if(regeocode.addressComponent != nil)
        {
            title = regeocode.addressComponent.building;
            if ([BasicTool isStringEmpty:title])
                title = regeocode.addressComponent.neighborhood;
            
            if ([BasicTool isStringEmpty:title])
            {
                if(regeocode.addressComponent.streetNumber != nil)
                    title = [NSString stringWithFormat:@"%@%@", regeocode.addressComponent.streetNumber.street, regeocode.addressComponent.streetNumber.number];
            }
            
            if ([BasicTool isStringEmpty:title])
                title = regeocode.addressComponent.township;
        }
        
        if ([BasicTool isStringEmpty:title])
            title = regeocode.formattedAddress;
        else if ([BasicTool isStringEmpty:title])
            title = @"位置";
        
        AMapPOI *POIModel = [AMapPOI new];
        POIModel.name = title;
        POIModel.address = regeocode.formattedAddress;
        POIModel.location = location;
    
        return POIModel;
    }
    
    return nil;
}

+ (NSDictionary *)errorInfoMapping
{
    static NSDictionary *errorInfoMapping = nil;
    if (errorInfoMapping == nil)
    {
        errorInfoMapping = @{@(AMapSearchErrorOK):@"没有错误",
                             @(AMapSearchErrorInvalidSignature):@"无效签名",
                             @(AMapSearchErrorInvalidUserKey):@"key非法或过期",
                             @(AMapSearchErrorServiceNotAvailable):@"没有权限使用相应的接口",
                             @(AMapSearchErrorDailyQueryOverLimit):@"访问已超出日访问量",
                             @(AMapSearchErrorTooFrequently):@"用户访问过于频繁",
                             @(AMapSearchErrorInvalidUserIP):@"用户IP无效",
                             @(AMapSearchErrorInvalidUserDomain):@"用户域名无效",
                             @(AMapSearchErrorInvalidUserSCode):@"安全码验证错误，bundleID与key不对应",
                             @(AMapSearchErrorUserKeyNotMatch):@"请求key与绑定平台不符",
                             @(AMapSearchErrorIPQueryOverLimit):@"IP请求超限",
                             @(AMapSearchErrorNotSupportHttps):@"不支持HTTPS请求",
                             @(AMapSearchErrorInsufficientPrivileges):@"权限不足，服务请求被拒绝",
                             @(AMapSearchErrorUserKeyRecycled):@"开发者key被删除，无法正常使用",
                             
                             @(AMapSearchErrorInvalidResponse):@"请求服务响应错误",
                             @(AMapSearchErrorInvalidEngineData):@"引擎返回数据异常",
                             @(AMapSearchErrorConnectTimeout):@"服务端请求链接超时",
                             @(AMapSearchErrorReturnTimeout):@"读取服务结果超时",
                             @(AMapSearchErrorInvalidParams):@"请求参数非法",
                             @(AMapSearchErrorMissingRequiredParams):@"缺少必填参数",
                             @(AMapSearchErrorIllegalRequest):@"请求协议非法",
                             @(AMapSearchErrorServiceUnknown):@"其他服务端未知错误",
                             
                             @(AMapSearchErrorClientUnknown):@"客户端未知错误，服务返回结果为空或其他错误",
                             @(AMapSearchErrorInvalidProtocol):@"协议解析错误，通常是返回结果无法解析",
                             @(AMapSearchErrorTimeOut):@"连接超时",
                             @(AMapSearchErrorBadURL):@"URL异常",
                             @(AMapSearchErrorCannotFindHost):@"找不到主机",
                             @(AMapSearchErrorCannotConnectToHost):@"服务器连接失败",
                             @(AMapSearchErrorNotConnectedToInternet):@"连接异常，通常为没有网络的情况",
                             @(AMapSearchErrorCancelled):@"连接取消",
                             
                             @(AMapSearchErrorTableIDNotExist):@"table id 格式不正确",
                             @(AMapSearchErrorIDNotExist):@"id 不存在",
                             @(AMapSearchErrorServiceMaintenance):@"服务器维护中",
                             @(AMapSearchErrorEngineTableIDNotExist):@"key对应的table id 不存在",
                             @(AMapSearchErrorInvalidNearbyUserID):@"找不到对应userID的信息",
                             @(AMapSearchErrorNearbyKeyNotBind):@"key未开通“附近”功能",
                             @(AMapSearchErrorOutOfService):@"规划点（包括起点、终点、途经点）不在中国范围内",
                             @(AMapSearchErrorNoRoadsNearby):@"规划点（包括起点、终点、途经点）附近搜不到道路",
                             @(AMapSearchErrorRouteFailed):@"路线计算失败，通常是由于道路连通关系导致",
                             @(AMapSearchErrorOverDirectionRange):@"起点终点距离过长",
                             @(AMapSearchErrorShareLicenseExpired):@"短串分享认证失败",
                             @(AMapSearchErrorShareFailed):@"短串请求失败",};
    }
    
    return errorInfoMapping;
}

+ (NSString *)errorDescriptionWithCode:(NSInteger)errorCode
{
//    AMapSearchError.h
    NSString *description = [NSString stringWithFormat:@"错误信息：%@。请在<AMapSearchKit/AMapSearchError.h>头文件中查看错误信息或者访问【%@】了解详细信息。", [[self errorInfoMapping] objectForKey:@(errorCode)], kErrorInfoUrl];
    return description;
}

@end
