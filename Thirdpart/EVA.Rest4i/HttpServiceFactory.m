//telegram @wz662
#import "HttpServiceFactory.h"

/** 所有服务实例引用列表 */
static NSMutableDictionary<NSString *, HttpService *> *serviceInstances;

@implementation HttpServiceFactory

+ (void) addServices:(NSString *)httpURL
{
    [HttpServiceFactory addServices:@DEFAULT_SERVICE_NAME withURL:httpURL overWriteIfExists:NO];
}

+ (void) addServices:(NSString *)serviceName withURL:(NSString *)httpURL
{
    [HttpServiceFactory addServices:serviceName withURL:httpURL overWriteIfExists:NO];
}

+ (void) addServices:(NSString *)serviceName withURL:(NSString *)httpURL overWriteIfExists:(bool)overWrite
{
    if(serviceName)
    {
        if(serviceInstances == nil)
            serviceInstances = [[NSMutableDictionary alloc] init];

        if([serviceInstances objectForKey:serviceName] != nil && !overWrite)
        {
            NSLog(@"【警告】服务%@已经存在，再新添加到它到服务列表失败！", serviceName);
            return;
        }

        HttpService *hs = [[HttpService alloc] initWithURL:httpURL];
        [serviceInstances setObject:hs forKey:serviceName];
    }
    else
    {
        NSLog(@"【警告】HTTP服务名称不可为空，增加新服务到服务列表失败！");
    }
}

+ (HttpService *) getService:(NSString *)serviceName
{
    if(serviceName == nil)
    {
        NSLog(@"【警告】获取服务失败，serviceName==nil.");
        return nil;
    }

    HttpService *serviceInstance = [serviceInstances objectForKey:serviceName];
    if(serviceInstance == nil)
       NSLog(@"【警告】获取服务失败，可能是你指定的服务尚未添加到服务列表中,serviceName=%@", serviceName);

    return serviceInstance;
}

+ (HttpService *) getDefaultService
{
    return [HttpServiceFactory getService:@DEFAULT_SERVICE_NAME];
}

+ (NSMutableDictionary<NSString *, HttpService *> *) getServices
{
    return serviceInstances;
}

@end
