//
//  APCTaskImporter.m
//  APCAppCore
//
//  Copyright (c) 2015, Apple Inc. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without modification,
//  are permitted provided that the following conditions are met:
//
//  1.  Redistributions of source code must retain the above copyright notice, this
//  list of conditions and the following disclaimer.
//
//  2.  Redistributions in binary form must reproduce the above copyright notice,
//  this list of conditions and the following disclaimer in the documentation and/or
//  other materials provided with the distribution.
//
//  3.  Neither the name of the copyright holder(s) nor the names of any contributors
//  may be used to endorse or promote products derived from this software without
//  specific prior written permission. No license is granted to the trademarks of
//  the copyright holders even if such marks are included in this software.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
//  FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
//  SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
//  CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
//  OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
//  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

#import "APCTaskImporter.h"
#import "APCTask+AddOn.h"
#import "APCTask+Bridge.h"
#import "APCGenericSurveyTaskViewController.h"
#import "APCLog.h"
#import "NSDate+Helper.h"
#import "NSError+APCAdditions.h"
#import "NSManagedObject+APCHelper.h"
#import "APCAppDelegate.h"

// ---------------------------------------------------------
#pragma mark - Constants
// ---------------------------------------------------------

/**
 Error codes and messages generated by this class.
 */
typedef enum : NSUInteger {
    APCErrorCouldntFindSurveyFileCode,
    APCErrorInboundListOfSchedulesAndTasksIssuesCode,
    APCErrorLoadingNativeBridgeSurveyObjectCode,
    APCErrorLoadingSurveyFileCode,
    APCErrorParsingSurveyContentCode,
    APCErrorSavingEverythingCode,
    APCErrorDeletingObsoleteTasksCode,
}   APCError;

static NSString * const APCErrorDomain                                              = @"APCErrorDomainImportTasks";
static NSString * const APCErrorSavingEverythingReason                              = @"Error Saving New Tasks";
static NSString * const APCErrorSavingEverythingSuggestion                          = @"There was an error attempting to save the new tasks.";
static NSString * const APCErrorDeletingObsoleteTasksReason                         = @"Error Deleting Obsolete Tasks";
static NSString * const APCErrorDeletingObsoleteTasksSuggestion                     = @"There was an error attempting to delete the obsolete tasks.";
static NSString * const APCErrorCouldntFindSurveyFileReason                         = @"Can't Find Survey File";
static NSString * const APCErrorCouldntFindSurveyFileSuggestion                     = @"We couldn't find the specified survey file on the phone.  Did you misspell the filename, perhaps?";
static NSString * const APCErrorLoadingSurveyFileReason                             = @"There was an error serializing the contents of a survey file";
static NSString * const APCErrorLoadingSurveyFileSuggestion                         = @"There was an error serializing the contents of a survey file. ";
static NSString * const APCErrorParsingSurveyContentReason                          = @"There was an error parsing the contents of a survey file";
static NSString * const APCErrorParsingSurveyContentSuggestion                      = @"There was an error parsing the contents of a survey file.";
static NSString * const APCErrorLoadingNativeBridgeSurveyObjectReason               = @"Can't Find Survey File";
static NSString * const APCErrorLoadingNativeBridgeSurveyObjectSuggestion           = @"We couldn't find the specified survey file on the phone.  Did you misspell the filename, perhaps?";

/**
 JSON Mapping files
 */
static NSString * const kTaskIdToViewControllerMappingJSON                      = @"APHTaskIdToViewControllerMapping";

/**
 Keys and special values in the JSON dictionaries representing tasks.
 */
