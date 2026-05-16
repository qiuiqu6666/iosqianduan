//telegram @wz662
#import "BigFileViewerController.h"
#import "BasicTool.h"
#import "FileTool.h"
#import "AppDelegate.h"

@interface BigFileViewerController ()

/** 本次要查看的文件名 */
@property (nonatomic, retain) NSString *fileName;
/** 文件存储的目录：此目录末尾不需带"/"反斜线 */
@property (nonatomic, retain) NSString *fileDir;
/** 文件md5码 */
@property (nonatomic, retain) NSString *fileMd5;
/** 文件的理论总长度(此值并不是本地文件的实际长度，因为支持断点续传，可能并未完全下载完成) */
@property (nonatomic, assign) long long fileLength;

/** true表示当文件未完成或不存在时需要下载，否则不需要下载（这种情况对应用于我发出的文件） */
@property (nonatomic, assign) BOOL canDownload;

@property (nonatomic, strong) UIDocumentInteractionController * documentInteractionController;

@end


@implementation BigFileViewerController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil fileName:(NSString *)fileName fileDir:(NSString *)fileDir fileMd5:(NSString *)fileMd5 fileLength:(long long)fileLength canDownload:(BOOL)canDownload
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
    {
        self.fileName = fileName;
        self.fileDir = fileDir;
        self.fileMd5 = fileMd5;
        self.fileLength = fileLength;
        self.canDownload = canDownload;

        DDLogDebug(@"【文件查看界面】传进来的参数：fileName=%@ fileDir=%@, fileMd5=%@, fileLen=%lld", fileName, fileDir, fileMd5, fileLength);

        if(self.fileLength < 0)
            self.fileLength = 0;
    }
    return self;
}

- (id)init
{
    if(self = [super init])
    {
        // 属性初始化
        self.canDownload = NO;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // 设置Ui组件的默认可见笥
    [self setProgressVisible:NO];
    self.mViewHint.hidden = YES;

    self.title = @"文件信息";

    // 设置文件图标
    self.mViewFileIcon.image = [BigFileViewerController getFileIconByExtention:self.fileName bigImage:YES];
    // 文件名显示
    self.mViewFileName.text = self.fileName;

    // 初始化文件状态及相关UI显示
    [self initFileStatusForUI];
    
    // 给按钮设置液态玻璃效果
    [BasicTool setClearGlassBgnConfig:self.mBtnOpr];
}

// 根据UIViewController的生命周期，本方法将在每次本界面每次回到前台时被调用
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    // 设置大文件下载任务观察者
    [BigFileDownloadManager sharedInstance].delegate = self;
}

//视图已经出现
- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    if(![self checkInitParams])
        [self doBack];
}

- (void)viewDidDisappear:(BOOL)animated
{
    // 取消设置大文件下载任务观察者
    [BigFileDownloadManager sharedInstance].delegate = nil;

    [super viewDidDisappear:animated];
}

