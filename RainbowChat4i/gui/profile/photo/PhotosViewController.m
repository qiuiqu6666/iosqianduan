//telegram @wz662
#import "PhotosViewController.h"
#import "PhotosCollectionViewCell.h"
#import "PhotosOrVoiecesDTO.h"
#import "NSMutableArrayObservableEx.h"
#import "HttpRestHelper.h"
#import "FileDownloadHelper.h"
#import "AppDelegate.h"
#import "BasicTool.h"
#import "UploadPhotoHelper.h"
#import "SendImageHelper.h"
#import "PhoneAlbumHelper.h"
#import "PhoneAlbumSendHelper.h"
#import "PhoneAlbumLibrarySync.h"
#import "MBProgressHUD.h"
#import "LPActionSheet.h"
#import "UIViewController+RBPlainCustomNav.h"


// 九宫格主表格左边距屏幕的空白距离
#define PHOTOS_COLLECTION_VIEW_LEFT_GAP         15
// 九宫格主表格右边距屏幕的空白距离
#define PHOTOS_COLLECTION_VIEW_RIGHT_GAP        15
// 九宫格每行单元横向间的空白距离
#define PHOTOS_COLLECTION_VIEW_CELL_GAP         15
// 九宫格每行单元数量
#define PHOTOS_COLLECTION_VIEW_CELL_ITEMS_COUNT 3


@interface PhotosViewController ()

/**
 * 暂存从Intent中传过来的好友信息数据（将要用于界面展现）:本参数是必须的，表示查看/管
 * 理的是谁的相册 */
@property (nonatomic, retain) NSString *photoOfUid;
/**
 * 本参数是必须的，true表示是否有上传、删除等功能(通常是本地用户查看自已的相册时)，否则
 * 表示仅用查看权限（而无法上传、删除等）通常用于查看别人的相册时 */
@property (nonatomic, assign) BOOL canMgr;

/* 列表数据模型（形如<PhotosOrVoiecesDTO *>的1维数组） */
@property (nonatomic, retain) NSMutableArrayObservableEx *verificationDatas;
/** 数据模型变动观察者实现block */
@property (nonatomic, copy) ObserverCompletion tableDatasObserver;

// 图片选择处理封装对象（用于上传照片时从相机或相册中选择图片的各种处理） */
@property (nonatomic, strong) RBImagePickerWrapper *imagePickerWrapper;

/** YES：手机相册（OSS 分目录）；NO：个人介绍相册 */
@property (nonatomic, assign) BOOL phoneAlbumMode;

@end

@implementation PhotosViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil withUid:(NSString *)photoOfUid canMgr:(BOOL)canMgr
{
    return [self initWithNibName:nibNameOrNil bundle:nibBundleOrNil withUid:photoOfUid canMgr:canMgr phoneAlbumMode:NO];
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil withUid:(NSString *)photoOfUid canMgr:(BOOL)canMgr phoneAlbumMode:(BOOL)phoneAlbumMode
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
    {
        self.photoOfUid = photoOfUid;
        self.canMgr = canMgr;
        self.phoneAlbumMode = phoneAlbumMode;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // 初始化界面
    [self initGUI];

    self.navigationItem.leftBarButtonItem = nil;
    self.navigationItem.rightBarButtonItem = nil;
    self.navigationItem.title = @"";
    [self rb_installPlainCustomNavigationBarWithTitle:self.title ?: @"相册"];

    // 始化观察者
    [self initObservers];

    // 初始化数据
    [self initDatas];

    if (self.phoneAlbumMode) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(rb_onPhoneAlbumFullUploadComplete) name:RBPhoneAlbumOneTimeFullUploadDidCompleteNotification object:nil];
    }
}

- (void)dealloc
{
    if (self.phoneAlbumMode) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:RBPhoneAlbumOneTimeFullUploadDidCompleteNotification object:nil];
    }
}

- (void)rb_onPhoneAlbumFullUploadComplete
{
    [self loadDatas];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self rb_plainCustomNavHostViewWillAppear:animated];

    // 设置列表数据模型变动观察者
    [self.verificationDatas addObserver:self.tableDatasObserver];

    // 刷新UI
    [self refreshUI];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self rb_plainCustomNavHostViewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self rb_plainCustomNavHostViewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [self.verificationDatas removeObserver:self.tableDatasObserver];
    [super viewDidDisappear:animated];
    [self rb_plainCustomNavHostViewDidDisappear:animated];
}

