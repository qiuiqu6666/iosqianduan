// 全屏预览用户头像：图片用大图查看，视频用 RBAvatarView 播放
#import "RBAvatarPreviewViewController.h"
#import "RBAvatarView.h"
#import "FileDownloadHelper.h"

@interface RBAvatarPreviewViewController ()
@property (nonatomic, copy) NSString *uid;
@property (nonatomic, copy) NSString *avatarFileName;
@property (nonatomic, strong) RBAvatarView *avatarView;
@property (nonatomic, strong) UIImageView *imageView;
@end

@implementation RBAvatarPreviewViewController

- (instancetype)initWithUid:(NSString *)uid avatarFileName:(NSString *)fileName
{
    self = [super init];
    if (self) {
        _uid = [uid copy];
        _avatarFileName = [fileName copy];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissTap)];
    [self.view addGestureRecognizer:tap];

    CGFloat side = MIN(self.view.bounds.size.width, self.view.bounds.size.height) * 0.85f;
    CGRect frame = CGRectMake((self.view.bounds.size.width - side) / 2,
                              (self.view.bounds.size.height - side) / 2,
                              side, side);

    // 不支持视频头像，仅图片头像预览
    _imageView = [[UIImageView alloc] initWithFrame:frame];
    _imageView.contentMode = UIViewContentModeScaleAspectFill;
    _imageView.clipsToBounds = YES;
    _imageView.layer.cornerRadius = 0;
    _imageView.layer.masksToBounds = YES;
    [self.view addSubview:_imageView];
    if (![FileDownloadHelper isVideoAvatarFileName:self.avatarFileName]) {
        __weak typeof(self) wself = self;
        [FileDownloadHelper loadUserAvatarWithFileName:self.avatarFileName uid:self.uid logTag:@"RBAvatarPreview" complete:^(BOOL sucess, UIImage *img) {
            if (wself && wself.imageView && sucess && img) {
                wself.imageView.image = img;
            }
        }];
    }
}

- (void)dismissTap
{
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

@end
