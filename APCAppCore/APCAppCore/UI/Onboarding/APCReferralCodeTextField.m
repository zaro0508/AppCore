//
//  APCReferralCodeTextField.m
//  APCAppCore
//
//  Created by Josh Bruhin on 2/10/17.
//  Copyright © 2017 Apple, Inc. All rights reserved.
//

#import "APCReferralCodeTextField.h"

@implementation APCReferralCodeTextField

- (BOOL)isValid {
    NSString *text = self.pendingText ? self.pendingText : self.text;
    NSPredicate *test = [NSPredicate predicateWithFormat:@"%@ MATCHES %@", text, self.regexString];
    return [test evaluateWithObject:self];
}
- (BOOL)isValidWithString:(NSString *)string {
    NSPredicate *test = [NSPredicate predicateWithFormat:@"%@ MATCHES %@", string, self.regexString];
    return [test evaluateWithObject:self];
}

- (void)deleteBackward {
    [super deleteBackward];
    if ([self.referallCodeTextFieldDelegate respondsToSelector:@selector(APCReferralCodeTextFieldDidBackspace:)]){
        [self.referallCodeTextFieldDelegate APCReferralCodeTextFieldDidBackspace:self];
    }
}


@end
