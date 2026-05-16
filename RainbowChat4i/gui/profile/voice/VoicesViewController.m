//telegram @wz662
#import "VoicesViewController.h"
#import "NSMutableArrayObservableEx.h"
#import "VoicesCollectionViewCell.h"
#import "PhotosOrVoiecesDTO.h"
#import "HttpRestHelper.h"
#import "AppDelegate.h"
#import "UploadPVoiceHelper.h"
#import "MBProgressHUD.h"
#import "SendVoiceHelper.h"
#include "amrFileCodec.h"
#import "FileDownloadHelper.h"
#import "PromtHelper.h"
#import "FileTool.h"
#import "LPActionSheet.h"
#import "UIViewController+RBPlainCustomNav.h"


// 九宫格主表格左边距屏幕的空白距离
#define VOICES_COLLECTION_VIEW_LEFT_GAP         15
// 九宫格主表格右边距屏幕的空白距离
#define VOICES_COLLECTION_VIEW_RIGHT_GAP        15
// 九宫格每行单元横向间的空白距离
#define VOICES_COLLECTION_VIEW_CELL_GAP         15
// 九宫格每行单元数量
#define VOICES_COLLECTION_VIEW_CELL_ITEMS_COUNT 3


@interface VoicesViewController ()

/**
 * 暂存从Intent中传过来的好友信息数据（将要用于界面展现）:本参数是必须的，表示查看/管
 * 理的是谁的语音 */
@property (nonatomic, retain) NSString *photoOfUid;
/**
 * 本参数是必须的，true表示是否有上传、删除等功能(通常是本地用户查看自已的语音时)，否则
 * 表示仅用查看权限（而无法上传、删除等）通常用于查看别人的语音时 */
@property (nonatomic, assign) BOOL canMgr;
/** 列表数据模型（形如<PhotosOrVoiecesDTO *>的1维数组） */
@property (nonatomic, retain) NSMutableArrayObservableEx *verificationDatas;
/** 数据模型变动观察者实现block */
@property (nonatomic, copy) ObserverCompletion tableDatasObserver;

//-------------------------------------- 以下属性仅用于播放时 START
// 仅用于播放时：音频播放器对象
@property (nonatomic, strong) AVAudioPlayer *play_audioPlayer;
// 仅用于播放时：加载的音频数据（不播放的时候本对象为nil，播放时才加载并设置，播放完成立即置nil，释放资源）
@property (nonatomic, strong) NSData *play_audioData;
// 仅用于播放时：当前正在播放中的表格单元实体对象句柄
@property (nonatomic, strong) PhotosOrVoiecesDTO *play_currentPlayingCell;
// 仅用于播放时：语音播放动画数组
@property (nonatomic, strong) NSArray *play_animationArray;
//-------------------------------------- 以下属性仅用于播放时 END

@end

@implementation VoicesViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil withUid:(NSString *)voiceOfUid canMgr:(BOOL)canMgr
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
    {
        self.photoOfUid = voiceOfUid;
        self.canMgr = canMgr;
    }
    return self;
}

- (void)dealloc
{
    _play_audioData = nil;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // 初始化界面
    [self initGUI];

    // 始化观察者
    [self initObservers];

    // 初始化数据
    [self initDatas];

    NSString *navTitle = self.title ?: @"";
    if (self.canMgr) {
        UIImage *addImg = [UIImage imageNamed:@"main_more_profile_voice_add_btn_nor"];
        [self rb_installPlainCustomNavigationBarWithTitle:navTitle
                                         rightButtonImage:addImg
                                                   target:self
                                                   action:@selector(doAddVoice)];
    } else {
        [self rb_installPlainCustomNavigationBarWithTitle:navTitle];
    }
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
    // 取消设置列表数据模型变动观察者
    [self.verificationDatas removeObserver:self.tableDatasObserver];

    [super viewDidDisappear:animated];
    [self rb_plainCustomNavHostViewDidDisappear:animated];
}