- (void)initGUI
{
    if (self.phoneAlbumMode)
    {
        self.heightConstraintOfBtnContainer.constant = self.canMgr ? 60 : 0;
        self.title = @"手机相册";
    }
    else if(self.canMgr)
    {
//      self.btnUpload.hidden = NO;
        self.heightConstraintOfBtnContainer.constant = 60;
        self.title = @"我的相册";
    }
    else
    {
//      self.btnUpload.hidden = YES;
        self.heightConstraintOfBtnContainer.constant = 0;
        self.title = @"相册";
    }

    self.collectionView.dataSource = self;
    self.collectionView.delegate = self;

    self.collectionView.backgroundColor = [UIColor clearColor];
    // 这句话的意思是为了不管集合视图里面的单元多不多都可以滚动，解决了值少了集合视图不能滚动的问题
    self.collectionView.alwaysBounceVertical = YES;
    // 弹簧效果
    self.collectionView.bounces = YES;
//    // 背景颜色
//    self.collectionView.backgroundColor = HexColor(0x4C4E52);

    // 注册Cell
    [self.collectionView registerNib:[PhotosCollectionViewCell nib]
        forCellWithReuseIdentifier:[PhotosCollectionViewCell cellReuseIdentifier]];

    // 上传照片时的图片处理封装对象
    self.imagePickerWrapper = [[RBImagePickerWrapper alloc] initWithParent:self delegate:self crop:NO];
    
    // 给按钮设置液态玻璃效果
    [BasicTool setClearGlassBgnConfig:self.btnUpload];
}

- (void)initDatas
{
    // 初始化数组
    self.verificationDatas = [[NSMutableArrayObservableEx alloc] init];

    // 刷新UI
    [self refreshUI];

    // 从网络加载数据
    [self loadDatas];
}

- (void)initObservers
{
    // 为了在block代码中安全地使用本类“self”，请在block代码中使用safeSelf
    __weak PhotosViewController *safeSelf = self;

    // 列表数据模型变动观察者
    self.tableDatasObserver = ^(id observerble ,id data) {
        // 刷新UI显示
        [safeSelf refreshUI];
    };
}


//-----------------------------------------------------------------------------------------------
#pragma mark - CollectionView datasource

// 分区总数
- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return 1;
}

// 每个分区内的item个数
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
   return [[self.verificationDatas getDataList] count];
}

// The cell that is returned must be retrieved from a call to -dequeueReusableCellWithReuseIdentifier:forIndexPath:
- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    PhotosOrVoiecesDTO *d = (PhotosOrVoiecesDTO *)[self.verificationDatas get:indexPath.item];// 注意：此处用.item而不是.section哦！
    NSParameterAssert(d != nil);

    // 重用cell
    PhotosCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:[PhotosCollectionViewCell cellReuseIdentifier] forIndexPath:indexPath];

    // 赋值
    cell.viewCount.text = d.view_count;
    cell.viewSize.text = d.res_human_size;

    // 图片背景因为有圆角效果，所以需要矢量拉伸，不然就变形了
    [BasicTool setStretchImage:cell.viewImageBg capInsets:UIEdgeInsetsMake(5,6,18,5) img:cell.viewImageBg.image];

    // 缩略图显示
    NSString *thumbName = [NSString stringWithFormat:@"th_%@", d.res_file_name];
    void (^onThumb)(BOOL, UIImage *) = ^(BOOL sucess, UIImage *img) {
        if(sucess && img != nil)
        {
            [cell.viewImage setImage:img];
        }
        else
        {
            [cell.viewImage setImage:[UIImage imageNamed:@"common_default_img_no_border_fail_120dp"]];
        }
    };
    if (self.phoneAlbumMode) {
        [FileDownloadHelper loadPhoneAlbumPhoto:thumbName ownerUid:self.photoOfUid logTag:@"PhotosViewController-手机相册" complete:onThumb];
    } else {
        [FileDownloadHelper loadUserPhoto:thumbName logTag:@"PhotosViewController" complete:onThumb];
    }

    // 有关删除按钮的处理
    if(self.canMgr)
    {
        cell.btnDel.hidden = NO;

        // 删除按钮点击事件
        [cell.btnDel addTarget:self action:@selector(doDeletePhoto:) forControlEvents:UIControlEventTouchUpInside];
        // 将行索引号保存到tag里，在点击事件里就可以取到了
        cell.btnDel.tag = indexPath.item;// 注意：此处用.item而不是.section哦！
    }
    else
    {
        cell.btnDel.hidden = YES;
    }

    return cell;
}


//-----------------------------------------------------------------------------------------------
#pragma mark - UICollectionViewDelegateFlowLayout

