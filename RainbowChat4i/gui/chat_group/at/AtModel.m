//telegram @wz662
//
//  NIMInputAtCache.m
//  NIMKit
//
//  Created by xxx on 2016/12/8.
//  Copyright © 2016年 xxx. All rights reserved.
//

#import "AtModel.h"
#import "ViewControllerFactory.h"
#import "ChatRootViewController.h"
#import "JSQMessagesComposerTextView.h"

/// TG 等场景使用普通 UITextView，无 insertTextStr:；逻辑与 JSQMessagesComposerTextView 一致（含越界保护）
static void AtModelInsertPlainTextIntoComposer(UITextView *textView, NSString *text) {
    if (!textView) return;
    NSString *current = textView.text ?: @"";
    NSRange range = textView.selectedRange;
    if (range.location > current.length) {
        range = NSMakeRange(current.length, 0);
    }
    if (range.location + range.length > current.length) {
        range.length = (current.length - range.location);
    }
    NSString *replaceText = [current stringByReplacingCharactersInRange:range withString:(text ?: @"")];
    NSRange newSel = NSMakeRange(range.location + (text ? text.length : 0), 0);
    textView.text = replaceText;
    textView.selectedRange = newSel;
    id<UITextViewDelegate> del = textView.delegate;
    if ([del respondsToSelector:@selector(textViewDidChange:)]) {
        [del textViewDidChange:textView];
    }
}

@interface AtModel()

@property (nonatomic,strong) NSMutableArray *items;

@property (nonatomic, strong) NSString *gid;

@end

@implementation AtModel

//---------------------------------------------------------------------------------------------------
#pragma mark - 初始化

- (instancetype)initWith:(NSString *)gid
{
    self = [super init];
    if (self) {
        _items = [[NSMutableArray alloc] init];
        self.gid = gid;
    }
    return self;
}


//---------------------------------------------------------------------------------------------------
#pragma mark - 内部方法

- (void)clean
{
    [self.items removeAllObjects];
}

- (void)addAtItem:(AtBlock *)item
{
    [_items addObject:item];
}

- (AtBlock *)item:(NSString *)name
{    
    __block AtBlock *item;
    // 关于[NSArray enumerateObjectsUsingBlock:] 参见：https://www.jianshu.com/p/76ea00832f74
    [_items enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        AtBlock *object = obj;
        if ([object.name isEqualToString:name])
        {
            item = object;
            *stop = YES;
        }
    }];
    return item;
}

- (AtBlock *)removeName:(NSString *)name
{
    __block AtBlock *item;
    [_items enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        AtBlock *object = obj;
        if ([object.name isEqualToString:name]) {
            item = object;
            *stop = YES;
        }
    }];
    if (item) {
        [_items removeObject:item];
    }
    return item;
}

- (NSArray<NSString *> *)matchString:(NSString *)sendText
{
    NSString *pattern = [NSString stringWithFormat:@"%@([^%@]+)%@",NIMInputAtStartChar,NIMInputAtEndChar,NIMInputAtEndChar];
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:&error];
    NSArray *results = [regex matchesInString:sendText options:0 range:NSMakeRange(0, sendText.length)];
    
    NSLog(@">>>>>>>>>>>>>> 【正在针对@对象matchString】pattern=%@，本次匹配的文本内容=%@，匹配完成的结果有 %ld 个", pattern, sendText, [results count]);
    
    NSMutableArray<NSString *> *matchs = [[NSMutableArray alloc] init];
    for (NSTextCheckingResult *result in results) {
        NSString *name = [sendText substringWithRange:result.range];
        
        NSLog(@">>>>>>>>>>>>>> 【正在针对@对象matchString-。。】本次匹配完成的name=%@", name);
        
        name = [name substringFromIndex:1];
        name = [name substringToIndex:name.length - 1];
        [matchs addObject:name];
    }
    return matchs;
}


//---------------------------------------------------------------------------------------------------
#pragma mark - 对外开放的方法

