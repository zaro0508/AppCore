// 
//  APCUser+Bridge.h 
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
 
#import "APCUser.h"
#import <BridgeSDK/BridgeSDK.h>

@interface APCUser (Bridge) <SBBAuthManagerDelegateProtocol>

/*
 * @param shouldPerform YES if you want to perform test user check when calling sign up with view controller paramater
 *                      NO if you do not want it to perform this test
 */
+ (void) setShouldPerformTestUserEmailCheckOnSignup:(BOOL)shouldPerform;

- (void) signUpOnCompletion:(void (^)(NSError * error))completionBlock;
- (void) signUpWithDataGroups:(NSArray<NSString *> *)dataGroups onCompletion:(void (^)(NSError *))completionBlock;

/*
 * @param vc -  a view controller that will be used to perform the test user check and display loading spinner
 *              and also the prompt to the user to make sure they want to be test users
 *              if kAPCUserBridgePerformTestUserEmailCheck is NO, method skips any testing
 */
- (void) signUpWithDataGroups:(NSArray<NSString *> *)dataGroups
         withTestUserPromptVc:(__weak UIViewController*)vc
                 onCompletion:(void (^)(NSError *))completionBlock;

- (void) signInOnCompletion:(void (^)(NSError * error))completionBlock;

/**
 * Login a user on this device via externalId where registration was handled on a different device
 * ExternalID property must not be nil before calling this method
 */
- (void) signInUserWithExternalIdOnCompletion:(void (^)(NSError *))completionBlock;

- (void) signOutOnCompletion:(void (^)(NSError * error))completionBlock;
- (void) updateDataGroups:(NSArray<NSString *> *)dataGroups onCompletion:(void (^)(NSError * error))completionBlock;
- (void) updateProfileOnCompletion:(void (^)(NSError * error))completionBlock;
- (void) updateCustomProfile:(SBBUserProfile*)profile onCompletion:(void (^)(NSError * error))completionBlock;
- (void) getProfileOnCompletion:(void (^)(NSError *error))completionBlock;
- (void) sendUserConsentedToBridgeOnCompletion: (void (^)(NSError * error))completionBlock;
- (void) retrieveConsentOnCompletion:(void (^)(NSError *error))completionBlock;
- (void) withdrawStudyWithReason:(NSString*)reason onCompletion:(void (^)(NSError *error))completionBlock;
- (void) resumeStudyOnCompletion:(void (^)(NSError *error))completionBlock;
- (void) pauseSharingOnCompletion:(void (^)(NSError *error))completionBlock;
- (void) resumeSharingOnCompletion:(void (^)(NSError *error))completionBlock;
- (void) resendEmailVerificationOnCompletion:(void (^)(NSError *))completionBlock;
- (void) changeDataSharingTypeOnCompletion:(void (^)(NSError *))completionBlock;
- (void) sendDownloadDataOnCompletion:(void (^)(NSError *))completionBlock;

@end
