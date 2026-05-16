//telegram @wz662
/**
 * 本类是图片选择封装和处理类，包括从相机拍照、相册选取能力，封装的目的是希望
 * 在简化调用者的代码，不然到处都是图片选择代码混到业务功能里太难看了，本类的
 * 高度封装重用可以解决这个问题。
 *
 * @author Jack Jiang, 2017-12-28
 * @version 1.0
 */

#import <Foundation/Foundation.h>
#import "TZImagePickerController.h"


@protocol RBImagePickerCompleteDelegate;
@interface RBImagePickerWrapper : NSObject<TZImagePickerControllerDelegate, UIAlertViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>// 此 UINavigationControllerDelegate 本是不需要的，仅为了 _imagePickerVc.delegate = self 时不显示警告而已(m)

@property (nonatomic, weak) id<RBImagePickerCompleteDelegate> imagePickerCompleteDelegate;

/** YES：相册选图时开启「原图」能力并默认按原图导出（二维码识别等需要清晰像素）；默认 NO */
@property (nonatomic, assign) BOOL preferAlbumOriginalPhotoForRecognition;

/**
 实例化图片处理封装对象（默认不提供裁剪能力）。

 @param parentViewController 父view控制器引用
 @param imagePickerCompleteDelegate 图片拍摄或从相册选项完成后的回调代码方法，不参数不可为空！
 @return 返回本对象
 */
- (id)initWithParent:(UIViewController *)parentViewController delegate:(id<RBImagePickerCompleteDelegate>)imagePickerCompleteDelegate;

/**
 实例化图片处理封装对象。

 @param parentViewController 父view控制器引用
 @param imagePickerCompleteDelegate 图片拍摄或从相册选项完成后的回调代码方法，不参数不可为空！
 @param enableCrop YES表示提供裁剪功能（比如用于用户头像修改时），否则不提供裁剪（普通的图片拍摄或相册选择）
 @return 返回本对象
 */
- (id)initWithParent:(UIViewController *)parentViewController delegate:(id<RBImagePickerCompleteDelegate>)imagePickerCompleteDelegate crop:(BOOL)enableCrop;

/**
 使用相机拍照的入口方法。
 */
- (void)takePhoto;

/**
 使用相册并发送图片消息入口方法。
 
 @param allowPickingVideo YES表示允许选择视频，否则仅允许选择图片
 */
- (void)takeAlbum:(BOOL)allowPickingVideo;

@end



@protocol RBImagePickerCompleteDelegate <NSObject>
@optional

/**
 图片选择结果代理方法：可以经此方法中处理从相机、相册中选择的图片进行进一步处理。
 <p>
 本代码方法被调用，即意味着已成功获得图片，其它乱七八糟的前置处理已经在中RBImagePickerWrapper封
 装处理好了。

 @param photo 图片对象
 @param tag debug的TAG
 */
- (void)processImagePickerComplete:(UIImage *)photo withTag:(NSString *)tag;

/**
 多图片选择结果代理方法：可以经此方法中处理从相册中选择的多张图片进行进一步处理。
 <p>
 本代码方法被调用，即意味着已成功获得多张图片，最多9张。
 
 @param photos 图片对象数组
 @param tag debug的TAG
 */
- (void)processMultiImagePickerComplete:(NSArray<UIImage *> *)photos withTag:(NSString *)tag;

 /**
 视频选择结果代理方法：可以经此方法中处理从相册中选择的视频进行进一步处理。
 <p>
 本代码方法被调用，即意味着已成功获得视频，其它乱七八糟的前置处理已经在中RBImagePickerWrapper封
 装处理好了。

 @param videoFilePath 视频文件绝对路径
 @param tag debug的TAG
 */
- (void)processVideoPickerComplete:(NSString *)videoFilePath duration:(int)duration withTag:(NSString *)tag;

/**
 用户头像场景下从相册选择了 GIF 动图时的回调（不裁剪，原图上传）。
 若未实现则按静态图走 processImagePickerComplete:。
 @param fileURL GIF 文件的本地 URL（临时文件，调用方用后可选删除）
 @param tag debug 的 TAG
 */
- (void)processImagePickerCompleteWithGifFileURL:(NSURL *)fileURL withTag:(NSString *)tag;

@end
