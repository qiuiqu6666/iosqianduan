//telegram @wz662
#import <UIKit/UIKit.h>
#import "IQAudioRecorderViewController.h"
#import <AVFoundation/AVFoundation.h>

@interface VoicesViewController : UIViewController<UICollectionViewDataSource,UICollectionViewDelegate,UICollectionViewDelegateFlowLayout,IQAudioRecorderViewControllerDelegate,AVAudioPlayerDelegate>

@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;
/* 表格数据为空时显示的提示UI */
@property (weak, nonatomic) IBOutlet UIView *layoutTableEmptyHint;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil withUid:(NSString *)voiceOfUid canMgr:(BOOL)canMgr;

@end
