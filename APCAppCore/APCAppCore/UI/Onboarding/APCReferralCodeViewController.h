//
//  APCReferralCodeViewController.h
//  APCAppCore
//
//  Created by Josh Bruhin on 2/6/17.
//  Copyright © 2017 Apple, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "APCFormTextField.h"
#import "APCUser.h"

@interface APCReferralCodeViewController : UIViewController <UITextFieldDelegate, APCFormTextFieldDelegate>

@property (weak, nonatomic) IBOutlet APCFormTextField *textField;
@property (assign, nonatomic) UIBarButtonItem *saveButton;

// abstract methods
- (void)setupSaveButton;
- (IBAction)saveHit:(id)sender;
- (APCUser *)currentUser;
- (void)textFieldTextDidChangeTo:(NSString*)text;

@end