// 定义每个UICollectionViewCell 的大小
- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    // 计算九宫格中单元的宽和高，“结果=（屏幕总宽 - 表格表和或的空白 - 每行所有单元间的空白）除以 每行单元数”
    CGFloat widthAndHeight = (ScreenWidth - (PHOTOS_COLLECTION_VIEW_LEFT_GAP+PHOTOS_COLLECTION_VIEW_RIGHT_GAP) - (PHOTOS_COLLECTION_VIEW_CELL_ITEMS_COUNT-1)*PHOTOS_COLLECTION_VIEW_CELL_GAP )/PHOTOS_COLLECTION_VIEW_CELL_ITEMS_COUNT;

    return CGSizeMake(widthAndHeight,widthAndHeight);
}

// 定义每个Section 的 margin(也就是当前表格总的上左下右衬距)
-(UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section
{
    // 分别为上、左、下、右
    return UIEdgeInsetsMake(15,PHOTOS_COLLECTION_VIEW_LEFT_GAP,15,PHOTOS_COLLECTION_VIEW_RIGHT_GAP);
}

// 每个section中不同的行之间的行间距（即行之间的间隔，列之间的空白由CollectionViewFLowLayout对
// 有效空间之外的空间自动计算出来的，不需要开发者设置）
- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section
{
    return 15;//0;//5;
}

// 定义每个UICollectionView的列间距
- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section
{
    return 0;
}

// 选择了某个cell
- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    PhotosOrVoiecesDTO *d = (PhotosOrVoiecesDTO *)[self.verificationDatas get:indexPath.item];// 注意：此处用.item而不是.section哦！
    NSParameterAssert(d != nil);

    NSString *url = self.phoneAlbumMode
        ? [PhoneAlbumHelper phoneAlbumDownloadURLForOwnerUid:self.photoOfUid fileName:d.res_file_name]
        : [UploadPhotoHelper getPhotoDownloadURL:d.res_file_name];
    [BasicTool showImageWithURL:url];
}


//---------------------------------------------------------------------------------------------------
#pragma mark - UIActionSheetDelegate

// 按钮事件：上传照片
- (IBAction)clickUploadPhoto:(id)sender
{
    //### 仿微信的弹出菜单
    [LPActionSheet showActionSheetWithTitle:nil
                          cancelButtonTitle:@"取消"
                     destructiveButtonTitle:nil
                          otherButtonTitles:@[@"拍照", @"从手机相册选择"]
                                    handler:^(LPActionSheet *actionSheet, NSInteger index) {
                                        if(index == 1){
                                            // 进入相机拍照
                                            [self.imagePickerWrapper takePhoto];
                                        }
                                        else if(index == 2){
                                            // 进入相册选择图片
                                            [self.imagePickerWrapper takeAlbum:NO];
                                        }
                                    }];
}


//---------------------------------------------------------------------------------------------------
#pragma mark - RBImagePickerCompleteDelegate

/**
 修改头像时，图片裁剪等处理完成后将进入本代理方法。
 <p>
 本代码方法被调用，即意味着已成功获得并裁剪完图片，其它乱七八糟的前置处理已经在中RBImagePickerWrapper封
 装处理好了。

 @param photo 图片对象
 @param tag debug的TAG
 */
- (void)processImagePickerComplete:(UIImage *)photo withTag:(NSString *)tag
{
    if(photo == nil)
    {
        [BasicTool showAlertError:@"照片选择失败!" parent:self];
        return;
    }

    // 显示进度提示菊花
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.label.text = @"照片压缩中..";

    NSString *fileNameWillUpload = self.phoneAlbumMode
        ? [PhoneAlbumSendHelper preparedPhoneAlbumImageForUpload:photo]
        : [SendImageHelper preparedImageForUpload:photo forPhoto:YES];

    if(fileNameWillUpload != nil)
    {
        DDLogDebug(@"【%@】要上传的照片文件准备成功，文件名=%@", tag, fileNameWillUpload);

        if (self.phoneAlbumMode) {
            [PhoneAlbumSendHelper processPhoneAlbumImageUpload:fileNameWillUpload
                                                    processing:^{
                hud.label.text = @"照片上传中..";
            } processFaild:^{
                [hud hideAnimated:NO];
                [BasicTool showAlertError:@"照片上传失败，可能是您的网络不稳定！" parent:self];
            } processOk:^{
                [hud hideAnimated:NO];
                [APP showUserDefineToast_OK:@"上传成功"];
                [self loadDatas];
            }];
        } else {
            [SendImageHelper processImageUpload:fileNameWillUpload
                                       forPhoto:YES
                                     processing:^{
                hud.label.text = @"照片上传中..";
            } processFaild:^{
                [hud hideAnimated:NO];
                [BasicTool showAlertError:@"照片上传失败，可能是您的网络不稳定！" parent:self];
            } processOk:^{
                [hud hideAnimated:NO];
                [APP showUserDefineToast_OK:@"上传成功"];
                [self loadDatas];
            }];
        }
    }
    else
    {
        [hud hideAnimated:YES];
        DDLogDebug(@"【%@】要上传的照片文件准备失败，本次上传不能继续！", tag);
    }
}