// 按钮点击事件处理
- (IBAction)fireButtonClick:(id)sender
{
    // 当文件不完整或不存在时需要下载（这种情况对应于收到的文件消息）
    if(self.canDownload)
    {
        // 大文件下载管理器
        BigFileDownloadManager *bfdm = [BigFileDownloadManager sharedInstance];

        // 当前界面中要查看的文件就是下载任务管理器中的文件
        if ([bfdm isCurrentFile:self.fileMd5])
        {
            // 如果文件本身就已经下载完成，则直接进入打开逻辑，不需要再去根据管理器中的文件状态来决定
            if([self isLocalFileCompelte])
            {
                DDLogDebug(@"【文件查看界面-当前任务】[isFileCompelte=true]initListeners调用中。。");
                [self doOpen];
            }
            // 未完成情况下
            else
            {
                DDLogDebug(@"【文件查看界面-当前任务】[isFileCompelte=false]initListeners调用中。。（bfdm.getFileStatus()=%d)", [bfdm getFileStatus]);

                // 根据下载管理器中当前文件的下载状态来决定按钮的事件响应
                switch ([bfdm getFileStatus])
                {
                    case BFDM_FILE_STATUS_FILE_COMPLETE:
                        [self doOpen];
                        break;
                    case BFDM_FILE_STATUS_FILE_NOT_COMPLETE:
                        [self doDownload];
                        break;
                    case BFDM_FILE_STATUS_FILE_DOWNLOADING:
                        [self doPause];
                        break;
                    case BFDM_FILE_STATUS_FILE_DOWNLOAD_PAUSE:
                        [self doDownload];
                        break;
                }

                // 根据最新状态刷新UI显示
                [self refreshUI:[bfdm getFileStatus]];
            }
        }
        // 当前界面中要查看的文件并不在下载任务管理器中
        else
        {
            // 如果该文件本来就已经下载完成
            if([self isLocalFileCompelte])
            {
                DDLogDebug(@"【文件查看界面-非当前任务】initListeners调用中，用户可以直接打开文件，因为文件已就绪。");
                // 直接尝试打开
                [self doOpen];
            }
            // 否则进入下载流程
            else
            {
                DDLogDebug(@"【文件查看界面-非当前任务】initListeners调用中，用户应是点击 doDownload()了");
                [self doDownload];
            }
        }
    }
    // 当文件不完整或不存在时不需要下载（这种情况对应用于我发出的文件消息）
    else
    {
        // 直接尝试打开
        [self doOpen];
    }
}

/**
 * 初始化文件的状态。
 */
- (void) initFileStatusForUI
{
    // 当文件不完整或不存在时需要下载（这种情况对应于收到的文件消息）
    if(self.canDownload)
    {
//        File f = this.getLocalFilePath();
//        NSString *f = [self getLocalFilePath];
        // 本界面要查看的文件已经就绪了(就不用管下载管理器的事，直接刷新ui)
        if([self isLocalFileCompelte])
           [self refreshUI:BFDM_FILE_STATUS_FILE_COMPLETE];
        else
        {
            DDLogInfo(@"【文件查看界面-initFileStatusForUI】%@ 未下载完成。。。", [self getLocalFilePath]);
//            Log.i(TAG, f.getAbsolutePath() + " 未下载完成。。。");

            // 大文件下载管理器
            BigFileDownloadManager *bfdm = [BigFileDownloadManager sharedInstance];

            // 当前界面中要查看的文件就是下载任务管理器中的文件
            if ([bfdm isCurrentFile:self.fileMd5])
            {
                // 根据任务状态刷新界面上的UI显示（如按钮、进度条可见性等）
                [self refreshUI:[bfdm getFileStatus]];

                // 如果有正在下载中或暂停中的作务，则还要把下载进度条及进度值显示出来
                if([bfdm isDownloading] || [bfdm isPause])
                 [self showDownloadPregress:YES];
            }
            else
            {
                // 根据任务状态刷新界面上的UI显示（如按钮、进度条可见性等）
                [self refreshUI:BFDM_FILE_STATUS_FILE_NOT_COMPLETE];
                // 并刷新已经下载过的进度(在上次已经下载过一部分的情况下才需要显示，否则没意义)
                if([self getLocalFileCurrentLength] > 0)
                    [self showDownloadPregress:YES];
            }
        }
    }
    // 当文件不完整或不存在时不需要下载（这种情况对应用于我发出的文件消息）
    else
    {
        // 根据任务状态刷新界面上的UI显示（如按钮、进度条可见性等）
        [self refreshUI:BFDM_FILE_STATUS_FILE_COMPLETE];
    }
}

/**
 * 刷新按钮等相关UI的可见性。
 */
