//telegram @wz662
#import <Foundation/Foundation.h>
#import "ChatHistoryTable.h"
#import "AlarmsHistoryTable.h"
#import "GroupChatHistoryTable.h"
#import "CallRecordsCacheTable.h"
#import "FMDatabaseQueue.h"

@interface MyDataBase : NSObject

@property (nonatomic, retain, readonly) ChatHistoryTable *chatHistoryTable;
@property (nonatomic, retain, readonly) AlarmsHistoryTable *alarmsHistoryTable;
@property (nonatomic, retain, readonly) GroupChatHistoryTable *groupChatHistoryTable;
@property (nonatomic, retain, readonly) CallRecordsCacheTable *callRecordsCacheTable;

+(MyDataBase*)sharedInstance;
+(void)clean;

+(FMDatabaseQueue*)getDbQueue;
//+(void)createTable:(NSString*)tableString;
//+(void)dropTable:(NSString*)dropSQL;

+(void)inDatabase:(void (^)(FMDatabase *db))block;
//+(void)inTransaction:(void (^)(FMDatabase *db, BOOL *rollback))block finished:(void (^)())finished;
+(void)inTransaction:(void (^)(FMDatabase *db, BOOL *rollback))block;


/**
 用于安全的返回nil对象（用于NSArray等不能为nil的场景下）。
 <p>
 因为NSArray这样的集合里不允许放入nil单元，所以本方法可以智能判断，当此对象为nil时将自
 动返回NSNull（这是允许放入NSArray这样的集合里的），否则原样返回此对象不作处理
 </p>

 @param o 要被判断的对象
 @return 如果此对象为nil则返回NSNull对象，否则原样返回不作处理
 */
+ (NSObject *)nullSafe:(NSObject *)o;

+ (void)printErrorForDebug:(FMDatabase *)db tag:(NSString *)TAG;

@end