- (void)initGUI
{
    if(self.canMgr)
    {
        self.title = @"我的声音";
    }
    else
    {
        self.title = @"声音";
    }

    self.collectionView.dataSource = self;
    self.collectionView.delegate = self;

    self.collectionView.backgroundColor = [UIColor clearColor];
    // 这句话的意思是为了不管集合视图里面的单元多不多都可以滚动，解决了值少了集合视图不能滚动的问题
    self.collectionView.alwaysBounceVertical = YES;
    // 弹簧效果
    self.collectionView.bounces = YES;
    // 背景颜色
//    self.collectionView.backgroundColor = HexColor(0x4C4E52);

    // 注册Cell
    [self.collectionView registerNib:[VoicesCollectionViewCell nib]
          forCellWithReuseIdentifier:[VoicesCollectionViewCell cellReuseIdentifier]];
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
    __weak VoicesViewController *safeSelf = self;

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
    VoicesCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:[VoicesCollectionViewCell cellReuseIdentifier] forIndexPath:indexPath];

    // 赋值
    cell.viewCount.text = d.view_count;
    cell.viewSize.text = d.res_human_size;

    // 从文件名中解析出语音时长（单位：秒），根据语音文件的生成规则，时长是包含在文件名里的
    int duration = [TimeTool getDurationFromVoiceFileName:d.res_file_name];
    // 显示语音时长（形如：65''，表示65秒）
    cell.durationLabel.text = [TimeTool getVoiceDurationHuman:duration];

    // 有关删除按钮的处理
    if(self.canMgr)
    {
        // 利用autolayout的属性，设置删除按钮的可见性(为了xib ui设计的一致性，此宽度请与.xib里保持一致哦)
//      cell.cellDeleteLayoutWidthConstraint.constant = 30;
        cell.btnDel.hidden = NO;

        // 删除按钮点击事件
        [cell.btnDel addTarget:self action:@selector(doDeleteVoice:) forControlEvents:UIControlEventTouchUpInside];
        // 将行索引号保存到tag里，在点击事件里就可以取到了
        cell.btnDel.tag = indexPath.item;// 注意：此处用.item而不是.section哦！
    }
    else
    {
        // 利用autolayout的属性，设置删除按钮的可见性
//      cell.cellDeleteLayoutWidthConstraint.constant = 0;
        cell.btnDel.hidden = YES;
    }

    // 用于音频播放时：显示文件下载进度（如果需要显示的话）
    int progressStatus = d.downloadStatus.status;
    switch(progressStatus)
    {
        case VoiceDownloadStatus_NONE:
        case VoiceDownloadStatus_PROCESS_OK:
        case VoiceDownloadStatus_PROCESS_FAILD:
//            viewProgressBar.setVisibility(View.GONE);
            cell.progressView.hidden = YES;
            break;
        case VoiceDownloadStatus_PROCESSING:
            // 设置进度条可见
            cell.progressView.hidden = NO;
            // 刷新进度值显示
            cell.progressView.progress = d.downloadStatus.progress;
            break;
    }

    // 用于音频播放时：显示播放动画（如果该cell正在被播放中的话）
    if([self isCurrentPlayingCell:d])// && [self isAudioPlaying])
    {
        NSLog(@"【个人语音介绍-播放】文件：%@正在播放中，动画走起！！", d.res_file_name);

        if(self.play_animationArray == nil)
        {
            self.play_animationArray = [NSArray arrayWithObjects:
                              [UIImage imageNamed:@"main_more_profile_pvoice_anim_icons2"],
                              [UIImage imageNamed:@"main_more_profile_pvoice_anim_icons3"],
                              [UIImage imageNamed:@"main_more_profile_pvoice_anim_icons4"],
                              nil];
        }

        cell.playImage.animationImages = self.play_animationArray;
        // 设置执行一次完整动画的时长（单位：秒）
        cell.playImage.animationDuration = 0.35 * 3;//1.0;//
        // 动画重复次数 （0为重复播放）
        cell.playImage.animationRepeatCount = 0;

        // 设置初始静态图标
        [cell.playImage setImage:[UIImage imageNamed:@"main_more_profile_pvoice_gridview_item_voice_icon"]];

        // 显示播放动画
        [cell.playImage startAnimating];
    }
    // 否则不是处于“播放中”，则尝试恢复它的ui显示为正常状态即可
    else
    {
        NSLog(@"【个人语音介绍-播放】文件：%@未播放", d.res_file_name);

        // 确保先stop ，否则正在动画中时此时设置图片则只会停在动画的最后一帧
        if([cell.playImage isAnimating])
            [cell.playImage stopAnimating];

        // 设置初始静态图标
        [cell.playImage setImage:[UIImage imageNamed:@"main_more_profile_pvoice_gridview_item_voice_icon"]];
    }

    return cell;
}


