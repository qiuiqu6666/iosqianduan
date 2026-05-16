//telegram @wz662
#import <Foundation/Foundation.h>
#import "GroupEntity.h"

@interface QueryGroupInfoAsync : NSObject

+ (void)doIt:(NSString *)gid myUserId:(NSString *)myUserId hudParentViewController:(UIViewController *)viewController;

/**
 * 查看群信息（方法内部将根据有网、无网等情况智能判断并进行相应的信息加载逻辑，确保最大限度查看的是最新数据）。
 *
 * @param gid 群id
 * @param ge 群信息数据，如果此数据不为空，将优先查看此数据
 */
+ (void)gotoWatchGroupInfo:(NSString *)gid withInfo:(nullable GroupEntity *)ge nav:(UINavigationController *)nav view:(UIView *)v vc:(UIViewController *)vc;

@end
