//
//  APCReferralCodeViewController.h
//  APCAppCore
//
//  Created by Josh Bruhin on 2/6/17.
//  Copyright © 2017 Apple, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "APCUser.h"
#import "APCReferralCodeTextField.h"

@interface APCReferralCodeViewController : UIViewController <UITextFieldDelegate, APCReferralCodeTextFieldDelegate>

@property (assign, nonatomic) UIBarButtonItem *saveButton;
@property (strong, nonatomic) NSArray *textFields;
@property (weak, nonatomic) IBOutlet UIView *textFieldContainView;

// abstract methods
- (void)setupSaveButton;
- (IBAction)saveHit:(id)sender;
- (APCUser *)currentUser;
- (void)updateControls;

@end
