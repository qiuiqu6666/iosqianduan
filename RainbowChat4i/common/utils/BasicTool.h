//telegram @wz662
//#import "DatePair.h"
//#import "RecordData.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CommonCrypto/CommonDigest.h>
#import "JSQMessage.h"

#define  HALF_DAY (60*60*12)
#define  ONE_DAY (60*60*24)
#define  ONE_HOUR (60*60)

@interface BasicTool : NSObject

/**
 * 给按钮设置液态玻璃效果。
 */
+ (void)setClearGlassBgnConfig:(UIButton *)btn;

/**
 * 一个全局的收起软键盘的方法。
 */
+ (void)hideSoftInputMethod;

/**
 * 检查手机号是否符合中国大陆手机号码规范。
 *
 * @param phoneNum 手机号
 * @return tYES表示符合，否则不符号
 */
+ (BOOL)verifyChineseMainlandPhone:(NSString *_Nonnull)phoneNum;

/**
 * 结文本输入区进行输入长度限制。
 */
+ (void)textFieldInputLimit:(UITextField *_Nonnull)textField maxLen:(int)mLen;

/**
 设置边框。
 */
+ (void)setBorder:(UIView *_Nonnull)v width:(CGFloat)w color:(UIColor *_Nonnull)c radius:(CGFloat)r;

/**
 * 安全地返回本地用户UID.
 *
 * @returns local uid
 */
+ (NSString *_Nonnull)getLocalUserUid;

/**
 * 是否"@我".
 *
 * @param at 被"@"人的uid数组
 * @return true表示被"@"，否则不是
 */
+ (BOOL)isAtMe:(NSArray *_Nonnull)at;

/**
 * 从字符串数组中判断是否存在指定字符串的单元。
 *
 * @param src 源数组
 * @param targetString 目标字符串
 * @return true表示存在，否则不存在
 * @since 11.0
 */
+ (BOOL)matchInStringArray:(NSArray *_Nonnull)src target:(NSString *_Nonnull)targetString;
    
/**
 显示提示信息并提供跳转到登陆界面的能力（当前用于被踢或token失效时）。
 
 @param title 提示标题
 @param alertContent 提示信息
 @since 7.1
 */
+ (void)showAlertAndGotoLogin:(NSString *)alertTitle content:(NSString *)alertContent;

/**
 * 高亮显示该条消息（从搜索进入聊天时定位到的那条），灰色背景一直保持不淡出。
 *
 * @param msgCell 表格 cell 引用
 * @param msg  要高亮显示的消息对象
 * @since 6.0
 */
+ (void)highlightOnceMessageItem:(UIView *_Nonnull)msgCell forMsg:(JSQMessage *_Nonnull)msg;

/**
 * 关键字高亮显示。
 *
 * @param src 源字符码
 * @param keyword 关键字
 * @param color 高亮颜色
 * @return 正常处理完成则返回属性字符串对象，否则返回nil
 */
+ (NSMutableAttributedString *_Nullable) coloredStringForSearch:(NSString *)src keyword:(NSString *)keyword keywordColor:(UIColor *)color;

/**
 * 将光标移至文字末尾。
 *
 * @param txtField 文本输入框
 */
+ (void)setCursorToEnd:(UITextField *_Nonnull)txtField;

/**
 * UI组件圆角，支持分别指定4个角的圆角效果。
 *
 * @param srcView 需要圆角化的UIView组件
 * @param corners 圆角范围，参数可以是（可以通过 “|” 组合使用）：
 *                        UIRectCornerTopLeft  //上部左角
 *                        UIRectCornerTopRight  //上部右角
 *                        UIRectCornerBottomLeft  //下部左角
 *                        UIRectCornerBottomRight //下部右角
 *                        UIRectCornerAllCorners  // 设置所有的角
 * @param cornerRadii 圆角半径，形如：CGSizeMake(10, 10)
 */
+ (void)viewRoundCorner:(UIView *_Nonnull)srcView byRoundingCorners:(UIRectCorner)corners cornerRadii:(CGSize)cornerRadii;

/**
 * 查找字符串中最后出现的字符所在索引.
 *
 * @param srcStr 源字符串
 * @param lastChar 被查找的字符
 * @return 如果找到则返回正常索引值，否则返回-1
 */
+ (int)lastIndex:(NSString *_Nonnull)srcStr of:(char *_Nonnull)lastChar;