static NSString * const kTaskClassNameKey                      = @"taskClassName";
static NSString * const kTaskCompletionTimeStringKey           = @"taskCompletionTimeString";
static NSString * const kTaskExpiresDateKey                    = @"taskExpiresDateKey";
static NSString * const kTaskFinishedDateKey                   = @"taskFinishedDateKey";
static NSString * const kTaskFileNameKey                       = @"taskFileName";
static NSString * const kTaskGuidKey                           = @"taskGuid";
static NSString * const kTaskIDKey                             = @"taskID";
static NSString * const kTaskIsOptionalKey                     = @"persistent";
static NSString * const kTaskScheduledForDateKey               = @"taskScheduledForDateKey";
static NSString * const kTaskSortStringKey                     = @"sortString";
static NSString * const kTaskStartedDateKey                    = @"taskStartedDateKey";
static NSString * const kTaskTitleKey                          = @"taskTitle";
static NSString * const kTaskTypeKey                           = @"taskType";
static NSString * const kTaskTypeValueSurvey                   = @"survey";
static NSString * const kTaskUrlKey                            = @"taskUrl";

/**
 Formats for interpreting a JSON list of time values.
 Filled in during +load.
 */
static NSArray *legalTimeSpecifierFormats = nil;


// ---------------------------------------------------------
#pragma mark - The Class Body
// ---------------------------------------------------------


@implementation APCTaskImporter

/**
 Sets global, static values the first time anyone calls this category.
 
 By definition, this method is called once per category, in a thread-safe
 way, the first time the category is sent a message -- basically, the first
 time we refer to any method declared in that category.
 
 Documentation:  the key sentence is actually in the documentation for
 +initialize:  "initialize is invoked only once per class. If you want
 to perform independent initialization for the class and for categories
 of the class, you should implement +load methods."
 
 Useful resources:
 -  http://stackoverflow.com/q/13326435
 -  https://developer.apple.com/library/ios/documentation/Cocoa/Reference/Foundation/Classes/NSObject_Class/index.html#//apple_ref/occ/clm/NSObject/load
 -  https://developer.apple.com/library/ios/documentation/Cocoa/Reference/Foundation/Classes/NSObject_Class/index.html#//apple_ref/occ/clm/NSObject/initialize
 */
+ (void) load
{
    legalTimeSpecifierFormats = @[@"H",
                                  @"HH",
                                  @"HH:mm",
                                  @"HH:mm:SS",
                                  @"HH:mm:SS.sss"
                                  ];
}


// ---------------------------------------------------------
#pragma mark - The Main Import Method
// ---------------------------------------------------------

