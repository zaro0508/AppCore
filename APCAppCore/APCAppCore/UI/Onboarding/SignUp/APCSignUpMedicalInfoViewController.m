// 
//  APCSignUpMedicalInfoViewController.m 
//  APCAppCore 
// 
// Copyright (c) 2015, Apple Inc. All rights reserved. 
// 
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
// 
// 1.  Redistributions of source code must retain the above copyright notice, this
// list of conditions and the following disclaimer.
// 
// 2.  Redistributions in binary form must reproduce the above copyright notice, 
// this list of conditions and the following disclaimer in the documentation and/or 
// other materials provided with the distribution. 
// 
// 3.  Neither the name of the copyright holder(s) nor the names of any contributors 
// may be used to endorse or promote products derived from this software without 
// specific prior written permission. No license is granted to the trademarks of 
// the copyright holders even if such marks are included in this software. 
// 
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE 
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL 
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR 
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER 
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, 
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE 
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
// 
 
#import "APCSignUpMedicalInfoViewController.h"
#import "APCSpinnerViewController.h"
#import "APCOnboardingManager.h"
#import "APCStepProgressBar.h"
#import "APCPermissionButton.h"
#import "APCPermissionsManager.h"
#import "APCLog.h"
#import "APCLocalization.h"
#import "APCContainerStepViewController.h"
#import "APCNavigationFooter.h"

#import "UIAlertController+Helper.h"
#import "APCUser+Bridge.h"


@interface APCSignUpMedicalInfoViewController () <APCNavigationFooterDelegate>

@property (nonatomic, strong) APCPermissionsManager *permissionsManager;
@property (nonatomic) BOOL permissionGranted;

@end

@implementation APCSignUpMedicalInfoViewController

#pragma mark - View Life Cycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.tableView.tableHeaderView = nil;
    
    self.items = [self prepareContent];
    
    self.navigationItem.hidesBackButton = YES;
    
    self.permissionsManager = [(id<APCOnboardingManagerProvider>)[UIApplication sharedApplication].delegate onboardingManager].permissionsManager;
    self.permissionGranted = [self.permissionsManager isPermissionsGrantedForType:kAPCSignUpPermissionsTypeHealthKit];
    
    __weak typeof(self) weakSelf = self;
    if (!self.permissionGranted) {
        [self.permissionsManager requestForPermissionForType:kAPCSignUpPermissionsTypeHealthKit withCompletion:^(BOOL granted, NSError * __unused error) {
            if (granted) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    weakSelf.permissionGranted = YES;
                    weakSelf.items = [self prepareContent];
                    [weakSelf.tableView reloadData];
                });
            }
        }];
    }
    
    if (self.parentStepViewController == nil) {
        self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
    }
    
    self.title = NSLocalizedStringWithDefaultValue(@"Additional Information", @"APCAppCore", APCBundle(), @"Additional Information", @"Additional Information");
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [self.stepProgressBar setCompletedSteps:([self onboarding].onboardingTask.currentStepNumber - 1) animation:YES];
    APCLogViewControllerAppeared();
}