/**
 在主线程中运行.
 @param block 需要运行在主线程中的代码块
 */
+ (void)runInMainThread:(dispatch_block_t _Nullable )block;

/**
 * 识别系统通知账号。
 *
 * @param uid uid号
 * @return true表示是，否则不是
 * @since 4.4
 */
+ (BOOL)isSystemAdmin:(NSString *_Nonnull)uid;

/**
 * 识别只读官方账号（不允许发送消息，如10000、400070）。10001、400069 为官方账号但可发消息。
 */
+ (BOOL)isReadOnlyOfficialAccount:(NSString *_Nonnull)uid;

/**
 * 聊天中不显示导航更多按钮、不显示在线时间且点击标题/更多不跳转资料页的账号（10000、400069、400070）。10001 仍显示更多并可跳转。
 */
+ (BOOL)isOfficialAccountHideAvatarInChat:(NSString *_Nonnull)uid;

/**
 * 会话/消息列表中显示「官方」标签的账号（10000、400069、400070）。10001 不显示官方标签。
 */
+ (BOOL)isOfficialAccountShowFlagInConversationList:(NSString *_Nonnull)uid;

/// 官方图标资源（xc / 官方帖子.png），找不到时返回 nil。
+ (UIImage *_Nullable)officialBadgeImage;

/// 生成「昵称 + 官方图标」富文本；未追加图标时返回纯文本属性串。
+ (NSAttributedString *_Nonnull)attributedName:(NSString *_Nullable)name
                           appendOfficialBadge:(BOOL)appendBadge
                                          font:(UIFont *_Nullable)font
                                     textColor:(UIColor *_Nullable)textColor
                                   badgeHeight:(CGFloat)badgeHeight;

/**
 * 角标数字转字符串，当数字大于99时，返回"99+"。
 *
 * @param badgeNumber 数字
 * @return 字符串
 */
+ (NSString *_Nonnull)getBadgeViewString:(int)badgeNumber;
    
/// 绘制UIView圆角.
///
/// @param v ui组件
/// @param corners 圆角位置，可以是 UIRectCornerBottomLeft | UIRectCornerBottomRight | UIRectCornerTopRight | UIRectCornerBottomRight 或 UIRectCornerAllCorners
/// @param cornerRadii 圆角大小，如：CGSizeMake(12.0, 12.0)
+ (void)roundView:(UIView *)v byRoundingCorners:(UIRectCorner)corners cornerRadii:(CGSize)cornerRadii;

/**
 返回留海屏安全区上部分的衬距。
 
 @return 如果大于ios11（含）则返回该值，否则返回0
 @since 7.0
 */
+ (CGFloat)getSafeAreaInsets_top;

/**
 返回留海屏安全区下部分的衬距。
 
 @return 如果大于ios11（含）则返回该值，否则返回0
 @since 4.1
 */
+ (CGFloat)getSafeAreaInsets_bottom;

/**
 显示一个“普通提示”信息弹出提示框。因ios8及以上系统中UIAlertView已过时，本方法将使用UIAlertController实现同样的功能。
 
 @param content 提示信息内容
 @param parent 依赖的爷UIViewControler对象
 */
+ (void)showAlertInfo:(id)content parent:(UIViewController *_Nonnull)parent;

/**
 显示一个“警告提示”信息弹出提示框。因ios8及以上系统中UIAlertView已过时，本方法将使用UIAlertController实现同样的功能。
 
 @param content 提示信息内容
 @param parent 依赖的爷UIViewControler对象
 */
+ (void)showAlertWarn:(id)content parent:(UIViewController *_Nonnull)parent;

/**
 显示一个“错误提示”信息弹出提示框。因ios8及以上系统中UIAlertView已过时，本方法将使用UIAlertController实现同样的功能。
 
 @param content 提示信息内容
 @param parent 依赖的爷UIViewControler对象
 */
+ (void)showAlertError:(id)content parent:(UIViewController *)parent;

/**
 显示一个弹出提示框。因ios8及以上系统中UIAlertView已过时，本方法将使用UIAlertController实现同样的功能。

 @param title 标题
 @param content 提示信息内容
 @param btnTitle 按钮上显示的文字
 @param parent 依赖的爷UIViewControler对象
 */
+ (void)showAlert:(NSString *)title content:(id)content btnTitle:(NSString *)btnTitle parent:(UIViewController *)parent;

