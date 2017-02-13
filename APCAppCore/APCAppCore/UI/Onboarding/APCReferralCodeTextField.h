//
//  APCReferralCodeTextField.h
//  APCAppCore
//
//  Created by Josh Bruhin on 2/10/17.
//  Copyright © 2017 Apple, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@class APCReferralCodeTextField;

@protocol APCReferralCodeTextFieldDelegate <NSObject>

@optional
/*
 Tell our delegate that the backspace key was hit so it can go to previous textField.
 This is necessary because there are no other standard UITextField delegate methods called
 when backspace key is hit and the textField is empty
 */
- (void)APCReferralCodeTextFieldDidBackspace:(APCReferralCodeTextField*)textField;
@end

@interface APCReferralCodeTextField : UITextField<UIKeyInput>

@property (nonatomic, assign)   id<APCReferralCodeTextFieldDelegate> referallCodeTextFieldDelegate;
@property (nonatomic, copy)     NSString *regexString;

/*
 Track pending text changes on the textField since the textField contents are evaluated
 before the textField is updated with the pending changes
 */
@property (nonatomic, copy)     NSString *pendingText;

@property (assign)              NSUInteger numChars;

/*
 This will check current content against our regex string
 */
@property (readonly)            BOOL isValid;

/*
 This will determine which field the user can tap on the begin editing. We don't want them
 to tap on field that are already filled in, for instance, so our delegate controls that by
 setting this flag
 */
@property (assign)              BOOL isActive;

@property (assign)              BOOL isEmpty;

- (BOOL)isValidWithString:(NSString*)string;

@end