- (AtBlock *)delRangeForAt:(UITextView *)textView
{
    NSString *text = textView.text;
    NSRange range = [self rangeForPrefix:NIMInputAtStartChar suffix:NIMInputAtEndChar target:textView];
    NSRange selectedRange = [textView selectedRange];
    AtBlock *item = nil;
    if (range.length > 1)
    {
        NSString *name = [text substringWithRange:range];
        NSString *set = [NIMInputAtStartChar stringByAppendingString:NIMInputAtEndChar];
        name = [name stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:set]];
        item = [self item:name];
        range = item? range : NSMakeRange(selectedRange.location - 1, 1);
    }
    item.range = range;
    return item;
}

- (NSRange)rangeForPrefix:(NSString *)prefix suffix:(NSString *)suffix target:(UITextView *)textView
{
    NSString *text = textView.text;
    NSRange range = [textView selectedRange];
    NSString *selectedText = range.length ? [text substringWithRange:range] : text;
    NSInteger endLocation = range.location;
    if (endLocation <= 0)
    {
        return NSMakeRange(NSNotFound, 0);
    }
    NSInteger index = -1;
    if ([selectedText hasSuffix:suffix]) {
        //往前搜最多20个字符，一般来讲是够了...
        NSInteger p = 20;
        for (NSInteger i = endLocation; i >= endLocation - p && i-1 >= 0 ; i--)
        {
            NSRange subRange = NSMakeRange(i - 1, 1);
            NSString *subString = [text substringWithRange:subRange];
            if ([subString compare:prefix] == NSOrderedSame)
            {
                index = i - 1;
                break;
            }
        }
    }
    return index == -1? NSMakeRange(endLocation - 1, 1) : NSMakeRange(index, endLocation - index);
}

- (void)addAtUser:(TargetEntity *)selectedUser target:(UITextView *)textView
{
    NSMutableString *str = [[NSMutableString alloc] initWithString:@"@"];
    [self addAtUser:selectedUser prefix:str target:textView];
}

- (void)addAtUser:(TargetEntity *)selectedUser prefix:(NSMutableString *)str target:(UITextView *)textView
{
    NSString *nick = selectedUser.targetName;
    [str appendString:nick];
    [str appendString:NIMInputAtEndChar];
    
    AtBlock *item = [[AtBlock alloc] init];
    item.uid  = selectedUser.targetId;
    item.name = nick;
    [self addAtItem:item];
    
    if ([textView respondsToSelector:@selector(insertTextStr:)]) {
        [(JSQMessagesComposerTextView *)textView insertTextStr:str];
    } else {
        AtModelInsertPlainTextIntoComposer(textView, str);
    }
}

- (NSArray<NSString *> *)getAtUsers:(NSString *)sendText;
{
    NSArray<NSString *> *names = [self matchString:sendText];
    NSMutableArray<NSString *> *uids = [[NSMutableArray alloc] init];
    for (NSString *name in names) {
        AtBlock *item = [self item:name];
        if (item)
        {
            [uids addObject:item.uid];
        }
    }
    
    // 去掉数组中同一个uid的重复情况
    if([uids count] > 0) {
        NSOrderedSet *orderedSet = [[NSOrderedSet orderedSetWithArray:uids] copy];
        return [orderedSet array];
    }
    
    return [NSArray arrayWithArray:uids];
}

- (void)showAtUserActivity:(BOOL)needInsertAitInText nav:(UINavigationController *)navigationController delegate:(id<UserChooseCompleteDelegate>)userChooseCompleteDelegate {
    // 进入转发目标选择界面
    [ViewControllerFactory goTargetChooseViewController:navigationController
                                              supportedTargetSource:TargetSourceGroupMember
                                               latestChattingFilter:nil
                                                       friendFilter:nil
                                                        groupFilter:nil
                                      groupMemberFilter:[TargetSourceFilterFactory createTargetSourceFilterGroupMember4At]
                                                           extraObj:@(needInsertAitInText)
                                                    gid:self.gid
                                                        requestCode:TARGET_CHOOSE_REQUEST_CODE_FOR_AT
                                                           delegate:userChooseCompleteDelegate];
    }


@end


@implementation AtBlock

@end