/**
显示一个弹出提示框。因ios8及以上系统中UIAlertView已过时，本方法将使用UIAlertController实现同样的功能。

@param title 标题
@param content 提示信息内容
@param btnTitle 按钮上显示的文字
@param parent 依赖的爷UIViewControler对象
@param handler 点击确认时的block回调
*/
+ (void)showAlert:(NSString *)title content:(id)content btnTitle:(NSString *)btnTitle parent:(UIViewController *)parent handler:(void (^ __nullable)(UIAlertAction *action))handler;

/**
 显示一个确认提示框。因ios8及以上系统中UIAlertView已过时，本方法将使用UIAlertController实现同样的功能。
 
 @param title 标题
 @param content 提示信息内容
 @param okBtnTitle 确认按钮上显示的文字
 @param cancelBtnTitle 取消按钮上显示的文字
 @param parent 依赖的爷UIViewControler对象
 @param okHandler 点击确认时的block回调
 @param cancelHandler 点击取消时的block回调
 @since 10.2
 */
+ (void)areYouSureAlert:(NSString *)title content:(NSString *)content okBtnTitle:(NSString *)okBtnTitle cancelBtnTitle:(NSString *)cancelBtnTitle parent:(UIViewController *)parent okHandler:(void (^ __nullable)(UIAlertAction *action))okHandler cancelHandler:(void (^ __nullable)(UIAlertAction *action))cancelHandler;

/**
 显示一个确认提示框。因ios8及以上系统中UIAlertView已过时，本方法将使用UIAlertController实现同样的功能。
 
 @param title 标题
 @param content 提示信息内容
 @param okBtnTitle 确认按钮上显示的文字
 @param cancelBtnTitle 取消按钮上显示的文字
 @param parent 依赖的爷UIViewControler对象
 @param okHandler 点击确认时的block回调
 @param cancelHandler 点击取消时的block回调
 @param cencelActionStyle cancel按钮样式
 */
+ (void)areYouSureAlert:(NSString *_Nonnull)title content:(NSString *_Nonnull)content okBtnTitle:(NSString *_Nullable)okBtnTitle cancelBtnTitle:(NSString *_Nullable)cancelBtnTitle parent:(UIViewController *_Nonnull)parent okHandler:(void (^ __nullable)(UIAlertAction * _Nullable action))okHandler cancelHandler:(void (^ __nullable)(UIAlertAction * _Nullable action))cancelHandler cencelActionStyle:(UIAlertActionStyle)cencelActionStyle;

/**
 显示一个确认提示框。因ios8及以上系统中UIAlertView已过时，本方法将使用UIAlertController实现同样的功能。
 
 @param title 标题
 @param content 提示信息内容
 @param okBtnTitle 确认按钮上显示的文字
 @param cancelBtnTitle 取消按钮上显示的文字
 @param parent 依赖的爷UIViewControler对象
 @param okHandler 点击确认时的block回调
 @param cancelHandler 点击取消时的block回调
 @param okActionStyle ok按钮的样式
 @param cencelActionStyle cancel按钮样式
 @since 10.2
 */
+ (void)areYouSureAlert:(NSString *)title content:(NSString *)content okBtnTitle:(NSString *)okBtnTitle cancelBtnTitle:(NSString *)cancelBtnTitle parent:(UIViewController *)parent okHandler:(void (^ __nullable)(UIAlertAction *action))okHandler cancelHandler:(void (^ __nullable)(UIAlertAction *action))cancelHandler okActionStyle:(UIAlertActionStyle)okActionStyle cencelActionStyle:(UIAlertActionStyle)cencelActionStyle;

/**
 获得一个纯色UIImage图片对象。

 @param color 颜色
 @param size 图片大小，默认请填 CGRectMake(0.0f, 0.0f, 1.0f, 1.0f)
 @return 新的UIImage对象
 */
+ (UIImage *)imageWithColor:(UIColor *)color withSize:(CGSize)size;

/**
 获得一个纯色UIImage图片对象。

 @param color 颜色
 @param size 图片大小，默认请填 CGRectMake(0.0f, 0.0f, 1.0f, 1.0f)
 @param cornerRadius 圆角半径
 @return 新的UIImage对象
 */
+ (UIImage *)imageWithColor:(UIColor *)color withSize:(CGSize)size cornerRadius:(CGFloat)cornerRadius;

