//telegram @wz662
#import <UIKit/UIKit.h>
#import "RBImagePickerWrapper.h"

@interface PhotosViewController : UIViewController<UICollectionViewDataSource,UICollectionViewDelegate,UICollectionViewDelegateFlowLayout, RBImagePickerCompleteDelegate>

@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;
/* 表格数据为空时显示的提示UI */
@property (weak, nonatomic) IBOutlet UIView *layoutTableEmptyHint;

@property (weak, nonatomic) IBOutlet UIButton *btnUpload;

/** 按钮区域父布局的高度约束（当不显示按钮时，设置本值设为0即可） */
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *heightConstraintOfBtnContainer;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil withUid:(NSString *)photoOfUid canMgr:(BOOL)canMgr;

/** 手机相册模式：上传走 PhoneAlbumUploader，列表/删除使用 res_type=PROFILE_REST_RES_TYPE_PHONE_ALBUM（需服务端支持） */
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil withUid:(NSString *)photoOfUid canMgr:(BOOL)canMgr phoneAlbumMode:(BOOL)phoneAlbumMode;

@end