//-----------------------------------------------------------------------------------------------
#pragma mark - UICollectionViewDelegateFlowLayout

// 定义每个UICollectionViewCell 的大小
- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    // 计算九宫格中单元的宽和高，“结果=（屏幕总宽 - 表格表和或的空白 - 每行所有单元间的空白）除以 每行单元数”
    CGFloat width = (ScreenWidth - (VOICES_COLLECTION_VIEW_LEFT_GAP+VOICES_COLLECTION_VIEW_RIGHT_GAP) - (VOICES_COLLECTION_VIEW_CELL_ITEMS_COUNT-1)*VOICES_COLLECTION_VIEW_CELL_GAP )/VOICES_COLLECTION_VIEW_CELL_ITEMS_COUNT;

    return CGSizeMake(width, 100);
}

// 定义每个Section 的 margin(也就是当前表格总的上左下右衬距)
-(UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section
{
    // 分别为上、左、下、右
    return UIEdgeInsetsMake(15,VOICES_COLLECTION_VIEW_LEFT_GAP,15,VOICES_COLLECTION_VIEW_RIGHT_GAP);
}

// 每个section中不同的行之间的行间距（即行之间的间隔，列之间的空白由CollectionViewFLowLayout对
// 有效空间之外的空间自动计算出来的，不需要开发者设置）
- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section
{
    return 15;//2;
}

// 定义每个UICollectionView的列间距
- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section
{
    return 0;
}

// 点击了某个cell，本类中将触发音频播放完整处理逻辑
- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    PhotosOrVoiecesDTO *contentData = (PhotosOrVoiecesDTO *)[self.verificationDatas get:indexPath.item];// 注意：此处用.item而不是.section哦！
    NSParameterAssert(contentData != nil);

    [self clickCellToPlay:contentData];
}


//---------------------------------------------------------------------------------------------------
#pragma mark - 音频播放相关代码及处理逻辑