/**
 对图片对象进行圆角处理。

 @param image 图片对象
 @param cornerRadius 圆角半径
 @return 新的UIImage对象
 */
+ (UIImage *)imageWithCorner:(UIImage *)image cornerRadius:(CGFloat)cornerRadius;

+ (void)showImageWithURL:(NSString *)imgHttpUrl;

+ (void)showImageWithPath:(NSString *)localImagePath;

+ (void)showImage:(UIImage *)img;

/**
 为一个UIView增加手指点击事件处理。

 @param view view组件
 @param action 事件处理函数
 */
+ (void)addFingerClick:(UIView *)view action:(nullable SEL)action target:(nullable id)target;

/**
 为图片组件设置可拉伸不变形背景图片。

 @param viewImg 要设置拉伸图片的图片给件
 @param eim 不可拉伸范围，形如：UIEdgeInsetsMake(16, 16, 16, 16)
 @param imgName 被拉伸的原始图片名，形如：@“btn_style_alert_dialog_confirm_normal”
 */
+ (void)setStretchImage:(UIImageView *)viewImg capInsets:(UIEdgeInsets)eim imgName:(NSString *)imgName;

/**
 为图片组件设置可拉伸不变形背景图片。

 @param viewImg 要设置拉伸图片的图片给件
 @param eim 不可拉伸范围，形如：UIEdgeInsetsMake(16, 16, 16, 16)
 @param img 被拉伸的原始图片
 */
+ (void)setStretchImage:(UIImageView *)viewImg capInsets:(UIEdgeInsets)eim img:(UIImage *)img;

/**
 为按钮设置可拉伸不变形背景图片。

 @param btn 要设置背景的按钮
 @param eim 不可拉伸范围，形如：UIEdgeInsetsMake(16, 16, 16, 16)
 @param imgName 被拉伸的原始图片名，形如：@“btn_style_alert_dialog_confirm_normal”
 */
+ (void)setStretchBackgroundImage:(UIButton *)btn capInsets:(UIEdgeInsets)eim imgName:(NSString *)imgName forState:(UIControlState)state;

/**
 为按钮设置可拉伸不变形背景图片。

 @param btn 要设置背景的按钮
 @param eim 不可拉伸范围，形如：UIEdgeInsetsMake(16, 16, 16, 16)
 @param img 被拉伸的原始图片
 */
+ (void)setStretchBackgroundImage:(UIButton *)btn capInsets:(UIEdgeInsets)eim img:(UIImage *)img forState:(UIControlState)state;

/**
 显示一个可以定义图标和文本内容的Toast。

 @param tipContent 文本内容
 @param parentView 父view
 @param complete 在Toast消失时执行时block，可为nil
 */
+ (void)showUserDefintToast:(NSString *)tipContent view:(UIView *)parentView atHide:(void (^)(void))complete;

/**
 * 截断文本（以字符长度为准，如中文等双字节字符是作为len=1计算的）.
 *
 * @param msg 文本
 * @param maxLen 超过该长度之后的部分将自动被截断，否则返样返回
 * @return String 截断后的文本
 */
+ (NSString *)truncString:(NSString *)msg maxLen:(int)maxLen;

+ (NSString *)trim:(NSString *)s;

// 当前系统语言是否简体中文
+ (BOOL)isChineseSimple;

// 当前系统语言是否中文（不区分简繁体）
+ (BOOL)isChinese;

+ (BOOL)isStringEmpty:(NSString *)str;

+ (int)getIntValue:(NSString *)intWithStr;
+ (int)getIntValue:(NSString *)intWithStr defaultVal:(int)defaultValue;

// 判断字符串是否是数字
+ (BOOL) isFullNumber:(NSString *)str;
// 邮箱地址的判断
+ (BOOL) isValidEmail:(NSString *)email;

/**
 * 获取当前应用的字体大小倍数
 * @return 字体倍数：小=0.85, 标准=1.0, 大=1.15, 超大=1.3
 */
+ (CGFloat)getAppFontSizeMultiplier;

/**
 * 根据基础字体大小获取调整后的字体大小
 * @param baseFontSize 基础字体大小
 * @return 调整后的字体大小
 */
+ (CGFloat)getAdjustedFontSize:(CGFloat)baseFontSize;

/**
 * 获取系统字体（根据应用字体大小设置调整）
 * @param baseFontSize 基础字体大小
 * @return 调整后的UIFont
 */
