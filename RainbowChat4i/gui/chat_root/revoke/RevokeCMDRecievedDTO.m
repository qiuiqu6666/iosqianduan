//telegram @wz662
//
//  RevokeCMDRecievedDTO.m
//  RainbowChat4i
//
//  Created by Jack Jiang on 2021/11/13.
//  Copyright © 2021 JackJiang. All rights reserved.
//

#import "RevokeCMDRecievedDTO.h"

@implementation RevokeCMDRecievedDTO

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: fpForRevokeCMD=%d, fpForRMessage=%@,>", [self class], self.fpForRevokeCMD, self.fpForRMessage];
}

@end
