//telegram @wz662
#import <UIKit/UIKit.h>

@interface AddMethodViewController : UIViewController

/// 所有10项权限设置（从父页面传入，子页面修改后一起保存）
@property (nonatomic, assign) int requireVerification;
@property (nonatomic, assign) int allowSearchByEmail;
@property (nonatomic, assign) int allowSearchByUid;
@property (nonatomic, assign) int allowSearchByPhone;
@property (nonatomic, assign) int allowViewAlbum;
@property (nonatomic, assign) int allowViewVoice;
@property (nonatomic, assign) int allowReadReceipt;
@property (nonatomic, assign) int allowAddByCard;
@property (nonatomic, assign) int allowAddByGroup;
@property (nonatomic, assign) int allowAddByQrcode;

@end