- (BOOL) processTasks: (NSArray *) arrayOfTasks
           fromSource: (APCTaskSource) taskSource
         usingContext: (NSManagedObjectContext *) context
       returningError: (NSError * __autoreleasing *) errorToReturn
{
    BOOL success = YES;
    NSString *sourceName = NSStringFromAPCTaskSource (taskSource);
    APCLogDebug(@"Importing new batch of schedules from [%@] starting at [%@].", sourceName, [NSDate date]);
    
    // Save method requires a pointer to an object, which should probably be updated at some
    // point but isn't part of the current work.
    APCTask *taskForSaving = nil;
    
    // -----------------------------------------------------
    // Upsert
    // -----------------------------------------------------
    
    for (NSDictionary *taskDictionary in arrayOfTasks) {
        if (taskForSaving == nil) {
            taskForSaving = [self createOrUpdateTaskFromJsonData: taskDictionary
                                                       inContext: context];
        } else {
            [self createOrUpdateTaskFromJsonData: taskDictionary
                                       inContext: context];
        }
    }
    
    // -----------------------------------------------------
    // Save
    // -----------------------------------------------------
    
    if (!context.hasChanges)
    {
        APCLogEvent(kTaskEvent,@"No new changes imported from Server.");
    }
    else
    {
        NSManagedObject *anySaveableObject = taskForSaving;
        NSError *savingError = nil;
        BOOL saved = [anySaveableObject saveToPersistentStore: &savingError];
        
        if (!saved)
        {
            *errorToReturn = [NSError errorWithCode: APCErrorSavingEverythingCode
                                             domain: APCErrorDomain
                                      failureReason: APCErrorSavingEverythingReason
                                 recoverySuggestion: APCErrorSavingEverythingSuggestion
                                        nestedError: savingError];
            success = NO;
        }
    }
    
    // -----------------------------------------------------
    // Delete Obsolete Tasks
    // -----------------------------------------------------
    // Relevant tasks should have come down from bridge and then update the APCTask.updatedAt field
    // accordingly with the exception of: completed tasks and expired tasks. Any task that wasn't updated
    // that doesn't fall into one of those 2 categories is either no longer scheduled or at least it is
    // no longer relevant. So lets delete those. If at some point Bridge starts returning recently completed
    // and recently expired activities, this will either be unnecessary or be significantly simpler.
    if (success) {
        // Tasks saved, so now clean out the tasks that didn't come down from the server
        NSDate *now = [NSDate date];
        NSTimeInterval fiveMinutesAgoInterval = 60 * 5 * (-1);
        NSDate *fiveMinutesAgo = [now dateByAddingTimeInterval:fiveMinutesAgoInterval];
        NSDate *midnightThisMorning = now.startOfDay;
        NSDate *midnightYesterdayMorning = [now dateByAddingDays:(-1)].startOfDay;
        
        
        // TODO: This logic can be simplified once daysBehind is an option - we no longer have to worry about deleting
        // "Yesterday" tasks.
        // (%K < %@) Select this as one of the tasks that was not updated
        // (%K == nil) Check that the activity was not finished - if it was, we don't want to remove it (since Bridge stops returning it)
        // Check that the activity was not a "yesterday" task, by confirming it:
            // %K.length == 0 Had no expiration OR
            // %K < %@ Expired before yesterday OR
            // %K > %@ Expired today or later
        NSPredicate *findObsoleteTasks = [NSPredicate predicateWithFormat:
                                          @"(%K < %@) && (%K == nil) && (%K.length == 0 OR %K < %@ OR %K > %@)",
                                          NSStringFromSelector (@selector (updatedAt)),           // -[APCTask taskScheduledFor]
                                          fiveMinutesAgo,
                                          NSStringFromSelector (@selector (taskFinished)),           // -[APCTask taskExpires]
                                          NSStringFromSelector (@selector (taskExpires)),           // -[APCTask taskExpires]
                                          NSStringFromSelector (@selector (taskExpires)),           // -[APCTask taskExpires]
                                          midnightYesterdayMorning,
                                          NSStringFromSelector (@selector (taskExpires)),           // -[APCTask taskFinished]
                                          midnightThisMorning
                                          ];
        NSFetchRequest *obsoleteTaskRequest = [APCTask requestWithPredicate: findObsoleteTasks];
        NSBatchDeleteRequest *deleteRequest = [[NSBatchDeleteRequest alloc] initWithFetchRequest:obsoleteTaskRequest];
        
        NSError *deleteError = nil;
        [context executeRequest:deleteRequest error:&deleteError];
        if (deleteError) {
            *errorToReturn = [NSError errorWithCode: APCErrorDeletingObsoleteTasksCode
                                             domain: APCErrorDomain
                                      failureReason: APCErrorDeletingObsoleteTasksReason
                                 recoverySuggestion: APCErrorDeletingObsoleteTasksSuggestion
                                        nestedError: deleteError];
            success = NO;
        }
    }
    
    return success;
}

// ---------------------------------------------------------
#pragma mark - Create/Update
// ---------------------------------------------------------

/**
 When we get data from a file or from the server, we first convert it to a set
 of dictionaries. This method looks for an existing task with the same guid as
 supplied in the dictionary and creates one if none exists. It then calls the
 update method to update the task with the rest of the data in the supplied
 dictionary.
 */
