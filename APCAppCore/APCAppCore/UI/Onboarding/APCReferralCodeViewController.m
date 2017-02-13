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

static const CGFloat kTextFieldWidthPerChar = 11.0;
static const CGFloat kTextFieldExteriorSidePadding = 3.0;
static const NSString *kTextFieldRegexStringKey = @"regexString";
static const NSString *kTextFieldMaxCharCountKey = @"maxCharCountNumber";
static const NSString *kTextFieldDelimiterString = @"-";

@implementation APCReferralCodeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [self setupTextFields];
    [self setupSaveButton];
}

- (void)viewDidAppear:(BOOL)animated {
    
    [super viewDidAppear:animated];

    /*
     Need to call become first responder here. For some reason, the text field
     will  not become and remain first resonder. If this is called on viewDidLoad,
     the keyboard is visible for a split second but is then dismissed. If called
     on viewDidAppear, it never shows up. I think this has to do with the fact
     that this VC is a child VC of APCContainerStepViewController. The only way
     to get the textField to become and remain firstResponder is to dispatch the call
     to the main queue here
     */
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self becomeFirstResponderOnAppropriateField];
    });
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

- (void)setupTextFields {
    
    // Iterate our model and create text fields and delimiter labels
    // Also populate the text fields with current values, if any
    
    NSString *existingCode = [self currentUser].externalId;
    NSArray *existingCodeFields = [existingCode componentsSeparatedByString:[kTextFieldDelimiterString copy]];
    
    UIView *previousView = nil;
    NSArray *textFieldDicts = [self textFieldDefinitions];
    NSMutableArray *textFields = [[NSMutableArray alloc] initWithCapacity:textFieldDicts.count];
    for (NSUInteger i=0; i<textFieldDicts.count; i++) {
        NSDictionary *dict = textFieldDicts[i];
        NSString *regexString = dict[kTextFieldRegexStringKey];
        NSUInteger charCount = [dict[kTextFieldMaxCharCountKey] integerValue];
        
        APCReferralCodeTextField *textField = [[APCReferralCodeTextField alloc] initWithFrame:CGRectZero];
        textField.regexString = regexString;
        textField.numChars = charCount;
        textField.isActive = NO;
        textField.referallCodeTextFieldDelegate = self;
        
        textField.textColor = [UIColor appSecondaryColor1];
        textField.font = [UIFont appRegularFontWithSize:16.0];
        
        textField.keyboardType = UIKeyboardTypeNumberPad;
        textField.delegate = self;
        textField.translatesAutoresizingMaskIntoConstraints = NO;
        
        if (existingCodeFields && existingCodeFields.count > i) {
            NSString *fieldStr = existingCodeFields[i];
            if (fieldStr && [textField isValidWithString:fieldStr]) {
                textField.text = existingCodeFields[i];
            }
        }
        
        [textFields addObject:textField];
                
        CGFloat width = textField.numChars * kTextFieldWidthPerChar;
        width += i == textFieldDicts.count - 1 ? kTextFieldWidthPerChar : 0;
        
        // add constraints
        [self lockView:textField toPreviousView:previousView withWidth:width];
        
        previousView = (UIView*)textField;
        if (dict != [textFieldDicts lastObject]) {
            UILabel *delimiterLabel = [self newDelimiterLabel];
            [self lockView:delimiterLabel toPreviousView:previousView withWidth:delimiterLabel.frame.size.width];
            previousView = (UIView*)delimiterLabel;
        }
    }
    
    self.textFields = [NSArray arrayWithArray:textFields];
}

- (UILabel*)newDelimiterLabel {
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.text = [kTextFieldDelimiterString copy];
    label.textColor = [UIColor lightGrayColor];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [label sizeToFit];
    return label;
}

- (void)lockView:(UIView* __nonnull)view toPreviousView:(UIView* __nullable)prevView withWidth:(CGFloat)width {
    
    [self.textFieldContainView addSubview:view];
    
    NSLayoutAttribute leftAttr = prevView ? NSLayoutAttributeTrailing : NSLayoutAttributeLeading;
    UIView *leftAlignView = prevView ? prevView : self.textFieldContainView;
    
    [self.textFieldContainView addConstraint:[NSLayoutConstraint constraintWithItem:view
                                                                          attribute:NSLayoutAttributeLeading
                                                                          relatedBy:NSLayoutRelationEqual
                                                                             toItem:leftAlignView
                                                                          attribute:leftAttr
                                                                         multiplier:1.0
                                                                           constant:kTextFieldExteriorSidePadding]];
    
    [self.textFieldContainView addConstraint:[NSLayoutConstraint constraintWithItem:view
                                                                          attribute:NSLayoutAttributeTop
                                                                          relatedBy:NSLayoutRelationEqual
                                                                             toItem:self.textFieldContainView
                                                                          attribute:NSLayoutAttributeTop
                                                                         multiplier:1.0
                                                                           constant:0.0]];

    [self.textFieldContainView addConstraint:[NSLayoutConstraint constraintWithItem:view
                                                                          attribute:NSLayoutAttributeBottom
                                                                          relatedBy:NSLayoutRelationEqual
                                                                             toItem:self.textFieldContainView
                                                                          attribute:NSLayoutAttributeBottom
                                                                         multiplier:1.0
                                                                           constant:0.0]];

    [view addConstraint:[NSLayoutConstraint constraintWithItem:view
                                                          attribute:NSLayoutAttributeWidth
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:nil
                                                          attribute:NSLayoutAttributeNotAnAttribute
                                                         multiplier:1.0
                                                           constant:width]];
}

