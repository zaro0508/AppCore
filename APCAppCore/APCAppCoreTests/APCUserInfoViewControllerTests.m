//
//  APCUserInfoViewControllerTests.m
//  APCAppCore
//
//  Created by Shannon Young on 6/15/16.
//  Copyright © 2016 Apple, Inc. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <APCAppCore/APCAppCore.h>
#import <HealthKit/HealthKit.h>

@interface APCUserInfoViewControllerTests : XCTestCase

@end

@interface MockUser : APCUser
@property (nonatomic, strong, nullable) HKQuantity * storedHeight;
@property (nonatomic, strong, nullable) HKQuantity * storedWeight;
@end

@implementation APCUserInfoViewControllerTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testUserUpdate_Weight_120lb {

    APCUser *user = [[MockUser alloc] init];
    APCUserInfoViewController *controller = [[APCUserInfoViewController alloc] init];

    APCTableViewTextFieldItem *textItem = [[APCTableViewTextFieldItem alloc] init];
    textItem.unit = [HKUnit poundUnit];
    textItem.value = @"120lb";
    
    [controller updateUser:user forItem:textItem itemType:kAPCUserInfoItemTypeWeight];
    
    HKQuantity *expected = [HKQuantity quantityWithUnit:[HKUnit poundUnit] doubleValue:120];
    XCTAssertEqualObjects(user.weight, expected);
}

- (void)testUserUpdate_Weight_120_lb {
    
    APCUser *user = [[MockUser alloc] init];
    APCUserInfoViewController *controller = [[APCUserInfoViewController alloc] init];
    
    APCTableViewTextFieldItem *textItem = [[APCTableViewTextFieldItem alloc] init];
    textItem.unit = [HKUnit gramUnitWithMetricPrefix:HKMetricPrefixKilo];   // kg
    textItem.value = @"120 lb";
    
    [controller updateUser:user forItem:textItem itemType:kAPCUserInfoItemTypeWeight];
    
    HKQuantity *expected = [HKQuantity quantityWithUnit:[HKUnit poundUnit] doubleValue:120];
    XCTAssertEqualObjects(user.weight, expected);
}

- (void)testUserUpdate_Weight_120_foo {
    
    APCUser *user = [[MockUser alloc] init];
    APCUserInfoViewController *controller = [[APCUserInfoViewController alloc] init];
    
    APCTableViewTextFieldItem *textItem = [[APCTableViewTextFieldItem alloc] init];
    textItem.unit = [HKUnit poundUnit]; // lb
    textItem.value = @"120 foo";
    
    [controller updateUser:user forItem:textItem itemType:kAPCUserInfoItemTypeWeight];
    
    HKQuantity *expected = [HKQuantity quantityWithUnit:[HKUnit poundUnit] doubleValue:120];
    XCTAssertEqualObjects(user.weight, expected);
}

- (void)testUserUpdate_Weight_65kg {
    
    APCUser *user = [[MockUser alloc] init];
    APCUserInfoViewController *controller = [[APCUserInfoViewController alloc] init];
    
    APCTableViewTextFieldItem *textItem = [[APCTableViewTextFieldItem alloc] init];
    textItem.unit = [HKUnit gramUnit];
    textItem.value = @"65.5 kg";
    
    [controller updateUser:user forItem:textItem itemType:kAPCUserInfoItemTypeWeight];
    
    HKQuantity *expected = [HKQuantity quantityWithUnit:[HKUnit gramUnitWithMetricPrefix:HKMetricPrefixKilo] doubleValue:65.5];
    XCTAssertEqualObjects(user.weight, expected);
}

@end

@implementation MockUser

- (HKQuantity *)weight {
    return self.storedWeight;
}

- (void)setWeight:(HKQuantity *)weight {
    self.storedWeight = weight;
}

- (HKQuantity *)height {
    return self.storedHeight;
}

- (void)setHeight:(HKQuantity *)height {
    self.storedHeight = height;
}

@end