//
//  APCAddReferralCodeViewController.m
//  APCAppCore
//
//  Created by Josh Bruhin on 2/6/17.
//  Copyright © 2017 Apple, Inc. All rights reserved.
//

#import "APCAddReferralCodeViewController.h"
#import "APCLocalization.h"
#import "APCSpinnerViewController.h"
#import "APCLog.h"
#import "APCCustomBackButton.h"
#import "APCAppDelegate.h"

#import "NSError+Bridge.h"
#import "UIColor+APCAppearance.h"

#import <BridgeSDK/BridgeSDK.h>

@interface APCReferralCodeViewController ()
- (void)setupAppearance;
@end

@interface APCAddReferralCodeViewController ()

@end

@implementation APCAddReferralCodeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupAppearance];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.textField becomeFirstResponder];
}

- (void)setupAppearance {
    
    [super setupAppearance];
    
    UIBarButtonItem  *backster = [APCCustomBackButton customBackBarButtonItemWithTarget:self action:@selector(goBack) tintColor:[UIColor appPrimaryColor]];
    [self.navigationItem setLeftBarButtonItem:backster];
}

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

- (void)textFieldTextDidChangeTo:(NSString*)text {
    
    [super textFieldTextDidChangeTo:text];
    
    // if we have no text, then disable our save button
    if (text.length == 0) {
        self.saveButton.enabled = NO;
    }
}

#pragma mark - Actions

- (IBAction)saveHit:(id __unused)sender {
    
    self.saveButton.enabled = NO;
    
    [self.textField resignFirstResponder];
    
    APCSpinnerViewController *spinnerController = [[APCSpinnerViewController alloc] init];
    [self presentViewController:spinnerController animated:YES completion:nil];
    
    typeof(self) __weak weakSelf = self;
    [SBBComponent(SBBParticipantManager) setExternalIdentifier:self.textField.text completion:^(id  _Nullable responseObject __unused, NSError * _Nullable error) {
        
        
        // get back to main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            
            if (error) {
                
                self.saveButton.enabled = YES;

                APCLogError2 (error);
                
                if (error.code == SBBErrorCodeInternetNotConnected || error.code == SBBErrorCodeServerNotReachable || error.code == SBBErrorCodeServerUnderMaintenance) {
                    [spinnerController dismissViewControllerAnimated:NO completion:^{
                        
                        UIAlertController *alertView = [UIAlertController alertControllerWithTitle:NSLocalizedStringWithDefaultValue(@"Referral Code", @"APCAppCore", APCBundle(), @"Referral Code", @"")
                                                                                           message:error.localizedDescription
                                                                                    preferredStyle:UIAlertControllerStyleAlert];
                        
                        UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
                                                                              handler:^(UIAlertAction * __unused action) {}];
                        
                        [alertView addAction:defaultAction];
                        [self presentViewController:alertView animated:YES completion:nil];
                    }];
                } else {
                    [spinnerController dismissViewControllerAnimated:NO completion:^{
                        
                        UIAlertController *alertView = [UIAlertController alertControllerWithTitle:NSLocalizedStringWithDefaultValue(@"Referral Code", @"APCAppCore", APCBundle(), @"Referral Code", @"")
                                                                                           message:error.message
                                                                                    preferredStyle:UIAlertControllerStyleAlert];
                        
                        UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"Cancel", @"APCAppCore", APCBundle(), @"Cancel", @"") style:UIAlertActionStyleCancel
                                                                             handler:^(UIAlertAction * __unused action) {
                                                                                 [self goBack];
                                                                             }];
                        
                        UIAlertAction* retryAction = [UIAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"Try Again", @"APCAppCore", APCBundle(), @"Try Again", nil) style:UIAlertActionStyleDefault
                                                                            handler:^(UIAlertAction * __unused action) {
                                                                                [weakSelf saveHit:nil];
                                                                            }];
                        
                        [alertView addAction:cancelAction];
                        [alertView addAction:retryAction];
                        [self presentViewController:alertView animated:YES completion:nil];
                        
                    }];
                }
            }
            else
            {
                // save our new referral code to current user
                [self currentUser].externalId = weakSelf.textField.text;
                
                [spinnerController showCheckmarkThenDismissCompletion:^{
                    [weakSelf goBack];
                }];
            }
        });
    }];
}

- (void)goBack {
    [self.textField resignFirstResponder];
    [self.navigationController popToRootViewControllerAnimated:YES];
}

@end