+ (UIFont *)getSystemFontOfSize:(CGFloat)baseFontSize;

/**
 * 获取粗体系统字体（根据应用字体大小设置调整）
 * @param baseFontSize 基础字体大小
 * @return 调整后的UIFont
 */
+ (UIFont *)getBoldSystemFontOfSize:(CGFloat)baseFontSize;

/**
 * 刷新指定视图及其所有子视图的字体大小（根据全局字体设置）
 * @param view 要刷新的视图
 */
+ (void)refreshFontsForView:(UIView *)view;

/**
 * 同上，但跳过某子树根（不处理该 view 及其所有后代）。用于聊天页：消息列表内 UITextView 须仅由 FlowLayout.messageBubbleFont + cell 配置，避免与 refreshFonts 递归改 .font 冲突导致裁字/抖动。
 */
+ (void)refreshFontsForView:(UIView *)view skippingDescendantsOfView:(UIView * _Nullable)skipRoot;

/**
 * 获取当前应用设置的语言代码
 * @return 语言代码，如 "zh-Hans", "en", "zh-Hant"，如果未设置则返回 nil（跟随系统）
 */
+ (NSString *)getAppLanguage;

/**
 * 设置应用语言
 * @param languageCode 语言代码，如 "zh-Hans", "en", "zh-Hant"，传 nil 表示跟随系统
 */
+ (void)setAppLanguage:(NSString *)languageCode;

/**
 * 初始化应用语言设置（应在应用启动时调用）
 */
+ (void)initializeAppLanguage;

//+ (void)showDialog:(NSString*)title message:(NSString*)message;
//+ (void)showDialog:(NSString*)title message:(NSString*)message btnCancel:(NSString*)cancel btnOK:(NSString*)ok withDelegate:(id<UIAlertViewDelegate>)delegate;

//+ (NSDate*) updateDate:(NSDate*)date hour:(int)h minute:(int)m second:(int)sec;

//+ (NSMutableAttributedString *)getAttributedText:(NSString *)content contentColor:(UIColor*)contentColor contentFontSize:(int)contentFontSize unit:(NSString*)unit
//                                       unitColor:(UIColor*)unitColor unitFontSize:(int)unitFontSize;
//+ (void)addCorner:(UIView*)view;
//+ (void)addAvaterCorner:(UIView*)userhead;
//+ (void)ajdustScrollViewBaseOnScreenHeight:(UIScrollView*)scrollView;

/**
 获取本地沙盒存储的图片.

 @param imageFilePath 图片文件的完整路径
 @return 返回nil表示文件不存在或读取失败，否则返回图片对象
 */
+ (UIImage *)loadImage:(NSString *)imageFilePath;

/**
 缩放图片、压缩图片质量的实用方法。

 @param sourceImage 源图
 @param compressionQuality 要压缩的质量
 @param defineWidth 要缩放的最大宽度
 @param savedDir 压缩完成后保存的目录（不带“/”）
 @param savedFileName 压缩完成后要保存的文件名
 @return 返回nil表示压缩过程中出错了，否则返回的是压缩完成后的新文件完整文件路径
 */
+ (NSString *)imageCompressForQualityAndWidth:(UIImage *)sourceImage
                                targetQuality:(CGFloat)compressionQuality
                                  targetWidth:(CGFloat)defineWidth
                                    saveToDir:(NSString *)savedDir
                                    savedName:(NSString *)savedFileName;

/**
 按指定质量压缩图片。

 @param sourceImage 源图
 @param compressionQuality 压缩质量（0~1.0的值）
 @return 压缩后的图片
 */
+ (NSData *)imageCompressForQuality:(UIImage *)sourceImage targetQuality:(CGFloat)compressionQuality;

/**
 按指定宽度等比缩放图片。

 @param sourceImage 源图
 @param defineWidth 指定宽度
 @return 缩放后的图片
 */
+ (UIImage *)imageCompressForWidthScale:(UIImage *)sourceImage targetWidth:(CGFloat)defineWidth;

/**
 * 主 Tab 根页导航栏左侧纯文字（无 iOS 26 玻璃胶囊时的常见共享底），复用与 Tab 相同的 Localizable key（如 main_tabs_title_wallet、main_tabs_title_more）。
 */
+ (UIBarButtonItem *)rb_leftPlainTitleBarButtonItemForMainTabWithLocalizedKey:(NSString *)key;

@end