- (APCTask *) createOrUpdateTaskFromJsonData: (NSDictionary *) taskData
                                   inContext: (NSManagedObjectContext *) context
{
    APCTask  *task              = nil;
    NSString *taskGuid          = [self nilIfNull: taskData [kTaskGuidKey]];
    
    NSSet *tasks = [APCTask querySavedTasksWithTaskGuids: [NSSet setWithObject: taskGuid]
                                            usingContext: context];
    
    if (tasks)
    {
        task = tasks.anyObject;
    }
    
    if (task == nil)
    {
        task = [APCTask newObjectForContext: context];
        task.taskGuid = taskGuid;
    }
    
    [self updateTask: task
            withData: taskData];
    
    return task;
}

- (void) updateTask: (APCTask *) task
           withData: (NSDictionary *) taskData
{
    //
    // Update the task with potentially new data
    // (or add it for the first time, if we're creating a task).
    //
    task.taskID                     = [self nilIfNull: taskData [kTaskIDKey]];
    task.taskType                   = [self nilIfNull: taskData [kTaskTypeKey]];                    // internal representation of separate bridge types (Survey, non Survey)
    task.taskHRef                   = [self nilIfNull: taskData [kTaskUrlKey]];                     // bridge-only?
    task.taskTitle                  = [self nilIfNull: taskData [kTaskTitleKey]];                   // bridge and us
    task.sortString                 = [self nilIfNull: taskData [kTaskSortStringKey]];              // appcore-only, for now
    task.taskClassName              = [self nilIfNull: taskData [kTaskClassNameKey]];               // bridge and appcore, because we add to bridge
    task.taskCompletionTimeString   = [self nilIfNull: taskData [kTaskCompletionTimeStringKey]];    // appcore-only?
    task.taskContentFileName        = [self nilIfNull: taskData [kTaskFileNameKey]];                // appcore-only?
    task.taskIsOptional             = [self nilIfNull: taskData [kTaskIsOptionalKey]];              // both
    task.taskExpires                = [self nilIfNull: taskData [kTaskExpiresDateKey]];             // new tasks api
    task.taskScheduledFor           = [self nilIfNull: taskData [kTaskScheduledForDateKey]];        // new tasks api
    
    
    // Don't overwrite data with nil for these values. Changed locally and server might not have latest values.
    if ([self nilIfNull: taskData [kTaskStartedDateKey]]) {
        task.taskStarted                = [self nilIfNull: taskData [kTaskStartedDateKey]];         // new tasks api
    }
    if ([self nilIfNull: taskData [kTaskFinishedDateKey]]) {
        task.taskFinished               = [self nilIfNull: taskData [kTaskFinishedDateKey]];        // new tasks api
    }
    
    
    if ([task.taskTitle stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]].length == 0)
    {
        APCLogDebug (@"\n-------------\nWARNING!  About to create a Task with an empty title!  taskData and task are:  \n%@\n%@\n----------------", taskData, task);
    }
    
    if (task.taskContentFileName)
    {
        id <ORKTask> survey = [self surveyFromFileBaseName: task.taskContentFileName];
        
        if (survey)
        {
            task.rkTask = survey;
        }
    }
}

