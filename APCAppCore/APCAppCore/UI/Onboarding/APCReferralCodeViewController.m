//
//  APCReferralCodeViewController.m
//  APCAppCore
//
//  Created by Josh Bruhin on 2/6/17.
//  Copyright © 2017 Apple, Inc. All rights reserved.
//

#import "APCReferralCodeViewController.h"
#import "APCUser.h"
#import "APCContainerStepViewController.h"
#import "APCOnboardingManager.h"
#import "APCLocalization.h"
#import "APCUserInfoConstants.h"
#import "UIColor+APCAppearance.h"
#import "NSString+Helper.h"
#import "UIColor+APCAppearance.h"
#import "UIFont+APCAppearance.h"

@interface APCReferralCodeViewController ()

@end

@implementation APCReferralCodeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [self setupTextField];
    [self setupAppearance];
    [self setupSaveButton];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (APCContainerStepViewController *)parentStepViewController {
    if ([self.parentViewController isKindOfClass:[APCContainerStepViewController class]]) {
        return (APCContainerStepViewController*)self.parentViewController;
    }
    return nil;
}


- (APCOnboardingManager *)onboardingManager {
    return [(id<APCOnboardingManagerProvider>)[UIApplication sharedApplication].delegate onboardingManager];
}

- (APCOnboarding *)onboarding {
    return [self onboardingManager].onboarding;
}

#pragma mark - Setup

- (void)setupAppearance {
    [self.textField setTextColor:[UIColor appSecondaryColor1]];
    [self.textField setFont:[UIFont appRegularFontWithSize:16.0f]];
}

- (void)setupTextField {
    
    self.textField.validationDelegate = self;
    
    //Set Default Values
    self.textField.text = [self currentUser].externalId;
    [self textFieldTextDidChangeTo:self.textField.text];
}


#pragma mark - Abstract classes

- (void)setupSaveButton {
    UIBarButtonItem *nextBarButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedStringWithDefaultValue(@"Next", @"APCAppCore", APCBundle(), @"Next", @"")
                                                                      style:UIBarButtonItemStylePlain
                                                                     target:self
                                                                     action:@selector(saveHit:)];
    self.saveButton = nextBarButton;
}

- (APCUser *)currentUser {
    return [[self onboardingManager] userForOnboardingTask:[self parentStepViewController].taskViewController.task];
}

- (void)setSaveButton:(UIBarButtonItem *)saveButton {
    [self parentStepViewController].navigationItem.rightBarButtonItem = saveButton;
}
- (UIBarButtonItem*)saveButton {
    return [self parentStepViewController].navigationItem.rightBarButtonItem;
}


#pragma mark - Form validation

- (void)textFieldTextDidChangeTo:(NSString*)text
{
    //    [UIView animateWithDuration:0.3 animations:^{
    //        self.alertLabel.alpha = 0;
    //    }];
    
    BOOL valid = [self refCodeIsValid:text];
    self.textField.valid = valid;
    
    // if the textfield is empty, we don't want to show the invalid icon, so
    // optionally hide the text fields validate button
    self.textField.validationButton.hidden = text.length == 0;
    
    // enable the next button if the textField has no text or is valid
    self.saveButton.enabled = valid || text.length == 0;
}

- (BOOL)refCodeIsValid:(NSString*)refCode
{
    BOOL fieldValid = NO;
    
    if (refCode > 0) {
        fieldValid = [refCode isValidForRegex:kAPCUserInfoFieldReferralCodeRegEx];
        
        //        if (errorMessage && !fieldValid) {
        //            errorMessage = NSLocalizedStringWithDefaultValue(@"Please enter a valid referral code.", @"APCAppCore", APCBundle(), @"Please enter a valid referral code.", @"");
        //        }
    } else {
        //        if (errorMessage && !fieldValid) {
        //            errorMessage = NSLocalizedStringWithDefaultValue(@"Referral code cannot be left empty.", @"APCAppCore", APCBundle(), @"Referral code cannot be left empty.", @"");
        //        }
    }
    
    
    return fieldValid;
}

#pragma mark - Actions

- (IBAction)saveHit:(id __unused)sender {
    
    [self.textField resignFirstResponder];
    APCUser *currentUser = [self currentUser];
    currentUser.externalId = self.textField.text;
    
    
    [self goForward];
}

- (void)goForward {
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


#pragma mark - UITextField delegate

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    
    NSString *text = [textField.text stringByReplacingCharactersInRange:range withString:string];
    [self textFieldTextDidChangeTo:text];
    
    return YES;
}

#pragma mark - APCFormTextField delegate

- (void)formTextFieldDidTapValidButton:(APCFormTextField *)textField
{
    [self textFieldTextDidChangeTo:textField.text];
}

@end