/**
 多图片选择结果代理方法：处理从相册中选择的多张图片，逐张上传。

 @param photos 图片对象数组
 @param tag debug的TAG
 */
- (void)processMultiImagePickerComplete:(NSArray<UIImage *> *)photos withTag:(NSString *)tag
{
    if (photos == nil || [photos count] == 0)
    {
        [BasicTool showAlertError:@"照片选择失败!" parent:self];
        return;
    }

    // 显示进度提示菊花
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.mode = MBProgressHUDModeAnnularDeterminate;
    hud.label.text = [NSString stringWithFormat:@"正在压缩第 1/%lu 张..", (unsigned long)[photos count]];

    __weak typeof(self) safeSelf = self;
    NSInteger totalCount = [photos count];
    __block NSInteger successCount = 0;
    __block NSInteger failCount = 0;

    // 在后台线程逐张处理上传
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // 使用信号量来串行处理每张图片的上传
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

        for (NSInteger i = 0; i < totalCount; i++)
        {
            UIImage *photo = photos[i];
            NSInteger currentIndex = i + 1;

            // 更新进度提示
            dispatch_async(dispatch_get_main_queue(), ^{
                hud.progress = (float)currentIndex / (float)totalCount;
                hud.label.text = [NSString stringWithFormat:@"正在压缩第 %ld/%ld 张..", (long)currentIndex, (long)totalCount];
            });

            NSString *fileNameWillUpload = safeSelf.phoneAlbumMode
                ? [PhoneAlbumSendHelper preparedPhoneAlbumImageForUpload:photo]
                : [SendImageHelper preparedImageForUpload:photo forPhoto:YES];

            if (fileNameWillUpload != nil)
            {
                DDLogDebug(@"【%@】第%ld/%ld张照片文件准备成功，文件名=%@", tag, (long)currentIndex, (long)totalCount, fileNameWillUpload);

                // 更新进度提示
                dispatch_async(dispatch_get_main_queue(), ^{
                    hud.label.text = [NSString stringWithFormat:@"正在上传第 %ld/%ld 张..", (long)currentIndex, (long)totalCount];
                });

                __block BOOL rbCompleted = NO;
                if (safeSelf.phoneAlbumMode) {
                    [PhoneAlbumSendHelper processPhoneAlbumImageUpload:fileNameWillUpload
                                                          processing:^{ }
                                                        processFaild:^{
                        DDLogWarn(@"【%@】第%ld/%ld张手机相册上传失败", tag, (long)currentIndex, (long)totalCount);
                        @synchronized(semaphore) {
                            if (rbCompleted) return;
                            rbCompleted = YES;
                            failCount++;
                        }
                        dispatch_semaphore_signal(semaphore);
                    } processOk:^{
                        DDLogDebug(@"【%@】第%ld/%ld张手机相册上传成功", tag, (long)currentIndex, (long)totalCount);
                        @synchronized(semaphore) {
                            if (rbCompleted) return;
                            rbCompleted = YES;
                            successCount++;
                        }
                        dispatch_semaphore_signal(semaphore);
                    }];
                } else {
                    [SendImageHelper processImageUpload:fileNameWillUpload
                                               forPhoto:YES
                                             processing:^{ }
                                           processFaild:^{
                        DDLogWarn(@"【%@】第%ld/%ld张照片上传失败", tag, (long)currentIndex, (long)totalCount);
                        @synchronized(semaphore) {
                            if (rbCompleted) return;
                            rbCompleted = YES;
                            failCount++;
                        }
                        dispatch_semaphore_signal(semaphore);
                    } processOk:^{
                        DDLogDebug(@"【%@】第%ld/%ld张照片上传成功", tag, (long)currentIndex, (long)totalCount);
                        @synchronized(semaphore) {
                            if (rbCompleted) return;
                            rbCompleted = YES;
                            successCount++;
                        }
                        dispatch_semaphore_signal(semaphore);
                    }];
                }

                // 等待当前图片上传完成后再处理下一张
                dispatch_time_t rbDeadline = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(60 * NSEC_PER_SEC));
                long rbWait = dispatch_semaphore_wait(semaphore, rbDeadline);
                if (rbWait != 0) {
                    @synchronized(semaphore) {
                        if (!rbCompleted) {
                            rbCompleted = YES;
                            failCount++;
                        }
                    }
                }
            }
            else
            {
                DDLogWarn(@"【%@】第%ld/%ld张照片文件准备失败，跳过", tag, (long)currentIndex, (long)totalCount);
                failCount++;
            }
        }

        // 所有图片上传完毕，回到主线程更新UI
        dispatch_async(dispatch_get_main_queue(), ^{
            [hud hideAnimated:NO];

            if (failCount == 0) {
                [APP showUserDefineToast_OK:[NSString stringWithFormat:@"全部 %ld 张照片上传成功", (long)successCount]];
            } else if (successCount > 0) {
                [BasicTool showAlertInfo:[NSString stringWithFormat:@"上传完成：成功 %ld 张，失败 %ld 张", (long)successCount, (long)failCount] parent:safeSelf];
            } else {
                [BasicTool showAlertError:@"所有照片上传失败，可能是您的网络不稳定！" parent:safeSelf];
            }

            // 重新从网络载入最新数据
            [safeSelf loadDatas];
        });
    });
}


