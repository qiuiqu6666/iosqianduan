//telegram @wz662
#import "rbRMMapper.h"
#import <objc/runtime.h>

//** 20170415 by JackJiang：修改了相关方法，从而实现了可支持对父类的属性进行转JSON
@implementation rbRMMapper


static const char *getPropertyType(objc_property_t property) {
    const char *attributes = property_getAttributes(property);
    //printf("attributes=%s\n", attributes);
    char buffer[1 + strlen(attributes)];
    strcpy(buffer, attributes);
    char *state = buffer, *attribute;
    while ((attribute = strsep(&state, ",")) != NULL) {
        if (attribute[0] == 'T' && attribute[1] != '@') {
            // it's a C primitive type:
            /*
             if you want a list of what will be returned for these primitives, search online for
             "objective-c" "Property Attribute Description Examples"
             apple docs list plenty of examples of what you get for int "i", long "l", unsigned "I", struct, etc.
             */
            NSString *name = [[NSString alloc] initWithBytes:attribute + 1 length:strlen(attribute) - 1 encoding:NSASCIIStringEncoding];
            return (const char *)[name cStringUsingEncoding:NSASCIIStringEncoding];
        }
        else if (attribute[0] == 'T' && attribute[1] == '@' && strlen(attribute) == 2) {
            // it's an ObjC id type:
            return "id";
        }
        else if (attribute[0] == 'T' && attribute[1] == '@') {
            // it's another ObjC object type:
            NSString *name = [[NSString alloc] initWithBytes:attribute + 3 length:strlen(attribute) - 4 encoding:NSASCIIStringEncoding];
            return (const char *)[name cStringUsingEncoding:NSASCIIStringEncoding];
        }
    }
    return "";
}

#pragma mark - Get properties for a class
+ (NSDictionary *)propertiesForClass:(Class)cls
{
    if (cls == NULL) {
        return nil;
    }
    
    NSMutableDictionary *results = [[NSMutableDictionary alloc] init];
    unsigned int outCount, i;
    objc_property_t *properties = class_copyPropertyList(cls, &outCount);
    for (i = 0; i < outCount; i++) {
        objc_property_t property = properties[i];
        const char *propName = property_getName(property);
        if(propName) {
            const char *propType = getPropertyType(property);
            NSString *propertyName = [NSString stringWithUTF8String:propName];
            NSString *propertyType = [NSString stringWithUTF8String:propType];
            [results setObject:propertyType forKey:propertyName];
        }
    }
    free(properties);

    // returning a copy here to make sure the dictionary is immutable
    return [NSDictionary dictionaryWithDictionary:results];
}

//** 20170415被JackJiang改造支持父类属性后的方法(在原propertiesForClass的基础上增加了循环读取父类属性直到顶级父类NSObject)
+ (NSDictionary *)propertiesForClass2:(id)obj
{
    if (obj == nil) {
        return nil;
    }

    NSMutableDictionary *results = [[NSMutableDictionary alloc] init];
    unsigned int outCount;
    Class class = [obj class];
    do { // 加这个do-while是为了将父类的属性页进行遍历

        objc_property_t *properties = class_copyPropertyList(class, &outCount);
        for (int i = 0; i < outCount; i++) {
            objc_property_t property = properties[i];
            const char *propName = property_getName(property);
            if(propName) {
                const char *propType = getPropertyType(property);
                NSString *propertyName = [NSString stringWithUTF8String:propName];
                NSString *propertyType = [NSString stringWithUTF8String:propType];
//                NSLog(@">>>>>>>>>>>>>>> 000 propertyName=%@, propertyType=%@", propertyName, propertyType);
                [results setObject:propertyType forKey:propertyName];
            }
        }
        free(properties);

        class = [class superclass];
    } while (class != [NSObject class]);

    // returning a copy here to make sure the dictionary is immutable
    return [NSDictionary dictionaryWithDictionary:results];
}