- (void) refreshUI:(int)fs
{
    switch(fs)
    {
        case BFDM_FILE_STATUS_FILE_COMPLETE:
            [self.mBtnOpr setTitle:@"打开文件" forState:UIControlStateNormal];
            // 针对ios 26的优化：给按钮设置液态玻璃效果后它会将原背景色变淡，所以在ios 26下就将愿意颜色设置的深一点，不然视觉上太淡了
            if (@available(iOS 26, *)) {
                [self.mBtnOpr setBackgroundColor:HexColor(0x00c460)];// -rgb颜色值各减26
            }
            else {
                [self.mBtnOpr setBackgroundColor:HexColor(0x00de7a)]; // 亮绿色 // 42c958
            }
            
            [self.mBtnOpr setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            [self setProgressVisible:NO];
            break;
        case BFDM_FILE_STATUS_FILE_NOT_COMPLETE:
            [self.mBtnOpr setTitle:@"下载文件" forState:UIControlStateNormal];
            [self.mBtnOpr setBackgroundColor:HexColor(0xda3e28)]; // 主红色
//            [self.mBtnOpr setBackgroundColor:HexColor(0xda3e28)]; // 主红色
//            [self.mBtnOpr setTitleColor:HexColor(0xff6432) forState:UIControlStateNormal];
            [self.mBtnOpr setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            [self setProgressVisible:NO];
            break;
        case BFDM_FILE_STATUS_FILE_DOWNLOADING:
            [self.mBtnOpr setTitle:@"暂停下载" forState:UIControlStateNormal];
            // 针对ios 26的优化：给按钮设置液态玻璃效果后它会将原背景色变淡，所以在ios 26下就将愿意颜色设置的深一点，不然视觉上太淡了
            if (@available(iOS 26, *)) {
                [self.mBtnOpr setBackgroundColor:HexColor(0x48B9DF)]; // 亮蓝色
            }
            else {
                [self.mBtnOpr setBackgroundColor:HexColor(0x61D2F8)]; // 亮蓝色
            }
            
            [self.mBtnOpr setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            [self setProgressVisible:YES];
            break;
        case BFDM_FILE_STATUS_FILE_DOWNLOAD_PAUSE:
            [self.mBtnOpr setTitle:@"继续下载" forState:UIControlStateNormal];
            [self.mBtnOpr setBackgroundColor:HexColor(0xda3e28)]; // 主红色
//            [self.mBtnOpr setTitleColor:HexColor(0xff6432) forState:UIControlStateNormal];
            [self.mBtnOpr setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            [self setProgressVisible:YES];
            break;
    }

    [self showLocalFileSize];
}

/**
 * 刷新按钮等相关UI的可见性。
 */
- (void) refreshUI_ext
{
    if([[BigFileDownloadManager sharedInstance] isCurrentFile:self.fileMd5])
        [self refreshUI:[[BigFileDownloadManager sharedInstance] getFileStatus]];
}


//-----------------------------------------------------------------------------------------
#pragma mark - BigFileDownloadManagerDelegate（下载任务管理器中下载任务状态变更的代理方法）

- (void) onPreExecute:(NSString *)fileMd5InManager
{
    BigFileDownloadManager *bfdm = [BigFileDownloadManager sharedInstance];
    if([bfdm isCurrentFile:self.fileMd5])
    {
        DDLogDebug(@"[文件查看界面-观察者实现类中-当前任务] onPreExecute被调用了！");

        [self refreshUI_ext];
        [self showDownloadPregress:YES];
        [self showHint:nil];
    }
    else
    {
        DDLogDebug(@"[文件查看界面-观察者实现类中-非当前任务] onPreExecute被调用了！");
    }
}

- (void) onProgressUpdate:(NSString *)fileMd5InManager withProgress:(float)progress
{
    BigFileDownloadManager *bfdm = [BigFileDownloadManager sharedInstance];
    if([bfdm isCurrentFile:self.fileMd5])
    {
//        DDLogDebug(@"[文件查看界面-观察者实现类中-当前任务] onProgressUpdate被调用了！");

        [self refreshUI_ext];
        self.mDownloadProgress.progress = progress;
        [self showLocalFileSize];
    }
    else
    {
        DDLogDebug(@"[文件查看界面-观察者实现类中-非当前任务] onProgressUpdate被调用了！");
    }
}

- (void) onPostExecute_onException:(NSString *)fileMd5InManager withError:(NSError *) exception
{
    BigFileDownloadManager *bfdm = [BigFileDownloadManager sharedInstance];
    if([bfdm isCurrentFile:self.fileMd5])
    {
        DDLogDebug(@"[文件查看界面-观察者实现类中-当前任务] onPostExecute_onException被调用了！");

        [self refreshUI_ext];
        [self showHint:@"下载已停止，您可点击\"点击继续下载\"按钮进行重试."];
        DDLogDebug(@"【文件查看界面】文件下载停止了，原因可能是：用户暂停了下载或者下载过程中出错了。");
    }
    else
    {
        DDLogDebug(@"[文件查看界面-观察者实现类中-非当前任务] onPostExecute_onException被调用了！");
    }
}

- (void) onPostExecute_onSucess:(NSString *)fileMd5InManager withSavedPath:(NSString *)fileSavedPath
{
    BigFileDownloadManager *bfdm = [BigFileDownloadManager sharedInstance];
    if([bfdm isCurrentFile:self.fileMd5])
    {
        DDLogDebug(@"[文件查看界面-观察者实现类中-当前任务] onPostExecute_onSucess被调用了！");
        [self refreshUI_ext];
    }
    else
    {
        DDLogDebug(@"[文件查看界面-观察者实现类中-非当前任务] onPostExecute_onSucess被调用了！");
    }

}

- (void) onCancel:(NSString *)fileMd5InManager
{
    BigFileDownloadManager *bfdm = [BigFileDownloadManager sharedInstance];
    if([bfdm isCurrentFile:self.fileMd5])
    {
        DDLogDebug(@"[文件查看界面-观察者实现类中-当前任务] onCancel被调用了！");
        [self refreshUI_ext];
    }
    else
    {
        DDLogDebug(@"[文件查看界面-观察者实现类中-非当前任务] onCancel被调用了！");
    }
}

- (void) onPause:(NSString *)fileMd5InManager;
{
    BigFileDownloadManager *bfdm = [BigFileDownloadManager sharedInstance];
    if([bfdm isCurrentFile:self.fileMd5])
    {
        DDLogDebug(@"[文件查看界面-观察者实现类中-当前任务] onPause被调用了！");
        [self refreshUI_ext];
    }
    else
    {
        DDLogDebug(@"[文件查看界面-观察者实现类中-非当前任务] onPause被调用了！");
    }
}


//-----------------------------------------------------------------------------------------
#pragma mark - UIDocumentInteractionControllerDelegate（利用ios的UIDocumentInteractionController，实现预览/查看文件内容，此delegate是必须的，否则无法完成预览）

- (UIViewController*)documentInteractionControllerViewControllerForPreview:(UIDocumentInteractionController*)controller
{
    return self;
}
- (UIView*)documentInteractionControllerViewForPreview:(UIDocumentInteractionController*)controller
{
    return self.view;
}
- (CGRect)documentInteractionControllerRectForPreview:(UIDocumentInteractionController*)controller
{

    return self.view.frame;
}
//点击预览窗口的“Done”(完成)按钮时调用
- (void)documentInteractionControllerDidEndPreview:(UIDocumentInteractionController*)_controller
{
    self.documentInteractionController = nil;
}


//-----------------------------------------------------------------------------------------
#pragma mark - 其它方法

/**
 * 显示提示信息。
 *
 * @param hint 提示信息文本
 */
- (void) showHint:(NSString *)hint
{
    if(![BasicTool isStringEmpty:[BasicTool trim:hint]])
        self.mViewHint.hidden = NO;
    else
        self.mViewHint.hidden = YES;

    self.mViewHint.text = hint;
}

/**
 * 用最新的下载刷新当前文件大小的显示。
 */
- (void) showLocalFileSize
{
    long long curentDownloadLength = [self getLocalFileCurrentLength];
    if(curentDownloadLength <= 0 || curentDownloadLength == self.fileLength)
        self.mViewFileSize.text = [FileTool getConvenientFileSize:self.fileLength];
    else
        self.mViewFileSize.text = [NSString stringWithFormat:@"%@/%@", [FileTool getConvenientFileSize:curentDownloadLength], [FileTool getConvenientFileSize:self.fileLength]];
}

- (NSString *) getLocalFilePath
{
    return [NSString stringWithFormat:@"%@/%@", self.fileDir, self.fileName];
//    return new File(fileDir+File.separator+fileName);
}

- (long long) getLocalFileCurrentLength
{
    return [FileTool fileSizeAtPath:[self getLocalFilePath]];
//    return getLocalFilePath().length();
}

/**
 * 本界面中要打开的文件是否已完成（已下载完成）。
 *
 * @return YES表示本地文件已经就绪
 */
- (BOOL) isLocalFileCompelte
{
//    File f = this.getLocalFilePath();
    // 当前查看的文件已存在 且 该文件的实际大小跟文件消息中存放的完整文件大小是相等的，就表示该文件已完成（已下载完成）
    return [FileTool fileExists:[self getLocalFilePath]] && [self getLocalFileCurrentLength] == self.fileLength;
}

/**
 * 检查传进来的参数合法性。
 *
 * @return YES表示参数检查通过
 */
- (BOOL) checkInitParams
{

    if([BasicTool isStringEmpty:self.fileName]
       || [BasicTool isStringEmpty:self.fileDir]
       || self.fileLength <= 0)
    {
//        AlertError(@"无效的文件信息参数！");
        [BasicTool showAlertError:@"无效的文件信息参数！" parent:self];
        DDLogDebug(@"【文件查看界面】fileName=%@ fileDir=%@, fileMd5=%@, fileLen=%ld", self.fileName, self.fileDir, self.fileMd5, self.fileLength);
        return NO;

    }
    return YES;
}

- (void) setProgressVisible:(BOOL)visible
{
    // 可见时的高度，请与xib中保持一致，这样方便ui与xib中的可视化保持一致
    self.heightConstraintOfDownloadProgressLayout.constant = visible?18:0;
}

/**
 * 刷新进条上的显示。
 *
 * @param show true表示刷新显示，false表示隐藏进度条的显示
 */
- (void) showDownloadPregress:(BOOL)show
{
    if(show)
    {
        [self setProgressVisible:YES];
        long long curentDownloadLength = [self getLocalFileCurrentLength];
        float percent = 0.0f;

        if (curentDownloadLength >= self.fileLength)
            percent = 1.0f;
        else
            // 下载进度：0~1.0f
            percent =  (curentDownloadLength * 1.0 / self.fileLength);
        self.mDownloadProgress.progress = percent;
    }
    else
    {
        [self setProgressVisible:NO];
    }
}

/**
 * 开始下载/继续下载。
 */
- (void) doDownload
{
    BigFileDownloadManager *bfdm = [BigFileDownloadManager sharedInstance];

    DDLogDebug(@"【文件查看界面】[doDownload] bfdm=%@, bfdm.fileStatus=%d", bfdm, [bfdm getFileStatus]);
    [bfdm printDebug];

    if(![bfdm isCurrentFile:self.fileMd5] && [bfdm isDownloading])
    {
        DDLogDebug(@"【文件查看界面】下载管理器中存在未完成的下载任务。。。");
        
        // 显示一个确认对话框
        [BasicTool areYouSureAlert:@"提示" content:[NSString stringWithFormat:@"\"%@\"正在后台下载中，请先停止该文件的下载，确认要这样做吗？",[bfdm getFileName]] okBtnTitle:NSLocalizedString(@"general_ok", @"") cancelBtnTitle:NSLocalizedString(@"general_cancel", @"") parent:self okHandler:^(UIAlertAction * _Nullable action) {
            
            // 先退出先前的下载任务
            [bfdm cancelTask:YES];

            //** 特别说明：因目前的大文件断点下载是使用NSURLSessionDataTask实现，而NSURLSessionDataTask中的cancel方法退出
            //**         当前下载任务时，会有几时毫秒的延迟（具体可能是NSURLSessionDataTask的内部读缓存机制的问题，暂未深究！），
            //**         如果此时像Android版中的此功能一样在cancel前一任务的同时马上开始新的任务，就会因此延迟产生的 didCompleteWithError:
            //**         delegate回调错误地将新的下载任务给打断而无法开始新任务的下载，所以目前的办法只能是先停止上一个下载后，再由用户
            //**         手动开始新的下载（这样就没有问题）。关于NSURLSessionDataTask cancel的延迟问题，日后可以再深入研究！！
//          // 开始新的下载
//          [self doDownloadImpl:bfdm];
        } cancelHandler:^(UIAlertAction * _Nullable action) {
            //
        } okActionStyle:UIAlertActionStyleDestructive cencelActionStyle:UIAlertActionStyleCancel];
    }
    else
    {
        // 开始新的下载
        [self doDownloadImpl:bfdm];
    }
}

- (void) doDownloadImpl:(BigFileDownloadManager *)bfdm
{
    if([self checkInitParams])
    {
        if (bfdm != nil)
        {
            long long currentLength = [self getLocalFileCurrentLength];
            if (currentLength <= 0)
                currentLength = 0;

            if (currentLength > self.fileLength)
            {
                [self showHint:@"下载无法完成，原因是：文件大小异常."];
                DDLogWarn(@"【文件查看界面】文下载无法完成，原因是：currentLength=%lld > fileLength=%ld", currentLength, self.fileLength);
                return;
            }

            [bfdm startTask:self.fileMd5 currentLength:currentLength fileDir:self.fileDir fileName:self.fileName fileLength:self.fileLength];
        }
    }
}

/**
 * 暂停下载。
 */
- (void) doPause
{
    BigFileDownloadManager *bfdm = [BigFileDownloadManager sharedInstance];
    [bfdm pauseTask];
    [self refreshUI:[bfdm getFileStatus]];
}

/**
 * 打开文件。
 */
- (void) doOpen
{
    // 预览/查看文件内容
    [self previewFile:[self getLocalFilePath]];
}

- (void)doBack
{
    // 退出本界面
    [self.navigationController popViewControllerAnimated:YES];
}

// 预览/查看文件内容
- (void)previewFile:(NSString *)path
{
    if(path != nil)
    {
        // 显示一个进度提示菊花HUD，因为iOS的UIDocumentInteractionController首次使用时会耗时较多
        [APP showGlobalHUD:YES];

        //## 以下代码行是20180614后的方式，解决录音界面打开卡卡顿的问题
        // 强制在主线程中执行，解决众所周之的 presentViewController 导致的界面延迟显示问题
        dispatch_async(dispatch_get_main_queue(), ^{
            NSURL *url=[NSURL fileURLWithPath:path];

            // 注意：支持预览的文件类型，见Info.plist配置文件中的“Document types”项
            // * 20181122日Jack Jiang实补充备注：实际上用UIDocumentInteractionController打开文件时不需要像网上的文章里说的，要在
            //   〉Info.plist配置文件中的“Document types”项，如果加了这些项，则提交app store审核会有点麻烦，而且实测完全没有必要这些配置。
            // * 20181122日 Jack Jiang备注：网上流传的打开文件配置内容如下：
            //------------------------------------------------------
            /*
            <key>CFBundleDocumentTypes</key>
            <array>
                <dict>
                <key>CFBundleTypeName</key>
                <string>com.rainbowchat_pro.common-data</string>
                <key>LSHandlerRank</key>
                <string>Owner</string>
                <key>LSItemContentTypes</key>
                <array>
                    <string>com.microsoft.powerpoint.ppt</string>
                    <string>public.item</string>
                    <string>com.microsoft.word.doc</string>
                    <string>com.adobe.pdf</string>
                    <string>com.microsoft.excel.xls</string>
                    <string>public.image</string>
                    <string>public.content</string>
                    <string>public.composite-content</string>
                    <string>public.archive</string>
                    <string>public.audio</string>
                    <string>public.movie</string>
                    <string>public.text</string>
                    <string>public.data</string>
                    <string>public.source-code</string>
                    <string>public.plain-text</string>
                    <string>public.font</string>
                    <string>public.xml</string>
                </array>
                </dict>
            </array>*/
            //------------------------------------------------------
            self.documentInteractionController = [UIDocumentInteractionController interactionControllerWithURL:url];
            self.documentInteractionController.delegate = self;

            // 预览文件
            BOOL b=[self.documentInteractionController presentPreviewAnimated:YES];
            // 关闭HUD
            [APP showGlobalHUD:NO];

            // 返回NO说明没有可以打开该文件的爱屁屁, 友情提示一下
            if (b == NO)
            {
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"提示" message:@"没有找到可以打开该文件的应用." delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil, nil];
                [alert show];
            }
        });
    }
}

// 返回对应扩展名的文件图标
+ (UIImage *) getFileIconByExtention:(NSString *)fileName bigImage:(BOOL)big
{
    NSString *resultFileIconName = [NSString stringWithFormat:@"file_type_unknow%@", big?@"_big":@""];
    // 取出文件扩展名
    NSString *fileExtName = (fileName == nil?nil:[fileName pathExtension]);
    if(fileExtName != nil)
    {
        fileExtName = [fileExtName lowercaseString];

        if([@"xls" isEqualToString:fileExtName] || [@"xlsx" isEqualToString:fileExtName])
            resultFileIconName = [NSString stringWithFormat:@"file_type_excel%@", big?@"_big":@""];
        else if([@"gif" isEqualToString:fileExtName])
            resultFileIconName = [NSString stringWithFormat:@"file_type_gif%@", big?@"_big":@""];
        else if([@"html" isEqualToString:fileExtName] || [@"htm" isEqualToString:fileExtName])
            resultFileIconName = [NSString stringWithFormat:@"file_type_html%@", big?@"_big":@""];
        else if([@"jpg" isEqualToString:fileExtName] || [@"jpeg" isEqualToString:fileExtName])
            resultFileIconName = [NSString stringWithFormat:@"file_type_jpg%@", big?@"_big":@""];
        else if([@"mp4" isEqualToString:fileExtName])
            resultFileIconName = [NSString stringWithFormat:@"file_type_mp4%@", big?@"_big":@""];
        else if([@"pdf" isEqualToString:fileExtName])
            resultFileIconName = [NSString stringWithFormat:@"file_type_pdf%@", big?@"_big":@""];
        else if([@"png" isEqualToString:fileExtName])
            resultFileIconName = [NSString stringWithFormat:@"file_type_png%@", big?@"_big":@""];
        else if([@"ppt" isEqualToString:fileExtName] || [@"pptx" isEqualToString:fileExtName])
            resultFileIconName = [NSString stringWithFormat:@"file_type_ppt%@", big?@"_big":@""];
        else if([@"rar" isEqualToString:fileExtName])
            resultFileIconName = [NSString stringWithFormat:@"file_type_rar%@", big?@"_big":@""];
        else if([@"txt" isEqualToString:fileExtName])
            resultFileIconName = [NSString stringWithFormat:@"file_type_txt%@", big?@"_big":@""];
        else if([@"apk" isEqualToString:fileExtName])
            resultFileIconName = [NSString stringWithFormat:@"file_type_apk%@", big?@"_big":@""];
        else if([@"doc" isEqualToString:fileExtName] || [@"docx" isEqualToString:fileExtName])
            resultFileIconName = [NSString stringWithFormat:@"file_type_word%@", big?@"_big":@""];
        else if([@"zip" isEqualToString:fileExtName]
                ||[@"7z" isEqualToString:fileExtName]
                ||[@"gz" isEqualToString:fileExtName]
                ||[@"tar" isEqualToString:fileExtName])
            resultFileIconName = [NSString stringWithFormat:@"file_type_zip%@", big?@"_big":@""];
    }

    return [UIImage imageNamed:resultFileIconName];
}




@end