// 点击九宫格后的播放全部逻辑实现方法
- (void)clickCellToPlay:(PhotosOrVoiecesDTO *)contentData
{
    NSString *audioFileName = contentData.res_file_name;
    NSLog(@"【个人语音介绍-播放】你刚点击播放的audioFileName=%@", audioFileName);

    // 如果正在点击的单元正处于”播放中“则此次点击将停止当前正在进行中的播放
    // ** 逻辑："如果点击的单元是当前正在播放中的"，本次点击只是停止播放之，播放逻辑不需要往下走了，直接return
    if([self isCurrentPlayingCell:contentData])
    {
        [self stopAudio:YES];
        return;
    }
    // 如果别的单元正在“播放中”，则本次是首先停止其它的单元的播放后，再继续走接下来的播放逻辑（此时就不需要return了）
    // ** 逻辑："虽然点击的单元不是当前播放中的但其它单元正在播放中"，都要首先停止播放之，为了保证一次至播放一个音频嘛
    else if(self.play_currentPlayingCell != nil)
    {
        [self stopAudio:YES];

        // 此处不需要return
    }

    // 开始正常播放逻辑
    {
        // 点击此单元就意味着此语音留言处于“播放中“状态（因为一次只能播放一个，所以可以
        // 作为全局变量存起来，只要表格的单元对应的是此dto就意味着它正处于”播放中“状态哦）
        [self setCurrentPlayingCell:contentData update:YES];

        // 音频文件路径
        NSString *audioFilePath = [NSString stringWithFormat:@"%@%@", [UploadPVoiceHelper getSendVoiceSavedDirHasSlash], audioFileName];
        // 文件是否已存在于本地缓存中（播放的逻辑就是如果这个文件不存在本地就从网络下载，如果已下载过就不需要重新下载，节省流量）
        BOOL exists = [FileTool fileExists:audioFilePath];

        NSLog(@"【个人语音介绍-播放】要播放的音频文件路径：%@【是否已在本地？%d】", audioFilePath, exists);

        // 文件已存在本地就直接播放
        if(exists)
        {
            // 本地文件直接播放
            @try{
                // 转码
                _play_audioData = DecodeAMRToWAVE([NSData dataWithContentsOfFile:audioFilePath]);
                // 开始播放
                [self playAudio];
            } @catch (NSException *exception){
                NSLog(@"%@",exception);
                _play_audioData = nil;
//                AlertInfo(@"语音播放失败，可能是文件已失效！");
                [BasicTool showAlertInfo:@"语音播放失败，可能是文件已失效！" parent:self];

                // 播放失败则清空播放状态
                [self clearCurrentPlayingCell:YES];
            }
        }
        // 文件不存在，则尝试从网络下载
        else
        {
            // 设置表格单元的下载状态显示
            contentData.downloadStatus.status = VoiceDownloadStatus_PROCESSING;
            [self.collectionView reloadData];

            NSString *fileDownloadURL = [UploadPVoiceHelper getVoiceDownloadURL:audioFileName];
            // 从服务器下载
            [FileDownloadHelper downloadCommonFile:fileDownloadURL
                                             toDir:[UploadPVoiceHelper getSendVoiceSavedDir]
                                                pg:^(NSProgress *dp) { // 下载进度
                                                    float pv = 1.0 * dp.completedUnitCount / dp.totalUnitCount;
                                                    dispatch_async(dispatch_get_main_queue(), ^{
                                                        contentData.downloadStatus.progress = pv;
                                                        [self.collectionView reloadData];
                                                    });
                                                } complete:^(BOOL sucess, NSURL *fileSavedPath) { // 下载完成

                                                    DDLogDebug(@"【个人语音介绍-播放】语音文件下载sucess？%d, fileSavedPath=%@", sucess, [fileSavedPath path]);

                                                    if(sucess)
                                                    {
                                                        // 更新表格单元的下载状态显示
                                                        contentData.downloadStatus.status = VoiceDownloadStatus_PROCESS_OK;
                                                        contentData.downloadStatus.progress = 1.0;
                                                        [self.collectionView reloadData];

                                                        // 下载完成后准备播放前多加一层判断：防止网络下载太慢，导致刚下载完成时，而用户
                                                        // 已经点击了其它单元了，此时再播放之前的这个文件（就是本次刚下载完成的）就不对了
                                                        if([self isCurrentPlayingCell:contentData])
                                                        {
                                                            // 下载完成后直接播放
                                                            @try{
                                                                // 转码
                                                                self.play_audioData = DecodeAMRToWAVE([NSData dataWithContentsOfFile:[fileSavedPath path]]);
                                                                // 开始播放
                                                                [self playAudio];
                                                            } @catch (NSException *exception){
                                                                NSLog(@"%@",exception);
                                                                self.play_audioData = nil;

                                                                // 播放失败则清空播放状态
                                                                [self clearCurrentPlayingCell:YES];

//                                                                AlertInfo(@"语音留言播放失败（网络下载完成后）！");
                                                                [BasicTool showAlertInfo:@"语音留言播放失败（网络下载完成后）！" parent:self];
                                                            }
                                                        }
                                                    }
                                                    else
                                                    {
//                                                        AlertInfo(@"语音留言文件下载失败！");
                                                        [BasicTool showAlertInfo:@"语音留言文件下载失败！" parent:self];

                                                        contentData.downloadStatus.status = VoiceDownloadStatus_PROCESS_FAILD;
                                                        // 播放失败则清空播放状态
                                                        [self clearCurrentPlayingCell:YES];
                                                        return;
                                                    }
                                                }];

        }
    }
}

/**
 * 当前列表单元（语音留言消息）是否处于“播放中”.
 *
 * @param entity 列表单元对象
 * @return YES表示播放中，否则处于普通状态
 */
- (BOOL) isCurrentPlayingCell:(PhotosOrVoiecesDTO *)entity
{
    return self.play_currentPlayingCell != nil && self.play_currentPlayingCell == entity;
}

// 清除当前“正在播放中”的单元对象（相当于置空当前点击播放所对应表格单元的dto对象句柄）
- (void) clearCurrentPlayingCell:(BOOL)updateUI
{
    [self setCurrentPlayingCell:nil update:updateUI];
}

