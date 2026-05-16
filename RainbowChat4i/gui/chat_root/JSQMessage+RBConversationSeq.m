//
//  JSQMessage+RBConversationSeq.m
//

#import "JSQMessage+RBConversationSeq.h"
#import <objc/runtime.h>

static const void *kJSQMsgRBConversationSeqKey = &kJSQMsgRBConversationSeqKey;
static const void *kRBRenderContentCacheKeyKey = &kRBRenderContentCacheKeyKey;
static const void *kRBRenderContentAttributedTextKey = &kRBRenderContentAttributedTextKey;
static const void *kRBRenderQuoteCacheKeyKey = &kRBRenderQuoteCacheKeyKey;
static const void *kRBRenderQuoteAttributedTextKey = &kRBRenderQuoteAttributedTextKey;
static const void *kRBCachedIsRedPacketNumberKey = &kRBCachedIsRedPacketNumberKey;
static const void *kRBCachedIsTransferNumberKey = &kRBCachedIsTransferNumberKey;
static const void *kRBCachedTransferAmountKey = &kRBCachedTransferAmountKey;
static const void *kRBCachedTransferRemarkKey = &kRBCachedTransferRemarkKey;
static const void *kRBCachedTransferAssetTypeKey = &kRBCachedTransferAssetTypeKey;
static const void *kRBCachedRedPacketBlessingKey = &kRBCachedRedPacketBlessingKey;
static const void *kRBCachedRedPacketExclusiveNameKey = &kRBCachedRedPacketExclusiveNameKey;
static const void *kRBCachedRedPacketExclusiveUidKey = &kRBCachedRedPacketExclusiveUidKey;
static const void *kRBCachedRedPacketAmountKey = &kRBCachedRedPacketAmountKey;
static const void *kRBCachedRedPacketAssetTypeKey = &kRBCachedRedPacketAssetTypeKey;

@implementation JSQMessage (RBConversationSeq)