+(id)populateObject:(id)obj fromDictionary:(NSDictionary *)dict exclude:(NSArray *)excludeArray {
    if (obj == nil) {
        return nil;
    }
    
    Class cls = [obj class];

//    //** 20180525 jackjiang修改为支持父类属性前的代码
//    NSDictionary* properties = [RMMapper propertiesForClass:cls];

    //** 20180525 jackjiang修改为支持父类属性后的代码
    NSDictionary* properties = [rbRMMapper propertiesForClass2:obj];

    // Since key of object is a string, we need to check the dict contains
    // string as key. If it contains non-string key, the key will be skipped.
    // If key is not inside the object properties, it's skipped too.
    // Otherwise assign value of key from dict to obj
    for (id key in dict) {
        // Skip for non-string key
        if ([key isKindOfClass:[NSString class]] == NO) {
            NSLog(@"TDUtils: key must be NSString. Received key %@", key);
            continue;
        }
        
        // If key is not inside the object properties, skip it
        if ([properties objectForKey:key] == nil) {
//            NSLog(@"TDUtils: key %@ is not existed in class %@", key, NSStringFromClass(cls));
            continue;
        }
        
        // If key inside excludeArray, skip it
        if (excludeArray && [excludeArray indexOfObject:key] != NSNotFound) {
            NSLog(@"TDUtils: key %@ is skipped", key);
            continue;
        }
        
        // For string-key
        id value = [dict objectForKey:key];
        
        
        // If the property type is NSString and the value is array,
        // join them with ","
        NSString *propertyType = [properties objectForKey:key];
        if ([propertyType isEqualToString:@"NSString"] \
            && [value isKindOfClass:[NSArray class]]) {
            NSArray* arr = (NSArray*) value;
            NSString* arrString = [arr componentsJoinedByString:@","];
            [obj setValue:arrString forKey:key];
        }
        
        else {
            // If the property type is a custom class (not NSDictionary),
            // and the value is a dictionary,
            // convert the dictionary to object of that class
            if ([propertyType isEqualToString:@"NSString"] == NO &&
                [propertyType isEqualToString:@"NSDictionary"] == NO &&
                [value isKindOfClass:[NSDictionary class]]) {
                
                // Init a child attribute with respective class
                Class objCls = NSClassFromString(propertyType);
                id childObj = [[objCls alloc] init];
                
                // Populate data from the value
                [rbRMMapper populateObject:childObj fromDictionary:value exclude:nil];
                
                [obj setValue:childObj forKey:key];
            }
            
            // Else, set value for key
            else {
                [obj setValue:value forKey:key];
            }
        }
    }
    
    return obj;
}


+(id)populateObject:(id)obj fromDictionary:(NSDictionary *)dict {
    obj = [rbRMMapper populateObject:obj fromDictionary:dict exclude:nil];
    
    return obj;
}


+ (id)objectWithClass:(Class)cls fromDictionary:(NSDictionary *)dict {
    id obj = [[cls alloc] init];
    
    [rbRMMapper populateObject:obj fromDictionary:dict];
    
    return obj;
}


+ (NSMutableDictionary *)mutableDictionaryForObject:(id)obj {
    //** 20170415 jackjiang修改为支持父类属性前的代码
//    NSDictionary* propertyDict = [RMMapper propertiesForClass:[obj class]];

    //** 20170415 jackjiang修改为支持父类属性后的代码
    NSDictionary* propertyDict = [rbRMMapper propertiesForClass2:obj];

    NSMutableDictionary* objDict = [NSMutableDictionary dictionaryWithDictionary:propertyDict];
    for (NSString* key in propertyDict) {
        id val = [obj valueForKey:key];
        [objDict setValue:val forKey:key];
    }

    return objDict;
}

+(NSMutableDictionary *)mutableDictionaryForObject:(id)obj include:(NSArray *)includeArray {
    NSDictionary* dict = [rbRMMapper dictionaryForObject:obj include:includeArray];
    return [NSMutableDictionary dictionaryWithDictionary:dict];
}

+(NSDictionary*)dictionaryForObject:(id)obj {
    NSMutableDictionary *mutableDict = [rbRMMapper mutableDictionaryForObject:obj];
    return [NSDictionary dictionaryWithDictionary:mutableDict];
}

+ (NSDictionary*) dictionaryForObject:(id)obj include:(NSArray*)includeArray {
    NSDictionary* propertyDict = [rbRMMapper propertiesForClass:[obj class]];
    
    NSMutableDictionary* objDict = [NSMutableDictionary dictionaryWithCapacity:includeArray.count];
    for (NSString* key in propertyDict) {
        if (includeArray && [includeArray indexOfObject:key] == NSNotFound) {
            NSLog(@"TDUtils: key %@ is skipped", key);
            continue;
        }
        
        id val = [obj valueForKey:key];
        [objDict setValue:val forKey:key];
    }
    
    return objDict;
}

+(NSArray *)arrayOfClass:(Class)cls fromArrayOfDictionary:(NSArray *)array {
    NSMutableArray *mutableArray = [rbRMMapper mutableArrayOfClass:cls fromArrayOfDictionary:array];
    
    NSArray *arrWithClass = [NSArray arrayWithArray:mutableArray];
    return arrWithClass;
}

+(NSMutableArray *)mutableArrayOfClass:(Class)cls fromArrayOfDictionary:(NSArray *)array {
    NSMutableArray *mutableArray = [[NSMutableArray alloc] initWithCapacity:[array count]];
    
    for (id item in array) {
        // The item must be a dictionary. Otherwise, skip it
        if ([item isKindOfClass:[NSDictionary class]] == NO) {
            NSLog(@"TDUtils: item inside array must be NSDictionary object");
            continue;
        }
        
        // Convert item dictionary to object with predefined class
        id obj = [rbRMMapper objectWithClass:cls fromDictionary:item];
        [mutableArray addObject:obj];
    }
    
    return mutableArray;
}



@end
