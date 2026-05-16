//telegram @wz662
//
//  SearchResult.m
//  RainbowChat4i
//
//  Created by Jack Jiang on 2022/9/21.
//  Copyright © 2022 JackJiang. All rights reserved.
//

#import "SearchCompleteData.h"

@implementation SearchCompleteData

- (int)getSearchedCompleteDatas {
    if(self.searchedCompleteDatas != nil)
        return (int)[self.searchedCompleteDatas count];
    return 0;
}

@end
