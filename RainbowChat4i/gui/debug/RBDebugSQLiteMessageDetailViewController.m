//telegram @wz662
#import "RBDebugSQLiteMessageDetailViewController.h"

@interface RBDebugSQLiteMessageDetailViewController ()
@property (nonatomic, copy) NSString *detailText;
@property (nonatomic, copy) NSString *navTitle;
@property (nonatomic, strong) UITextView *textView;
@end

@implementation RBDebugSQLiteMessageDetailViewController

- (instancetype)initWithDetailText:(NSString *)detailText title:(NSString *)title
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _detailText = [detailText copy];
        _navTitle = [title copy];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = self.navTitle ?: @"详情";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    self.textView = [[UITextView alloc] initWithFrame:self.view.bounds];
    self.textView.translatesAutoresizingMaskIntoConstraints = NO;
    UIFont *mono = [UIFont fontWithName:@"Menlo" size:11];
    if (!mono) mono = [UIFont fontWithName:@"Courier" size:11];
    if (@available(iOS 13.0, *)) {
        if (!mono) mono = [UIFont monospacedDigitSystemFontOfSize:11 weight:UIFontWeightRegular];
    }
    if (!mono) mono = [UIFont systemFontOfSize:11];
    self.textView.font = mono;
    self.textView.editable = NO;
    self.textView.selectable = YES;
    self.textView.alwaysBounceVertical = YES;
    self.textView.text = self.detailText;
    [self.view addSubview:self.textView];

    UILayoutGuide *g = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.textView.topAnchor constraintEqualToAnchor:g.topAnchor],
        [self.textView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.textView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.textView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"复制" style:UIBarButtonItemStylePlain target:self action:@selector(onCopy)];
}

- (void)onCopy
{
    if (self.detailText.length) {
        [UIPasteboard generalPasteboard].string = self.detailText;
    }
}

@end