- (void)setRb_conversationMsgSeq:(long long)rb_conversationMsgSeq
{
    objc_setAssociatedObject(self, kJSQMsgRBConversationSeqKey, @(rb_conversationMsgSeq), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (long long)rb_conversationMsgSeq
{
    NSNumber *n = objc_getAssociatedObject(self, kJSQMsgRBConversationSeqKey);
    return n ? n.longLongValue : 0;
}

- (void)setRb_renderContentCacheKey:(NSString *)rb_renderContentCacheKey
{
    objc_setAssociatedObject(self, kRBRenderContentCacheKeyKey, rb_renderContentCacheKey, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (NSString *)rb_renderContentCacheKey
{
    return objc_getAssociatedObject(self, kRBRenderContentCacheKeyKey);
}

- (void)setRb_renderContentAttributedText:(NSAttributedString *)rb_renderContentAttributedText
{
    objc_setAssociatedObject(self, kRBRenderContentAttributedTextKey, rb_renderContentAttributedText, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSAttributedString *)rb_renderContentAttributedText
{
    return objc_getAssociatedObject(self, kRBRenderContentAttributedTextKey);
}

- (void)setRb_renderQuoteCacheKey:(NSString *)rb_renderQuoteCacheKey
{
    objc_setAssociatedObject(self, kRBRenderQuoteCacheKeyKey, rb_renderQuoteCacheKey, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (NSString *)rb_renderQuoteCacheKey
{
    return objc_getAssociatedObject(self, kRBRenderQuoteCacheKeyKey);
}

- (void)setRb_renderQuoteAttributedText:(NSAttributedString *)rb_renderQuoteAttributedText
{
    objc_setAssociatedObject(self, kRBRenderQuoteAttributedTextKey, rb_renderQuoteAttributedText, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSAttributedString *)rb_renderQuoteAttributedText
{
    return objc_getAssociatedObject(self, kRBRenderQuoteAttributedTextKey);
}

- (void)setRb_cachedIsRedPacketNumber:(NSNumber *)rb_cachedIsRedPacketNumber
{
    objc_setAssociatedObject(self, kRBCachedIsRedPacketNumberKey, rb_cachedIsRedPacketNumber, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSNumber *)rb_cachedIsRedPacketNumber
{
    return objc_getAssociatedObject(self, kRBCachedIsRedPacketNumberKey);
}

- (void)setRb_cachedIsTransferNumber:(NSNumber *)rb_cachedIsTransferNumber
{
    objc_setAssociatedObject(self, kRBCachedIsTransferNumberKey, rb_cachedIsTransferNumber, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSNumber *)rb_cachedIsTransferNumber
{
    return objc_getAssociatedObject(self, kRBCachedIsTransferNumberKey);
}

- (void)setRb_cachedTransferAmount:(NSString *)rb_cachedTransferAmount
{
    objc_setAssociatedObject(self, kRBCachedTransferAmountKey, rb_cachedTransferAmount, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (NSString *)rb_cachedTransferAmount
{
    return objc_getAssociatedObject(self, kRBCachedTransferAmountKey);
}

- (void)setRb_cachedTransferRemark:(NSString *)rb_cachedTransferRemark
{
    objc_setAssociatedObject(self, kRBCachedTransferRemarkKey, rb_cachedTransferRemark, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (NSString *)rb_cachedTransferRemark
{
    return objc_getAssociatedObject(self, kRBCachedTransferRemarkKey);
}

- (void)setRb_cachedTransferAssetType:(NSString *)rb_cachedTransferAssetType
{
    objc_setAssociatedObject(self, kRBCachedTransferAssetTypeKey, rb_cachedTransferAssetType, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (NSString *)rb_cachedTransferAssetType
{
    return objc_getAssociatedObject(self, kRBCachedTransferAssetTypeKey);
}

- (void)setRb_cachedRedPacketBlessing:(NSString *)rb_cachedRedPacketBlessing
{
    objc_setAssociatedObject(self, kRBCachedRedPacketBlessingKey, rb_cachedRedPacketBlessing, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (NSString *)rb_cachedRedPacketBlessing
{
    return objc_getAssociatedObject(self, kRBCachedRedPacketBlessingKey);
}

- (void)setRb_cachedRedPacketExclusiveName:(NSString *)rb_cachedRedPacketExclusiveName
{
    objc_setAssociatedObject(self, kRBCachedRedPacketExclusiveNameKey, rb_cachedRedPacketExclusiveName, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (NSString *)rb_cachedRedPacketExclusiveName
{
    return objc_getAssociatedObject(self, kRBCachedRedPacketExclusiveNameKey);
}

- (void)setRb_cachedRedPacketExclusiveUid:(NSString *)rb_cachedRedPacketExclusiveUid
{
    objc_setAssociatedObject(self, kRBCachedRedPacketExclusiveUidKey, rb_cachedRedPacketExclusiveUid, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (NSString *)rb_cachedRedPacketExclusiveUid
{
    return objc_getAssociatedObject(self, kRBCachedRedPacketExclusiveUidKey);
}

- (void)setRb_cachedRedPacketAmount:(NSString *)rb_cachedRedPacketAmount
{
    objc_setAssociatedObject(self, kRBCachedRedPacketAmountKey, rb_cachedRedPacketAmount, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (NSString *)rb_cachedRedPacketAmount
{
    return objc_getAssociatedObject(self, kRBCachedRedPacketAmountKey);
}

- (void)setRb_cachedRedPacketAssetType:(NSString *)rb_cachedRedPacketAssetType
{
    objc_setAssociatedObject(self, kRBCachedRedPacketAssetTypeKey, rb_cachedRedPacketAssetType, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (NSString *)rb_cachedRedPacketAssetType
{
    return objc_getAssociatedObject(self, kRBCachedRedPacketAssetTypeKey);
}

- (void)rb_clearRenderCaches
{
    self.rb_renderContentCacheKey = nil;
    self.rb_renderContentAttributedText = nil;
    self.rb_renderQuoteCacheKey = nil;
    self.rb_renderQuoteAttributedText = nil;
}

@end