// 设置当前“正在播放中”的单元对象（相当于记录下当前点击播放所对应表格单元的dto对象句柄）
- (void) setCurrentPlayingCell:(PhotosOrVoiecesDTO *)entity update:(BOOL)updateUI
{
    self.play_currentPlayingCell = entity;

    if(updateUI)
        // 通知ui刷新播放状态
        [self.collectionView reloadData];
}

// 播放音频数据
- (void)playAudio
{
    if (self.play_audioData != nil)
    {
        // 无条件先保证重置音频的播放
        if([self isAudioPlaying])
            [self stopAudio:NO];

        // 基本播放配置
        NSError *error = nil;
        [[AVAudioSession sharedInstance] setCategory:@"AVAudioSessionCategoryPlayback"
                                         withOptions:AVAudioSessionCategoryOptionDuckOthers
         |AVAudioSessionCategoryOptionDefaultToSpeaker
         |AVAudioSessionCategoryOptionAllowBluetooth
                                               error:&error];

        // 重新起一个
        self.play_audioPlayer = [[AVAudioPlayer alloc] initWithData:self.play_audioData error:nil];
        self.play_audioPlayer.delegate = self;

        // 开始播放音频
        [self.play_audioPlayer play];
    }
}

// 停止播放音频数据
- (void)stopAudio:(BOOL)clearCurrentSlectedCell
{
    if(clearCurrentSlectedCell)
        // 清空播放状态
        [self clearCurrentPlayingCell:YES];

    if(self.play_audioPlayer != nil)
    {
        // 只在当前正在播放时移除观察者（因为每次开始play时都会首先调用
        // stopAudio，本判断防止刚加上的观察者在此时被提前移除）
        if([self isAudioPlaying])
        {
            // 被打断地播放，则显式置空播放数据
            self.play_audioData = nil;
        }

        [self.play_audioPlayer stop];
        self.play_audioPlayer = nil;
    }
}

- (BOOL)isAudioPlaying
{
    return self.play_audioPlayer != nil && [self.play_audioPlayer isPlaying];
}


#pragma mark - AVAudioPlayerDelegate（音频播放完成的回调通知）

// 音频正常播放完成后的回调
- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
    // 停止播放并释放资源
    [self stopAudio:YES];

    // 播放完成后，显式置空播放数据，没有必要占用内存
    self.play_audioData = nil;

    // 播放结束提示音
    // 已关闭播放结束提示音
    // [[PromtHelper sharedInstance] audioPlayEndPromt];
}

// 音频播放出错时的回调
- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(NSError *)error
{
    NSLog(@"【个人语音介绍-播放】【NO】播放音频文件时出错了，原因:%@", error);
}


//---------------------------------------------------------------------------------------------------
#pragma mark - IQAudioRecorderViewControllerDelegate（语音录制的相关代理方法）

// 语音录制完成，会自动走到本方法，从而继续处理语音留言文件的上传等逻辑
- (void)audioRecorderController:(IQAudioRecorderViewController *)controller didFinishWithAudioAtPath:(NSString *)originalAudioPath
{
    // 将录制的原始音频数据转码为.amr格式文件
    NSString *amrfilePath =  [IQAudioRecorderViewController convertCAFtoAMR:originalAudioPath toDir:[UploadPVoiceHelper getSendVoiceSavedDir]];
    NSString *amrfileName = [amrfilePath lastPathComponent];

    // 转码完成后删除原始的录制文件（及时清理，防止占用用户手机空间）
    [FileTool removeFile: originalAudioPath];

    NSLog(@"【个人语音介绍-录制】录制并转码完的语音文件路径是：%@, 文件名是：%@，转码为AMR前的原始路径为：%@", amrfilePath, amrfileName, originalAudioPath);

    // 返回用户详细资料界面
    [controller dismissViewControllerAnimated:YES completion:^{
//        [self processVoiceMessageSend:amrfileName];

        NSLog(@"【个人语音介绍-录制】录制并转码完成，最终文件为：%@", amrfileName);

        if(amrfileName != nil)
        {
            // 显示进度提示菊花
            MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];

            //** 开始上传语音文件
            [SendVoiceHelper processVoiceUpload:amrfileName usedFor:YES
                                     processing:^{    // “上传中”的状态回调
                                         hud.label.text = @"上传中..";
                                     } processFaild:^{// “上传失败完成”的状态回调
                                         // 隐藏进度提示菊花
                                         [hud hideAnimated:NO];
//                                         AlertError(@"上传失败，可能是您的网络不稳定！");
                                         [BasicTool showAlertError:@"上传失败，可能是您的网络不稳定！" parent:self];
                                     } processOk:^{   // “上传成功完成”的状态回调
                                         // 隐藏进度提示菊花
                                         [hud hideAnimated:NO];
                                         // 显示一个toast提示
                                         [APP showUserDefineToast_OK:@"上传成功"];
                                         // 重新从网络载入最新数据
                                         [self loadDatas];
                                     }];
        }
        else
        {
            DDLogDebug(@"【个人语音介绍-录制】要上传的语音文件准备失败，本次上传不能继续！");
//            AlertError(@"要上传的语音文件准备失败，本次上传不能继续！");
            [BasicTool showAlertError:@"要上传的语音文件准备失败，本次上传不能继续！" parent:self];
        }
    }];
}

