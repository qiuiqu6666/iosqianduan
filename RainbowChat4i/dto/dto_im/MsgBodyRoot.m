//telegram @wz662
#import "MsgBodyRoot.h"
#import "EVAToolKits.h"

@implementation MsgBodyRoot

- (id)init
{
    if(self = [super init])
    {
        // 默认属性初始化
        self.cy = CHAT_TYPE_FREIDN_CHAT;
        self.ty = TM_TYPE_TEXT;
    }
    return self;
}

/**
 * 从JSON字串中反序列化。
 *
 * @param originalMsg 即MsgBodyRoot对象的JSON序列化文本
 * @return 解析成功则返回对象，否则返回null
 * @since 2.0_rc11
 */
+ (MsgBodyRoot *)parseFromSender:(NSString *)originalMsg
{
    //    return new Gson().fromJson(originalMsg, TextMessage.class);
    return [EVAToolKits fromJSON:originalMsg withClazz:MsgBodyRoot.class];
}

@end
