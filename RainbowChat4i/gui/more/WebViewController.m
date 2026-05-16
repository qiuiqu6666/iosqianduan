//telegram @wz662
#import "WebViewController.h"
#import "MBProgressHUD.h"
#import "Masonry.h"
#import "UIViewController+RBPlainCustomNav.h"

@interface WebViewController ()

@property (nonatomic, retain) WKWebView *webView2;

@end

@implementation WebViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self rb_installPlainCustomNavigationBarWithTitle:(self.title ?: @"")];

    //# -- 以下代码用于配置WKWebView
    WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
//    WKUserContentController *userContentController = [[WKUserContentController alloc] init];
//    // 自适应屏幕宽度js
//    NSString *jSString = @"var meta = document.createElement('meta'); meta.setAttribute('name', 'viewport'); meta.setAttribute('content', 'width=device-width'); document.getElementsByTagName('head')[0].appendChild(meta);";
//    WKUserScript *wkUserScript = [[WKUserScript alloc] initWithSource:jSString injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:YES];
//    // 添加自适应屏幕宽度js调用的方法
//    [userContentController addUserScript:wkUserScript];
//    configuration.userContentController = userContentController;
    // 创建设置对象
    WKPreferences *preference = [[WKPreferences alloc]init];
    //最小字体大小 当将javaScriptEnabled属性设置为NO时，可以看到明显的效果
    preference.minimumFontSize = 0;
    //设置是否支持javaScript 默认是支持的
    preference.javaScriptEnabled = YES;
    // 在iOS上默认为NO，表示是否允许不经过用户交互由javaScript自动打开窗口
    preference.javaScriptCanOpenWindowsAutomatically = YES;
    configuration.preferences = preference;
    // 是使用h5的视频播放器在线播放, 还是使用原生播放器全屏播放
    configuration.allowsInlineMediaPlayback = YES;
    //设置视频是否需要用户手动播放  设置为NO则会允许自动播放
    configuration.requiresUserActionForMediaPlayback = YES;
    //设置是否允许画中画技术 在特定设备上有效
    configuration.allowsPictureInPictureMediaPlayback = YES;
    
    //# -- 以下代码用于实例化WKWebView以及UI显示
    self.webView2 = [[WKWebView alloc] initWithFrame:self.view.bounds configuration:configuration];
    [self.view addSubview:self.webView2];
    // 自动适配屏幕宽度
    if (@available(iOS 11,*)) {
        [self.webView2 mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(self.view);
            make.top.equalTo(self.view.mas_safeAreaLayoutGuideTop);
            make.right.equalTo(self.view);
            make.bottom.equalTo(self.view);
//          make.bottom.equalTo(self.view.mas_safeAreaLayoutGuideBottom);
        }];
    }
    self.webView2.navigationDelegate = self;
    self.webView2.opaque = NO;
    self.webView2.backgroundColor = [UIColor whiteColor];
    if (@available(ios 11.0,*)) {
        //## Bug FIX 250920：不能使用UIScrollViewContentInsetAdjustmentNever，否则将导致iOS 26上内容被标题导航栏档住的问题
        self.webView2.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
    }
    
    //# -- 以下代码用于WKWebView加载内容
    [self.webView2 loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:self.webUrl]]];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self rb_plainCustomNavHostViewWillAppear:animated];
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
    [super viewDidDisappear:animated];
    [self rb_plainCustomNavHostViewDidDisappear:animated];
}

#pragma mark - UIWebViewDelegate（已经过时的UIWebView的代理方法）

//- (void)webViewDidStartLoad:(UIWebView *)webView
//{
//    dispatch_async(dispatch_get_main_queue(), ^{
//        [MBProgressHUD showHUDAddedTo:webView animated:YES];
//    });
//}
//- (void)webViewDidFinishLoad:(UIWebView *)webView
//{
//    dispatch_async(dispatch_get_main_queue(), ^{
//        [MBProgressHUD hideAllHUDsForView:webView animated:YES];
//    });
//
//}
//- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
//{
////    [BasicTool showDialog:nil message:NSLocalizedString(@"request_server_failed", @"")];
//    [BasicTool showAlertInfo:NSLocalizedString(@"request_server_failed", @"") parent:self];
//    dispatch_async(dispatch_get_main_queue(), ^{
//        [MBProgressHUD hideAllHUDsForView:webView animated:YES];
//    });
//}

