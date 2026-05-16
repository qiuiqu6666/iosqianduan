//telegram @wz662
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

@interface WebViewController : UIViewController<WKNavigationDelegate>
//@property (weak, nonatomic) IBOutlet UIWebView *webView;
//@property (weak, nonatomic) IBOutlet WKWebView *webView2;
//- (IBAction)back:(id)sender;
@property (nonatomic, copy) NSString* webUrl;
@property (nonatomic, copy) NSString* webTitle;
@end