- (NSArray *)prepareContent {
    NSArray *profileElementsList = [self onboardingManager].permissionsManager.userInfoItemTypes;
    NSMutableArray *rowItems = [NSMutableArray new];
    
    for (NSNumber *type in profileElementsList) {
        
        APCUserInfoItemType itemType = type.integerValue;
        
        switch (itemType) {
            case kAPCUserInfoItemTypeBloodType:
            {
                APCTableViewCustomPickerItem *field = [APCTableViewCustomPickerItem new];
                field.caption = NSLocalizedStringWithDefaultValue(@"Blood Type", @"APCAppCore", APCBundle(), @"Blood Type", @"");
                field.reuseIdentifier = kAPCDefaultTableViewCellIdentifier;
                field.selectionStyle = UITableViewCellSelectionStyleGray;
                field.detailDiscloserStyle = YES;
                
                if (self.user.bloodType) {
                    field.selectedRowIndices = @[ @(self.user.bloodType) ];
                    field.editable = NO;
                }
                
                field.textAlignnment = NSTextAlignmentRight;
                field.pickerData = @[ [APCUser bloodTypeInStringValues] ];
                
                APCTableViewRow *row = [APCTableViewRow new];
                row.item = field;
                row.itemType = kAPCUserInfoItemTypeBloodType;
                [rowItems addObject:row];
                
            }
                break;
                
            case kAPCUserInfoItemTypeMedicalCondition:
            {
                APCTableViewCustomPickerItem *field = [APCTableViewCustomPickerItem new];
                field.caption = NSLocalizedStringWithDefaultValue(@"Medical Conditions", @"APCAppCore", APCBundle(), @"Medical Conditions", @"");
                field.reuseIdentifier = kAPCDefaultTableViewCellIdentifier;
                field.selectionStyle = UITableViewCellSelectionStyleGray;
                field.detailDiscloserStyle = YES;
                field.pickerData = @[ [APCUser medicalConditions] ];
                field.textAlignnment = NSTextAlignmentRight;
                if (self.user.medicalConditions) {
                    field.selectedRowIndices = @[ @([field.pickerData[0] indexOfObject:self.user.medicalConditions]) ];
                }
                else {
                    field.selectedRowIndices = @[ @(0) ];
                }
                
                APCTableViewRow *row = [APCTableViewRow new];
                row.item = field;
                row.itemType = kAPCUserInfoItemTypeMedicalCondition;
                [rowItems addObject:row];
            }
                break;
                
            case kAPCUserInfoItemTypeMedication:
            {
                APCTableViewCustomPickerItem *field = [APCTableViewCustomPickerItem new];
                field.caption = NSLocalizedStringWithDefaultValue(@"Medications", @"APCAppCore", APCBundle(), @"Medications", @"");
                field.reuseIdentifier = kAPCDefaultTableViewCellIdentifier;
                field.selectionStyle = UITableViewCellSelectionStyleGray;
                field.detailDiscloserStyle = YES;
                field.textAlignnment = NSTextAlignmentRight;
                field.pickerData = @[ [APCUser medications] ];
                
                if (self.user.medications) {
                    field.selectedRowIndices = @[ @([field.pickerData[0] indexOfObject:self.user.medications]) ];
                }
                else {
                    field.selectedRowIndices = @[ @(0) ];
                }
                
                APCTableViewRow *row = [APCTableViewRow new];
                row.item = field;
                row.itemType = kAPCUserInfoItemTypeMedication;
                [rowItems addObject:row];
            }
                break;
                
            case kAPCUserInfoItemTypeWakeUpTime:
            {
                APCTableViewDatePickerItem *field = [APCTableViewDatePickerItem new];
                field.caption = NSLocalizedStringWithDefaultValue(@"What time do you generally wake up?", @"APCAppCore", APCBundle(), @"What time do you generally wake up?", @"");
                field.placeholder = @"07:00 AM";
                field.reuseIdentifier = kAPCDefaultTableViewCellIdentifier;
                field.selectionStyle = UITableViewCellSelectionStyleGray;
                field.datePickerMode = UIDatePickerModeTime;
                field.dateFormat = kAPCMedicalInfoItemSleepTimeFormat;
                field.textAlignnment = NSTextAlignmentRight;
                field.detailDiscloserStyle = YES;
                
                if (self.user.wakeUpTime) {
                    field.date = self.user.wakeUpTime;
                } else {
                    field.date = [[NSCalendar currentCalendar] dateBySettingHour:7
                                                                          minute:0
                                                                          second:0
                                                                          ofDate:[NSDate date]
                                                                         options:0];
                }
                
                APCTableViewRow *row = [APCTableViewRow new];
                row.item = field;
                row.itemType = kAPCUserInfoItemTypeWakeUpTime;
                [rowItems addObject:row];
            }
                break;
                
            case kAPCUserInfoItemTypeSleepTime:
            {
                APCTableViewDatePickerItem *field = [APCTableViewDatePickerItem new];
                field.caption = NSLocalizedStringWithDefaultValue(@"What time do you generally go to sleep?", @"APCAppCore", APCBundle(), @"What time do you generally go to sleep?", @"");
                field.placeholder = @"09:30 PM";
                field.style = UITableViewCellStyleValue1;
                field.reuseIdentifier = kAPCDefaultTableViewCellIdentifier;
                field.selectionStyle = UITableViewCellSelectionStyleGray;
                field.datePickerMode = UIDatePickerModeTime;
                field.dateFormat = kAPCMedicalInfoItemSleepTimeFormat;
                field.textAlignnment = NSTextAlignmentRight;
                field.detailDiscloserStyle = YES;
                
                if (self.user.sleepTime) {
                    field.date = self.user.sleepTime;
                } else {
                    field.date = [[NSCalendar currentCalendar] dateBySettingHour:21
                                                                          minute:30
                                                                          second:0
                                                                          ofDate:[NSDate date]
                                                                         options:0];
                }
                
                APCTableViewRow *row = [APCTableViewRow new];
                row.item = field;
                row.itemType = kAPCUserInfoItemTypeSleepTime;
                [rowItems addObject:row];;
            }
                break;
                
            default: {
                APCTableViewRow *row = [self createTableViewRowForItemType:itemType user:self.user];
                if (row != nil) {
                    [rowItems addObject:row];
                }
            }
                break;
        }
    }
    
    APCTableViewSection *section = [APCTableViewSection new];
    section.rows = [NSArray arrayWithArray:rowItems];
    
    return @[section];
}

- (APCOnboardingManager *)onboardingManager {
    return [(id<APCOnboardingManagerProvider>)[UIApplication sharedApplication].delegate onboardingManager];
}

- (APCOnboarding *)onboarding {
    return [(id<APCOnboardingManagerProvider>)[UIApplication sharedApplication].delegate onboardingManager].onboarding;
}

#pragma mark - UIMethods

- (void)setupProgressBar {
    [self.stepProgressBar setCompletedSteps:([self onboarding].onboardingTask.currentStepNumber - 2) animation:NO];
}


#pragma mark - Private Methods

- (void)loadProfileValuesInModel {
    
    for (NSUInteger j=0; j<self.items.count; j++) {
        
        APCTableViewSection *section = self.items[j];
        
        for (NSUInteger i = 0; i < section.rows.count; i++) {
            
            APCTableViewRow *row = section.rows[i];
            
            APCTableViewItem *item = row.item;
            APCTableViewItemType itemType = row.itemType;
            
            switch (itemType) {
                case kAPCUserInfoItemTypeMedicalCondition:
                    self.user.medicalConditions = [(APCTableViewCustomPickerItem *)item stringValue];
                    break;
                    
                case kAPCUserInfoItemTypeMedication:
                    self.user.medications = [(APCTableViewCustomPickerItem *)item stringValue];
                    break;
                    
                default:
                    [self updateUser:self.user forItem:item itemType:itemType];
                    break;
            }
        }
    }
    
}

- (void)goForward {
    [self next];
}

- (IBAction) next {
    [self loadProfileValuesInModel];
    
    if (self.parentStepViewController != nil) {
        // If this has a step view controller parent then call goForward on the parent
        [self.parentStepViewController goForward];
    }
    else {
        // Otherwise, this uses APCOnboarding to handle navigation
        UIViewController *viewController = [[self onboarding] nextScene];
        [self.navigationController pushViewController:viewController animated:YES];
    }
}

@end
