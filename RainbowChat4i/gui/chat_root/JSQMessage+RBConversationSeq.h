//
//  JSQMessage+RBConversationSeq.h
//  单聊 conversation_msg_seq（可选）：漫游/接口解析侧写入并持久化；不再用于 UI SeqGate 裁剪。
//

#import "JSQMessage.h"

NS_ASSUME_NONNULL_BEGIN

@interface JSQMessage (RBConversationSeq)

@property (nonatomic, assign) long long rb_conversationMsgSeq;
@property (nonatomic, copy, nullable) NSString *rb_renderContentCacheKey;
@property (nonatomic, strong, nullable) NSAttributedString *rb_renderContentAttributedText;
@property (nonatomic, copy, nullable) NSString *rb_renderQuoteCacheKey;
@property (nonatomic, strong, nullable) NSAttributedString *rb_renderQuoteAttributedText;

@property (nonatomic, strong, nullable) NSNumber *rb_cachedIsRedPacketNumber;
@property (nonatomic, strong, nullable) NSNumber *rb_cachedIsTransferNumber;
@property (nonatomic, copy, nullable) NSString *rb_cachedTransferAmount;
@property (nonatomic, copy, nullable) NSString *rb_cachedTransferRemark;
@property (nonatomic, copy, nullable) NSString *rb_cachedTransferAssetType;
@property (nonatomic, copy, nullable) NSString *rb_cachedRedPacketBlessing;
@property (nonatomic, copy, nullable) NSString *rb_cachedRedPacketExclusiveName;
@property (nonatomic, copy, nullable) NSString *rb_cachedRedPacketExclusiveUid;
@property (nonatomic, copy, nullable) NSString *rb_cachedRedPacketAmount;
@property (nonatomic, copy, nullable) NSString *rb_cachedRedPacketAssetType;

- (void)rb_clearRenderCaches;

@end

NS_ASSUME_NONNULL_END
