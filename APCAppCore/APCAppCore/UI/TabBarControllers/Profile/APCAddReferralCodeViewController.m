//
//  APCAddReferralCodeViewController.m
//  APCAppCore
//
//  Created by Josh Bruhin on 2/6/17.
//  Copyright © 2017 Apple, Inc. All rights reserved.
//

#import "APCAddReferralCodeViewController.h"
#import "APCLocalization.h"
#import "APCCustomBackButton.h"
#import "APCAppDelegate.h"

#import "UIColor+APCAppearance.h"

@interface APCReferralCodeViewController ()
- (void)setupAppearance;
- (NSString*)finalString;
- (void)resignFirstResponderOnAll;
- (BOOL)codeIsValid;
@end

@interface APCAddReferralCodeViewController ()

@end

@implementation APCAddReferralCodeViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    UIBarButtonItem  *backster = [APCCustomBackButton customBackBarButtonItemWithTarget:self action:@selector(goBack) tintColor:[UIColor appPrimaryColor]];
    [self.navigationItem setLeftBarButtonItem:backster];
}
//
//- (void)viewWillAppear:(BOOL)animated {
//    [super viewWillAppear:animated];
////    [self.textField becomeFirstResponder];
//}

#pragma mark - Overrides

- (void)setupSaveButton {
    UIBarButtonItem *saveBarButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedStringWithDefaultValue(@"Save", @"APCAppCore", APCBundle(), @"Save", @"")
                                                                      style:UIBarButtonItemStylePlain
                                                                     target:self
                                                                     action:@selector(saveHit:)];
    self.saveButton = saveBarButton;
    self.saveButton.enabled = NO;
}

- (void)setSaveButton:(UIBarButtonItem *)saveButton {
    self.navigationItem.rightBarButtonItem = saveButton;
}
- (UIBarButtonItem*)saveButton {
    return self.navigationItem.rightBarButtonItem;
}

- (APCUser *)currentUser {
    return [[APCAppDelegate sharedAppDelegate] dataSubstrate].currentUser;
}

- (void)updateControls {
    self.saveButton.enabled = [self codeIsValid];
}

- (void)saveSucceededWithSpinnerController:(APCSpinnerViewController*)spinnerController {
    [spinnerController showCheckmarkThenDismissCompletion:^{
        [self goBack];
    }];
}

#pragma mark - Actions

- (void)goBack {
    [self resignFirstResponderOnAll];
    [self.navigationController popToRootViewControllerAnimated:YES];
}

@end