- (id <ORKTask>) surveyFromFileBaseName: (NSString *) surveyContentFileBaseName
{
    id <ORKTask> rkSurvey = nil;
    
    NSString *surveyFilePath = [[APCAppDelegate sharedAppDelegate] pathForResource: surveyContentFileBaseName
                                                               ofType: kAPCFileExtension_JSON];
    
    if (! surveyFilePath)
    {
        NSString *fullFileName = [NSString stringWithFormat: @"%@.%@", surveyContentFileBaseName, kAPCFileExtension_JSON];
        
        NSError *errorFindingSurveyFile = [NSError errorWithCode: APCErrorCouldntFindSurveyFileCode
                                                          domain: APCErrorDomain
                                                   failureReason: APCErrorCouldntFindSurveyFileReason
                                              recoverySuggestion: APCErrorCouldntFindSurveyFileSuggestion
                                                 relatedFilePath: fullFileName
                                                      relatedURL: nil
                                                     nestedError: nil];
        
        APCLogError2 (errorFindingSurveyFile);
    }
    
    else
    {
        NSError *errorLoadingSurveyFile = nil;
        NSData *jsonData = [NSData dataWithContentsOfFile: surveyFilePath
                                                  options: 0
                                                    error: & errorLoadingSurveyFile];
        
        if (! jsonData)
        {
            NSError *error = [NSError errorWithCode: APCErrorLoadingSurveyFileCode
                                             domain: APCErrorDomain
                                      failureReason: APCErrorLoadingSurveyFileReason
                                 recoverySuggestion: APCErrorLoadingSurveyFileSuggestion
                                        nestedError: errorLoadingSurveyFile];
            
            APCLogError2 (error);
        }
        
        else
        {
            NSError *errorParsingSurveyContent = nil;
            NSDictionary *surveyContent = [NSJSONSerialization JSONObjectWithData: jsonData
                                                                          options: 0
                                                                            error: & errorParsingSurveyContent];
            if (! surveyContent)
            {
                NSError *error = [NSError errorWithCode: APCErrorParsingSurveyContentCode
                                                 domain: APCErrorDomain
                                          failureReason: APCErrorParsingSurveyContentReason
                                     recoverySuggestion: APCErrorParsingSurveyContentSuggestion
                                            nestedError: errorParsingSurveyContent];
                
                APCLogError2 (error);
            }
            
            else
            {
                @try
                {
                    id manager = SBBComponent(SBBSurveyManager);
                    SBBSurvey *survey = [[manager objectManager] objectFromBridgeJSON: surveyContent];
                    rkSurvey = [APCTask rkTaskFromSBBSurvey: survey];
                }
                @catch (NSException *exception)
                {
                    NSError *error = [NSError errorWithCode: APCErrorLoadingNativeBridgeSurveyObjectCode
                                                     domain: APCErrorDomain
                                              failureReason: APCErrorLoadingNativeBridgeSurveyObjectReason
                                         recoverySuggestion: APCErrorLoadingNativeBridgeSurveyObjectSuggestion
                                            relatedFilePath: surveyFilePath
                                                 relatedURL: nil
                                                nestedError: nil
                                              otherUserInfo: @{ @"exception": exception,
                                                                @"stackTrace": exception.callStackSymbols }];
                    
                    APCLogError2 (error);
                }
                @finally
                {
                    
                }
            }
        }
    }
    
    return rkSurvey;
}

// ---------------------------------------------------------
#pragma mark - JSON conversions
// ---------------------------------------------------------

/**
 Convert inbound Bridge server data to an NSDictionary of keys we know how to
 look for.
 
 This lets us use the same method to process data downloaded from the server as
 we do data pulled from a local JSON file. It also lets us flatten out the
 task structure into a single object and its associated properties.
 */