#pragma mark - TextField model

- (NSArray*)textFieldDefinitions {
    
    // configure each text field with a regex string for validation and a
    // max character count (used only with setting width on field
    
    // TODO: parse char count from regex string instead of setting it explicitly here
    
    return @[@{kTextFieldRegexStringKey:@"[0-9]{2}", kTextFieldMaxCharCountKey:[NSNumber numberWithInteger:2]},
             @{kTextFieldRegexStringKey:@"[0-9]{3}", kTextFieldMaxCharCountKey:[NSNumber numberWithInteger:3]},
             @{kTextFieldRegexStringKey:@"[0-9]{3}", kTextFieldMaxCharCountKey:[NSNumber numberWithInteger:3]}];
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

- (NSString*)finalString {
    return [self concatStringWithDelimiter:YES];
}

- (NSString*)concatStringWithDelimiter:(BOOL)withDelimiter {
    NSMutableString *mString = [[NSMutableString alloc] initWithString:@""];
    for (APCReferralCodeTextField *textField in self.textFields) {
        if (textField.pendingText) {
            [mString appendString:textField.pendingText];
        }
        else {
            [mString appendString:textField.text];
        }
        if (withDelimiter && textField != [self.textFields lastObject]) {
            [mString appendString:[kTextFieldDelimiterString copy]];
        }
    }
    return [NSString stringWithString:mString];
}

- (BOOL)codeIsValid {
    
    // iterate our textFields and check valid state for each
    
    BOOL valid = YES;
    for (APCReferralCodeTextField *textField in self.textFields) {
        valid = textField.isValid;
        if (!valid) {
            break;
        }
    }
    return valid;
}

- (void)updateControls {
    self.saveButton.enabled = [self codeIsValid] || [self concatStringWithDelimiter:NO].length == 0;
}

#pragma mark - Actions

- (IBAction)saveHit:(id __unused)sender {
    
    // save referral code to user and continue
    
    [self resignFirstResponderOnAll];
    APCUser *currentUser = [self currentUser];
    currentUser.externalId = [self finalString];
    
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

- (void)goToTextFieldBeforeTextField:(APCReferralCodeTextField*)textField deleteChar:(BOOL)deleteChar {
    NSUInteger idx = [self.textFields indexOfObject:textField];
    if (idx > 0) {
        textField.isActive = NO;
        APCReferralCodeTextField *newTextField = self.textFields[idx - 1];
        newTextField.isActive = YES;
        if (deleteChar && newTextField.text.length > 0) {
            newTextField.text = [newTextField.text substringToIndex:newTextField.text.length - 1];
        }
        [newTextField becomeFirstResponder];
    }
}

- (void)goToTextFieldAfterTextField:(APCReferralCodeTextField*)textField {
    NSUInteger idx = [self.textFields indexOfObject:textField];
    if (idx + 1 < self.textFields.count) {
        textField.isActive = NO;
        APCReferralCodeTextField *newTextField = self.textFields[idx + 1];
        newTextField.isActive = YES;
        [newTextField becomeFirstResponder];
    }
}

- (void)resignFirstResponderOnAll {
    for (UITextField *textField in self.textFields) {
        if (textField.isFirstResponder) {
            [textField resignFirstResponder];
        }
    }
}

- (void)becomeFirstResponderOnAppropriateField {
    
    // tell the first empty text field to becomeFirstReponder. If none are empty,
    // then tell the last field to becomeFirstResponder
    
    if (self.textFields.count > 0) {
        for (APCReferralCodeTextField *textField in self.textFields) {
            if (textField.text.length == 0 || textField == [self.textFields lastObject]) {
                textField.isActive = YES;
                
                if ([textField canBecomeFirstResponder]) {
                    [textField becomeFirstResponder];
                }
                else {
                    NSLog(@"got it");
                }
                
                break;
            }
        }
    }
}

#pragma mark - UITextField delegate

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    
    
    
    NSString *text = [textField.text stringByReplacingCharactersInRange:range withString:string];
    APCReferralCodeTextField *referralTextField = (APCReferralCodeTextField*)textField;

    if (string.length > 0 && textField == [self.textFields lastObject] && referralTextField.numChars == textField.text.length) {
        return NO;
    }
    
    referralTextField.pendingText = text;
    
    [self updateControls];
    
    if (referralTextField.numChars == referralTextField.pendingText.length) {
        
        // dispatch to main queue here so this current field is updated before
        // the next field becomesFirstResponder
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self goToTextFieldAfterTextField:referralTextField];
        });
    }

    // set isEmpty property on text field so our didBackspace delegate method below
    // will know that text field is empty and can go to previous text field. This
    // is necessary because the didBackspace method is called before the textField.text
    // us updated, so it won't appear empty at that time
    
    referralTextField.isEmpty = textField.text.length == 0;

    return YES;
}

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
    APCReferralCodeTextField *referralTextField = (APCReferralCodeTextField*)textField;
    return referralTextField.isActive;
}

#pragma mark APCReferralTextField delegate

- (void)APCReferralCodeTextFieldDidBackspace:(APCReferralCodeTextField *)textField {
    
    // if our text was empty before backspace was hit, go to previous field
    if (textField.isEmpty) {
        [self goToTextFieldBeforeTextField:textField deleteChar:YES];
    }
    
    textField.isEmpty = textField.text.length == 0;
}

@end
