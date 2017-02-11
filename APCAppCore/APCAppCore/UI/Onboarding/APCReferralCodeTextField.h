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
- (void)APCReferralCodeTextFieldDidBackspace:(APCReferralCodeTextField*)textField;
@end

@interface HTTextField : UITextField<UIKeyInput>

@property (nonatomic, assign) id<APCReferralCodeTextFieldDelegate> backspaceDelegate;

@end


@interface APCReferralCodeTextField : UITextField

@property (nonatomic, assign)   id<APCReferralCodeTextFieldDelegate> referallCodeTextFieldDelegate;
@property (nonatomic, copy)     NSString *regexString;
@property (nonatomic, copy)     NSString *pendingText;
@property (assign)              NSUInteger numChars;
@property (readonly)            BOOL isValid;
@property (assign)              BOOL isActive;
@property (assign)              BOOL isEmpty;

- (BOOL)isValidWithString:(NSString*)string;

@end
