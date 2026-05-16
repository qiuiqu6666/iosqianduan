//telegram @wz662
#import "TableRoot.h"

@implementation TableRoot

- (FMResultSet *)query:(FMDatabase *)db tableName:(NSString *)tableName fieldNamesStr:(NSString *)fieldNamesWithStr filterSQL:(NSString *)filterSQL debugTag:(NSString *)tag
{
    if(fieldNamesWithStr == nil)
    {
        NSAssert(NO, @"无效的参数 fieldNamesWithStr==nil! 发生于方法： %s", __PRETTY_FUNCTION__);
        return nil;
    }

    NSString *whereStr = @"";
    if(filterSQL != nil)
        whereStr = [NSString stringWithFormat:@"WHERE %@", filterSQL];

    NSMutableString *sql = [NSMutableString stringWithFormat:@""];
    if(tableName != nil)
    {
        [sql appendFormat:@"SELECT %@ FROM %@ %@", fieldNamesWithStr, tableName, whereStr];
    }
    else
    {
        NSAssert(NO, @"无效的参数 tableName==nil! 发生于方法： %s", __PRETTY_FUNCTION__);
        return nil;
    }

    NSLog(@"[sqlite-%@] 组织完成的查询语句：%@", tag, sql);

    //获取结果集，返回参数就是查询结果
    FMResultSet *rs = [db executeQuery:sql];

    return rs;
}

- (FMResultSet *)query:(FMDatabase *)db tableName:(NSString *)tableName fieldNames:(NSArray<NSString *> *)fieldNames filterSQL:(NSString *)filterSQL debugTag:(NSString *)tag
{
    NSMutableString *fieldsStr = [NSMutableString stringWithFormat:@""];

    // 将数组组织的表字段，转成形如“a,b,c”这样的SQL字段字形串形式
    if(fieldNames != nil)
    {
//      for(NSString *field in fieldNames)
        for (int i=0; i< [fieldNames count]; i++)
        {
            NSString *f = [NSString stringWithFormat:@"%@%@", (i==0?@"":@","), [fieldNames objectAtIndex:i]];
            [fieldsStr appendString:f];
        }
    }
    else
    {
        NSAssert(NO, @"无效的参数 fieldNames==nil! 发生于方法： %s", __PRETTY_FUNCTION__);
        return nil;
    }
    
    return [self query:db tableName:tableName fieldNamesStr:fieldsStr filterSQL:filterSQL debugTag:tag];
}

- (BOOL) delete:(FMDatabase *)db tableName:(NSString *)tableName filterSQL:(NSString *)filterSQL debugTag:(NSString *)tag
{
    NSString *sql = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@", tableName, filterSQL];
    DDLogDebug(@"[sqlite-%@] 组织完成的SQL语句：%@", tag, sql);
    return [db executeUpdate:sql];
}

@end