#pragma mark - WKNavigationDelegate（用来追踪加载过程（页面开始加载、加载完成、加载失败）的方法）

// 页面开始加载时调用
-(void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation
{
    DDLogDebug(@"【WebViewController】1-didStartProvisionalNavigation-页面开始加载时调用");
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [MBProgressHUD showHUDAddedTo:webView animated:YES];
    });
}

// 页面加载失败时调用
- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
    if(error)
        DDLogDebug(@"【WebViewController】2-didFailProvisionalNavigation-页面加载失败时调用（错误码code=%ld，domain=%@）", error.code, error.domain);
    else
        DDLogDebug(@"【WebViewController】2-didFailProvisionalNavigation-页面加载失败时调用");
    
    //[BasicTool showDialog:nil message:NSLocalizedString(@"request_server_failed", @"")];
    [BasicTool showAlertInfo:NSLocalizedString(@"request_server_failed", @"") parent:self];
    dispatch_async(dispatch_get_main_queue(), ^{
//      [MBProgressHUD hideAllHUDsForView:webView animated:YES];
        [MBProgressHUD hideHUDForView:webView animated:YES];
    });
}

// 当内容开始返回时调用
- (void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation
{
    DDLogDebug(@"【WebViewController】3-didCommitNavigation-当内容开始返回时调用");
}

// 页面加载完成之后调用
- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{//这里修改导航栏的标题，动态改变
    DDLogDebug(@"【WebViewController】4-didFinishNavigation-页面加载完成之后调用");
    
    dispatch_async(dispatch_get_main_queue(), ^{
//      [MBProgressHUD hideAllHUDsForView:webView animated:YES];
        [MBProgressHUD hideHUDForView:webView animated:YES];
    });
}

// 提交发生错误时调用
- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
    DDLogDebug(@"【WebViewController】5-didFailNavigation-页面加载完成之后调用");
    
    //[BasicTool showDialog:nil message:NSLocalizedString(@"request_server_failed", @"")];
    [BasicTool showAlertInfo:NSLocalizedString(@"request_server_failed", @"") parent:self];
    dispatch_async(dispatch_get_main_queue(), ^{
//      [MBProgressHUD hideAllHUDsForView:webView animated:YES];
        [MBProgressHUD hideHUDForView:webView animated:YES];
    });
}


#pragma mark - WKNavigationDelegate（页面跳转的代理方法的方法）

// 接收到服务器跳转请求之后调用
- (void)webView:(WKWebView *)webView didReceiveServerRedirectForProvisionalNavigation:(WKNavigation *)navigation
{
    DDLogDebug(@"【WebViewController】5-didReceiveServerRedirectForProvisionalNavigation-接收到服务器跳转请求之后再执行");
}

// 在收到响应后，决定是否跳转
- (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler
{
    DDLogDebug(@"【WebViewController】6-decidePolicyForNavigationResponse-在收到响应后，决定是否跳转");
    
    NSInteger statusCode = ((NSHTTPURLResponse *)navigationResponse.response).statusCode;
    NSLog(@"【WebViewController】服务端的响应码statusCode：%ld", statusCode);
    if (statusCode/100 == 4 || statusCode/100 == 5) {
        NSLog(@"【WebViewController】服务端出错了，原因是：%@", navigationResponse.response);
    }
    
//    DDLogDebug(@"%@",navigationResponse);
    //允许跳转
    decisionHandler(WKNavigationResponsePolicyAllow);
    //不允许跳转
    //decisionHandler(WKNavigationResponsePolicyCancel);
}

// 在发送请求之前，决定是否跳转
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    DDLogDebug(@"【WebViewController】7-decidePolicyForNavigationAction-在发送请求之前，决定是否跳转");
    //这句是必须加上的，不然会异常
    //允许跳转
    decisionHandler(WKNavigationActionPolicyAllow);
    //不允许跳转
    //decisionHandler(WKNavigationActionPolicyCancel);
    NSURL *requestURL = navigationAction.request.URL;
    DDLogDebug(@"【WebViewController】requestURL：%@",requestURL.absoluteString);
}

@end