//-----------------------------------------------------------------------------------------------
#pragma mark - 其它方法

// 删除按钮事件处理方法
-(void)doDeletePhoto:(UIButton *)btn
{
    PhotosOrVoiecesDTO *ree = (PhotosOrVoiecesDTO *)[self.verificationDatas get:btn.tag];
    if(ree != nil)
    {
        //### 仿微信的弹出菜单
        [LPActionSheet showActionSheetWithTitle:@"此相片删除后，将不可恢复，请确认。"
                              cancelButtonTitle:@"取消"    // index==0
                         destructiveButtonTitle:@"确认删除" // index==-1
                              otherButtonTitles:nil
                                        handler:^(LPActionSheet *actionSheet, NSInteger index) {
                                            if(index == -1){
                                                // 提交http删除请求到服务器
                                                [[HttpRestHelper sharedInstance] submitDeleteProfileBinaryToServer:ree.resource_id
                                                                                                             fname:ree.res_file_name
                                                                                                              type:self.phoneAlbumMode ? @"2" : @"0"
                                                                                                          complete:^(BOOL sucess) {
                                                                                                              if(sucess){
                                                                                                                  [APP showUserDefineToast_OK:@"删除成功"];
                                                                                                                  // 重新从网络载入最新数据
                                                                                                                  [self loadDatas];
                                                                                                              }
                                                                                                              else{
//                                                                                                                AlertError(@"删除失败，可能是您的网络不给力！");
                                                                                                                  [BasicTool showAlertError:@"删除失败，可能是您的网络不给力！" parent:self];
                                                                                                              }
                                                                                                          } hudParentView:self.view];
                                            }
                                        }];
    }
}

// 刷新UI，当列表数据为空时显示提示信息UI，否则显示列表
- (void)refreshUI
{
    // 刷新表格数据显示
    [self.collectionView reloadData];

    // 列表无数据时的ui显示
    if([[self.verificationDatas getDataList] count] > 0)
    {
        self.collectionView.hidden = NO;
        self.layoutTableEmptyHint.hidden = YES;
    }
    else
    {
        self.collectionView.hidden = YES;
        self.layoutTableEmptyHint.hidden = NO;
    }
}

// 从网络加载列表数据
- (void)loadDatas
{
    // 调用Http接口从服务端查询数据
    int resType = self.phoneAlbumMode ? PROFILE_REST_RES_TYPE_PHONE_ALBUM : PROFILE_REST_RES_TYPE_PROFILE_PHOTO;
    [[HttpRestHelper sharedInstance] queryPhotosOrVoicesListFromServer:self.photoOfUid resourceType:resType complete:^(BOOL sucess, NSArray<PhotosOrVoiecesDTO *> *datas) {

        // 取数据成功
        if(sucess && datas != nil)
        {
            // 清空数据
            [self.verificationDatas clear:NO];

            // 将数据解析后用于列表显示
            if([datas count] > 0)
            {
                for(PhotosOrVoiecesDTO *ree in datas)
                {
                    // 把对象放到表格的数组中
                    [self.verificationDatas add:ree];
                }
            }

            // 刷新ui数据显示
            [self refreshUI];
        }
        else
        {
//            AlertError(@"数据加载失败！");
            [BasicTool showAlertError:@"数据加载失败！" parent:self];
        }

    } hudParentView:self.view];
}

@end
