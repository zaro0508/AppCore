//
//  NSDateCategoryTests.m
//  AppCore
//
//  Copyright (c) 2014 Apple Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "NSDate+Helper.h"


@interface NSDateCategoryTests : XCTestCase

@end


@implementation NSDateCategoryTests

/** Put setup code here. This method is called before the invocation of each test method in the class. */
- (void) setUp
{
	[super setUp];
}

/** Put teardown code here. This method is called after the invocation of each test method in the class. */
- (void) tearDown
{
    [super tearDown];
}

- (void) testDaysBetweenDates
{
    NSInteger daysBetween = [NSDate daysBetweenDate:[[NSDate date] dateByAddingDays:-5]
                                            andDate:[NSDate date]];
    XCTAssertEqual(5, daysBetween);
    
    daysBetween = [NSDate daysBetweenDate:[[NSDate date] dateByAddingDays:5]
                                  andDate:[NSDate date]];
    XCTAssertEqual(-5, daysBetween);
    
    daysBetween = [NSDate daysBetweenDate:[NSDate date]
                                  andDate:[NSDate date]];
    XCTAssertEqual(0, daysBetween);
}

@end
