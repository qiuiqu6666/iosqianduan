//telegram @wz662
#import <UIKit/UIKit.h>
#import "BigFileDownloadManager.h"

@interface BigFileViewerController : UIViewController<BigFileDownloadManagerDelegate, UIDocumentInteractionControllerDelegate>

/** 文件查看界面上方显示的此文件类型图标（根据扩展名来决定的） */
@property (weak, nonatomic) IBOutlet UIImageView *mViewFileIcon;
/** 文件查看界面下方显示的此文件名 */
@property (weak, nonatomic) IBOutlet UILabel *mViewFileName;
/** 文件查看界面下方显示的此文件原始大小 */
@property (weak, nonatomic) IBOutlet UILabel *mViewFileSize;

/** 文件查看界面下方的下载进度条组件父view的高度约束（当不需要显地此组件时，本值设为0即可） */
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *heightConstraintOfDownloadProgressLayout;
/** 文件查看界面下方的下载进度条（始果需要下载才显示哦） */
@property (weak, nonatomic) IBOutlet UIProgressView *mDownloadProgress;

/** 文件操作按钮：意义可以是打开、继续下载、暂停下载等，具体由文件下载状态和逻辑动态决定 */
@property (weak, nonatomic) IBOutlet UIButton *mBtnOpr;
/** 文件查看界面最下方的提示信息显示组件，比如当下载出错时会显示提示信息 */
@property (weak, nonatomic) IBOutlet UITextView *mViewHint;


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil fileName:(NSString *)fileName fileDir:(NSString *)fileDir fileMd5:(NSString *)fileMd5 fileLength:(long long)fileLength canDownload:(BOOL)canDownload;

/**
 * 返回对应扩展名的文件图标（大）。
 *
 * @param fileName 文件名
 * @return 图片对象
 */
+ (UIImage *) getFileIconByExtention:(NSString *)fileName bigImage:(BOOL)big;

@end