// 点击了取消上传按钮后，会自动走到本方法
- (void)audioRecorderControllerDidCancel:(IQAudioRecorderViewController *)controller
{
    [controller dismissViewControllerAnimated:YES completion:nil];
}


//-----------------------------------------------------------------------------------------------
#pragma mark - 其它方法

// 点击标题栏上的“添加语音”按钮时调用的方法
- (void)doAddVoice
{
    UIColor *sendButtonTextColor = HexColor(0x4B535E);
    // 针对ios 26的优化：由于ui中启用了液态玻璃效果，所以这里用白色字体更匹配
    if (@available(iOS 26, *)) {
        sendButtonTextColor = [UIColor whiteColor];
    }

    // 进入语音录制界面
    [IQAudioRecorderViewController presentBlurredAudioRecorderViewControllerAnimated2:self delegate:self maxDuration:LOCAL_PVOICE_AUDIO_LENGTH sendButtonText:@"点此上传" cancelButtonText:nil sendButtonImage:[UIImage imageNamed:@"main_more_profile_record_frame_btn_speech"] sendButtonImageHighlight:[UIImage imageNamed:@"main_more_profile_record_frame_btn_speech_hover"] sendButtonTextColor:sendButtonTextColor];
}

// 删除按钮事件处理方法
-(void)doDeleteVoice:(UIButton *)btn
{
    PhotosOrVoiecesDTO *ree = (PhotosOrVoiecesDTO *)[self.verificationDatas get:btn.tag];
    if(ree != nil)
    {
        //### 仿微信的弹出菜单
        [LPActionSheet showActionSheetWithTitle:@"此份语音删除后，将不可恢复，请确认。"
                              cancelButtonTitle:@"取消"    // index==0
                         destructiveButtonTitle:@"确认删除" // index==-1
                              otherButtonTitles:nil
                                        handler:^(LPActionSheet *actionSheet, NSInteger index) {
                                            if(index == -1){
                                                // 提交http删除请求到服务器
                                                [[HttpRestHelper sharedInstance] submitDeleteProfileBinaryToServer:ree.resource_id
                                                                                                             fname:ree.res_file_name
                                                                                                              type:@"1"
                                                                                                          complete:^(BOOL sucess) {
                                                                                                              if(sucess){
                                                                                                                  [APP showUserDefineToast_OK:@"删除成功"];
                                                                                                                  // 重新从网络载入最新数据
                                                                                                                  [self loadDatas];
                                                                                                              }
                                                                                                              else{
                                                                                                                  //                                                                              AlertError(@"删除失败，可能是您的网络不给力！");
                                                                                                                  [BasicTool showAlertError:@"删除失败，可能是您的网络不给力！" parent:self];
                                                                                                              }
                                                                                                          }
                                                                                                     hudParentView:self.view];
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
    [[HttpRestHelper sharedInstance] queryPhotosOrVoicesListFromServer:self.photoOfUid resourceType:1 complete:^(BOOL sucess, NSArray<PhotosOrVoiecesDTO *> *datas) {

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