- (NSDictionary *) extractJsonDataFromIncomingSageTask: (SBBScheduledActivity *)sageTask
{
    NSMutableDictionary *taskData               = [NSMutableDictionary new];
    taskData [kTaskGuidKey]                 = [self nullIfNil: sageTask.guid];
    taskData [kTaskTitleKey]                = [self nullIfNil: sageTask.activity.label];
    taskData [kTaskCompletionTimeStringKey] = [self nullIfNil: sageTask.activity.labelDetail];
    taskData [kTaskTypeKey]                 = [self nullIfNil: sageTask.activity.activityType];
    taskData [kTaskIsOptionalKey]           = [self nullIfNil: sageTask.persistent];
    taskData [kTaskExpiresDateKey]          = [self nullIfNil: sageTask.expiresOn];
    taskData [kTaskFinishedDateKey]         = [self nullIfNil: sageTask.finishedOn];
    taskData [kTaskScheduledForDateKey]     = [self nullIfNil: sageTask.scheduledOn];
    taskData [kTaskStartedDateKey]          = [self nullIfNil: sageTask.startedOn];
    
    // When we start getting these from Bridge, we'll use them.
    // In the mean time, noting them here, because they can still be used from
    // local json files.
    
    taskData [kTaskFileNameKey]             = [NSNull null];
    taskData [kTaskSortStringKey]           = [self nullIfNil: sageTask.activity.activityType]; // Default for now
    
    if (sageTask.activity.survey) {
        taskData [kTaskTypeKey]                 = [NSNumber numberWithUnsignedInt:APCTaskTypeSurveyTask];
        taskData [kTaskIDKey]                   = [self nullIfNil: sageTask.activity.survey.identifier];
        taskData [kTaskUrlKey]                  = [self nullIfNil: sageTask.activity.survey.href];
        taskData [kTaskClassNameKey]            = NSStringFromClass ([APCGenericSurveyTaskViewController class]);
        
        return taskData;
    } else if (sageTask.activity.task) {
        taskData [kTaskTypeKey]                 =  [NSNumber numberWithUnsignedInt:APCTaskTypeActivityTask];
        
        // Set up TaskId->TaskViewController dictionary
        // TODO: move this init stuff out of a situation where it will be called many times
        NSString *filePath = [[APCAppDelegate sharedAppDelegate] pathForResource:kTaskIdToViewControllerMappingJSON ofType:@"json"];
        NSString *JSONString = [[NSString alloc] initWithContentsOfFile:filePath
                                                               encoding:NSUTF8StringEncoding
                                                                  error:NULL];
        NSError *parseError;
        NSDictionary *mappingDictionary = [NSJSONSerialization JSONObjectWithData:[JSONString dataUsingEncoding:NSUTF8StringEncoding]
                                                                          options:NSJSONReadingMutableContainers
                                                                            error:&parseError];
        
        // ignore unrecognized tasks (probably added in a later app version)
        NSString *taskClassName = mappingDictionary[sageTask.activity.task.identifier];
        if (taskClassName.length) {
            taskData [kTaskIDKey]                   = [self nullIfNil: sageTask.activity.task.identifier];
            taskData [kTaskClassNameKey]            = taskClassName;
            
            // Not available for non survey tasks
            taskData [kTaskUrlKey]              = [NSNull null];
            
            return taskData;
        } else {
            APCLogEvent(@"Could not find taskClassName from task identifier: %@", sageTask.activity.task.identifier);
            return nil;
        }
    } else {
        APCLogEvent(@"Unable to extract JSON data from task, no activity survey or task supplied.");
        return nil;
    }
}

// ---------------------------------------------------------
#pragma mark - Utilities
// ---------------------------------------------------------

/**
 Performs a "practical" version of "isEqual", returning YES if
 (a)  both objects are nil, or
 (b)  [object1 isEqual: object2]
 */
- (BOOL) object1: (id) object1
   equalsObject2: (id) object2
{
    return ((object1 == nil && object2 == nil) || [object1 isEqual: object2]);
}

/**
 Returns nil if the specified value is [NSNull null].  Otherwise, returns the
 value itself.
 
 Used to extract values from an NSDictionary and treat them as "nil" when that
 was the actual intent.
 */
- (id) nilIfNull: (id) someInputValue
{
    id outputValue = someInputValue;
    
    if (outputValue == [NSNull null])
    {
        outputValue = nil;
    }
    
    return outputValue;
}

/**
 Returns [NSNull null] if the specified value is nil, so that we can
 insert the specified item into a dictionary.  Otherwise, returns the value
 itself.
 */
- (id) nullIfNil: (id) someInputValue
{
    id outputValue = someInputValue;
    
    if (outputValue == nil)
    {
        outputValue = [NSNull null];
    }
    
    return outputValue;
}

@end
