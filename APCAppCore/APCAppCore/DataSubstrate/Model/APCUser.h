// 
//  APCUser.h 
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
 
#import <Foundation/Foundation.h>
#import <HealthKit/HealthKit.h>
#import <CoreData/CoreData.h>
#import <UIKit/UIKit.h>


typedef NS_ENUM(NSInteger, APCUserConsentSharingScope) {
    APCUserConsentSharingScopeNone = 0,
    APCUserConsentSharingScopeStudy,
    APCUserConsentSharingScopeAll,
};

@interface APCUser : NSObject

/*********************************************************************************/
#pragma mark - Designated Intializer
/*********************************************************************************/
- (instancetype _Nonnull)initWithContext: (NSManagedObjectContext* _Nonnull) context;

/*********************************************************************************/
#pragma mark - Stored Properties in Keychain
/*********************************************************************************/

@property (nonatomic, strong, nullable) NSString * name;
@property (nonatomic, strong, nullable) NSString * familyName;

@property (nonatomic, strong, nullable) NSString * firstName DEPRECATED_ATTRIBUTE;
@property (nonatomic, strong, nullable) NSString * lastName DEPRECATED_ATTRIBUTE;
@property (nonatomic, strong, nullable) NSString * email;
@property (nonatomic, strong, nullable) NSString * password;
@property (nonatomic, strong, nullable) NSString * sessionToken;
@property (nonatomic, strong, nullable) NSString * externalId;
@property (nonatomic, nullable) NSString * subpopulationGuid;

/*********************************************************************************/
#pragma mark - Stored Properties in Core Data
/*********************************************************************************/
@property (nonatomic) APCUserConsentSharingScope sharingScope;      // NOT stored to CoreData, reflected in "sharedOptionSelection"
@property (nonatomic, nullable) NSNumber *sharedOptionSelection;
@property (nonatomic, strong, nullable) UIImage *profileImage;

@property (nonatomic, getter=isConsented) BOOL consented; //Confirmation that server is consented. Should be used in the app to test for user consent.
@property (nonatomic, getter=isUserConsented) BOOL userConsented; //User has consented though not communicated to the server.

@property (nonatomic, strong, nullable) NSDate * taskCompletion;
@property (nonatomic) NSInteger hasHeartDisease;
@property (nonatomic) NSInteger dailyScalesCompletionCounter;
@property (nonatomic, strong, nullable) NSString *customSurveyQuestion;
@property (nonatomic, strong, nullable) NSString *phoneNumber;
@property (nonatomic) BOOL allowContact;
@property (nonatomic, strong, nullable) NSString * medicalConditions;
@property (nonatomic, strong, nullable) NSString * medications;
@property (nonatomic, strong, nullable) NSString *ethnicity;

@property (nonatomic, strong, nullable) NSDate *sleepTime;
@property (nonatomic, strong, nullable) NSDate *wakeUpTime;

@property (nonatomic, strong, nullable) NSString *glucoseLevels;

@property (nonatomic, strong, nullable) NSString *homeLocationAddress;
@property (nonatomic, strong, nullable) NSNumber *homeLocationLat;
@property (nonatomic, strong, nullable) NSNumber *homeLocationLong;

@property (nonatomic, strong, nullable) NSString *consentSignatureName;
@property (nonatomic, strong, nullable) NSDate *consentSignatureDate;
@property (nonatomic, strong, nullable) NSData *consentSignatureImage;

@property (nonatomic, getter=isSecondaryInfoSaved) BOOL secondaryInfoSaved;

/*********************************************************************************/
#pragma mark - Simulated Properties using HealthKit
/*********************************************************************************/
@property (nonatomic, strong, nullable) NSDate * birthDate;
@property (nonatomic) HKBiologicalSex biologicalSex;
@property (nonatomic) HKBloodType bloodType;

// @return YES if birthdate property comes from healthkit, NO if comes from core data
- (BOOL) hasBirthDateInHealthKit;
- (BOOL) hasBiologicalSexInHealthKit;

@property (nonatomic, strong, nullable) HKQuantity * height;
@property (nonatomic, strong, nullable) HKQuantity * weight;
@property (nonatomic, strong, nullable) HKQuantity *systolicBloodPressure;

/*********************************************************************************/
#pragma mark - NSUserDefaults Simulated Properties
/*********************************************************************************/
@property (nonatomic, getter=isSignedUp) BOOL signedUp;
@property (nonatomic, getter=isSignedIn) BOOL signedIn;
@property (nonatomic, nullable) NSNumber * savedSharingScope;
@property (nonatomic, nullable) NSArray <NSString *> * dataGroups;

/*********************************************************************************/
#pragma mark - Stored In Memory Only
/*********************************************************************************/
@property (nonatomic, strong, nullable) NSString * cachedSessionToken; // Memory Only, can nil this out and sessionToken will remain safely in keychain
@property (nonatomic, strong, nullable) NSDate *downloadDataStartDate; // NOT stored in CoreData
@property (nonatomic, strong, nullable) NSDate *downloadDataEndDate; // NOT stored in CoreData


- (BOOL) isLoggedOut;

/**
 Returns our best approximation of the user's "date of
 consent" -- the date they agreed to start the study.
 
 These days, we track the date the user signs up.  In
 earlier versions of the apps, we didn't.  This method
 represents a set of next-best-guesses about that date,
 for users who signed up before we started tracking it.
 */
@property (readonly, nullable) NSDate *estimatedConsentDate;

/**
 Returns the best approximation we have for a user-consent
 date if we don't yet have any user data.  This is a
 static method so that it can be used during database
 migration, when we attach start dates to existing
 schedules, as well as during normal operation.
 */
+ (NSDate * _Nullable) proxyForConsentDate;

@end
