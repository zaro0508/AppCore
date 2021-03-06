//
//  APCActivitiesViewController.m 
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
 
#import "APCActivitiesViewController.h"
#import "APCActivitiesViewSection.h"
#import "APCAppDelegate.h"
#import "APCBaseTaskViewController.h"
#import "APCCircularProgressView.h"
#import "APCConstants.h"
#import "APCDataMonitor+Bridge.h"
#import "APCLog.h"
#import "APCPermissionsManager.h"
#import "APCScheduler.h"
#import "APCSpinnerViewController.h"
#import "APCTask.h"
#import "APCTaskGroup.h"
#import "APCTasksReminderManager.h"
#import "APCUtilities.h"
#import "APCUser+Bridge.h"
#import "NSBundle+Helper.h"
#import "NSDate+Helper.h"
#import "UIAlertController+Helper.h"
#import "UIColor+APCAppearance.h"
#import "NSDictionary+APCAdditions.h"
#import "APCLocalization.h"


static CGFloat const kTintedCellHeight             = 65;
static CGFloat const kTableViewSectionHeaderHeight = 77;


@interface APCActivitiesViewController ()

@property (nonatomic, strong) IBOutlet UITableView  *tableView;
@property (nonatomic, weak)   IBOutlet UILabel      *noTasksLabel;

@property (readonly) APCAppDelegate                 *appDelegate;
@property (readonly) APCActivitiesViewSection       *todaySection;
@property (readonly) NSUInteger                     countOfRequiredTasksToday;
@property (readonly) NSUInteger                     countOfCompletedTasksToday;
@property (readonly) NSUInteger                     countOfRemainingTasksToday;
@property (readonly) UITabBarItem                   *myTabBarItem;

@property (nonatomic, strong) NSDateFormatter       *dateFormatter;
@property (nonatomic, strong) NSDate                *lastKnownSystemDate;
@property (nonatomic, strong) NSArray               *sections;
@property (nonatomic, assign) BOOL                  isFetchingFromCoreDataRightNow;
@property (nonatomic, strong) UIRefreshControl      *refreshControl;

@property (nonatomic, readonly) APCUser *user;
@property (nonatomic, getter=isShowingConsentFlow) BOOL showingConsentFlow;
@property (nonatomic, getter=isAttemptingReconsent) BOOL attemptingReconsent;

@property (strong, nonatomic) APCPermissionsManager *permissionManager;

@property (readonly) NSDate *dateWeAreUsingForToday;

@end

static NSString * const kAPCAlertTitleKeepGoing                 = @"Good job!";
static NSString * const kAPCAlertMessageKeepGoing               = @"It is helpful when activities are completed in succession. Please consider completing remaining activities.";

@implementation APCActivitiesViewController


#pragma mark - Lifecycle

- (void) viewDidLoad
{
    [super viewDidLoad];

    self.navigationItem.title = NSLocalizedStringWithDefaultValue(@"Activities", @"APCAppCore", APCBundle(), @"Activities", @"Activities");
    self.tableView.backgroundColor = [UIColor appSecondaryColor4];

    NSString *headerViewNibName = NSStringFromClass ([APCActivitiesSectionHeaderView class]);
    UINib *nib = [UINib nibWithNibName:headerViewNibName bundle:[NSBundle appleCoreBundle]];
    [self.tableView registerNib: nib forHeaderFooterViewReuseIdentifier: headerViewNibName];

    self.dateFormatter = [NSDateFormatter new];
    [self configureRefreshControl];
    self.lastKnownSystemDate = nil;
    
    self.permissionManager = [[APCPermissionsManager alloc] init];

    /* 
     The below code is failing because signUpPermissionTypes is nil. This is because of the init method above
     being used (should use initWithHealthKitCharacteristicTypesToRead instead). It's commented out now because
     this requestForPermission for coreMotion is no longer needed. A fix has been made in didSelectRow to deal
     with coreMotion perms. See comment there.
     */
    
//    if ([self.permissionManager.signUpPermissionTypes containsObject:@(kAPCSignUpPermissionsTypeCoremotion)]) {
//        // make sure we know the state of CoreMotion permissions so it's available when we need it
//        [self.permissionManager requestForPermissionForType:kAPCSignUpPermissionsTypeCoremotion withCompletion:nil];
//    }
    
    [self setupNotifications];
    
    if (self.user.isConsented) {
        [self reloadData];
    }
}

- (void) viewWillAppear: (BOOL) animated
{
    [super viewWillAppear: animated];
    
    if (!self.user.isConsented) {
        self.showingConsentFlow = NO;
        [self showReconsentIfNecessary];
    }
    
    [self setUpNavigationBarAppearance];
    
    APCLogViewControllerAppeared();
}

- (void) reloadData {
    [self reloadTasksFromCoreData];
    [self checkForAndMaybeRespondToSystemDateChange];
}

- (void) setupNotifications
{
    // Fires when one day rolls over to the next.
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector (handleSystemDateChangeNotification)
                                                 name: APCDayChangedNotification
                                               object: nil];

    // ...but that only happens every minute or so.  This lets us respond much faster.
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector (handleSystemDateChangeNotification)
                                                 name: UIApplicationWillEnterForegroundNotification
                                               object: nil];

    // ...but that only happens every minute or so.  This lets us respond much faster.
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector (handleSystemDateChangeNotification)
                                                 name: UIApplicationDidBecomeActiveNotification
                                               object: nil];
    
    // Upon completion of activity, check to see if we should show an alert encouraging user to continue
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector (handleActivityCompleteNotification)
                                                 name: APCActivityCompletionNotification
                                               object: nil];
}


/**
 Sets up the pull-to-refresh control at the top of the TableView.
 If/when we go back to being a subclass of UITableViewController,
 we can remove this.
 */
- (void) configureRefreshControl
{
    self.refreshControl = [UIRefreshControl new];

    [self.refreshControl addTarget: self
                            action: @selector (fetchNewestSurveysAndTasksFromServer:)
                  forControlEvents: UIControlEventValueChanged];

    [self.tableView addSubview: self.refreshControl];
}

- (void) setUpNavigationBarAppearance
{
    [self.navigationController.navigationBar setBarTintColor: [UIColor appPrimaryNavBarColor]];

    self.navigationController.navigationBar.translucent = NO;
}



// ---------------------------------------------------------
#pragma mark - Responding to changes in system state
// ---------------------------------------------------------

- (void) checkForAndMaybeRespondToSystemDateChange
{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        
        NSDate *now = self.dateWeAreUsingForToday;
        
        if (self.lastKnownSystemDate == nil || ! [now isSameDayAsDate: self.lastKnownSystemDate])
        {
            APCLogDebug (@"Handling date changes (Activities): Last-known date has changed. Resetting dates, refreshing server content, and refreshing UI.");
            
            self.lastKnownSystemDate = now;
            [self reloadTasksFromCoreData];
            [self fetchNewestSurveysAndTasksFromServer: nil];
        }
    }];
}

- (void)handleSystemDateChangeNotification
{
    /*
     only do this if we're currently visible. Adding this check after removing notification
     observer behavior: this class used to start and stop listening whenver the view appeared
     and disappeared. Had to change that as we now rely on APCActivityCompletionNotification
     notification while we're not visible
     */
    
    if (self.isViewLoaded && self.view.window) {
        [self checkForAndMaybeRespondToSystemDateChange];
    }
}

// ---------------------------------------------------------
#pragma mark - Responding to completion of activity
// ---------------------------------------------------------

- (void) handleActivityCompleteNotification
{
    /*
     We reload data below asynchronously. So our countOfRemainingTasksToday will not be
     up to date as the activity the user just completed will not be marked completed yet.
     So, we check to see if our remaining count is more than 1 (instead of more than 0).
     */
    
    if (self.appDelegate.promptUserToContinueActivities && self.countOfRemainingTasksToday > 1) {
        
        // show an alert prompting them to continue doing activities. Delay so task
        // view controller has time to dismiss
        [self performSelector:@selector(presentContinueActivitiesAlert) withObject:nil afterDelay:0.4];
        
        // pass nil for spinnerController because we don't have/want one since we're
        // showing an alert controller
        [self actuallyReloadTasksFromCoreDataWithSpinnerController:nil];
    }
    else {
        // since we're not showing an alert controller, we DO want to show the spinner
        // so we call reloadTasksFromCoreData instead of actuallyReloadTasksFromCoreDataWithSpinnerController
        // Delay to give the task view controller time to dismiss
        [self performSelector:@selector(reloadTasksFromCoreData) withObject:nil afterDelay:0.4];
    }
}

- (void)presentContinueActivitiesAlert
{
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedStringWithDefaultValue(kAPCAlertTitleKeepGoing, @"APCAppCore", APCBundle(), kAPCAlertTitleKeepGoing, @"") message:kAPCAlertMessageKeepGoing preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *continueAction = [UIAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"Continue", @"APCAppCore", APCBundle(), @"Continue", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction * __unused action) {
        // start our next activity, delay to allow time for alert to dismiss
        [self performSelector:@selector(startNextActivity) withObject:nil afterDelay:0.2];
    }];
    [alertController addAction:continueAction];
    
    UIAlertAction *dismiss = [UIAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"Dismiss", @"APCAppCore", APCBundle(), @"Dismiss", @"") style:UIAlertActionStyleCancel handler:^(UIAlertAction *__unused action) {
    }];
    [alertController addAction:dismiss];

    [self.navigationController presentViewController:alertController animated:YES completion:nil];
}

- (void)startNextActivity {

    // get first non-completed task
    APCTaskGroup *taskToDo = nil;
    APCActivitiesViewSection *section = self.todaySection;
    for (APCTaskGroup *group in section.taskGroups) {
        
        // use .dayAfter here because it returns a date object with normalized time components
        // so we can compare it easily to today without worrying about time
        if ([group.dateFullyCompleted.dayAfter isEqualToDate:[NSDate date].dayAfter]) {
            // this one was done today
            continue;
        }
        else {
            taskToDo = group;
            break;
        }
    }
    
    if (taskToDo) {
        APCBaseTaskViewController *viewControllerToShowNext = [self viewControllerToShowForTaskGroup:taskToDo];
        [self presentViewControllerToShowNext:viewControllerToShowNext];
    }
}

// ---------------------------------------------------------
#pragma mark - Displaying the table cells
// ---------------------------------------------------------

- (NSInteger) numberOfSectionsInTableView: (UITableView *) __unused tableView
{
    return self.sections.count;
}

- (NSInteger) tableView: (UITableView *) __unused tableView
  numberOfRowsInSection: (NSInteger) sectionNumber
{
    APCActivitiesViewSection *section = [self sectionForSectionNumber: sectionNumber];
    NSInteger count = section.taskGroups.count;
    return count;
}

- (UITableViewCell *) tableView: (UITableView *) tableView
          cellForRowAtIndexPath: (NSIndexPath *) indexPath
{
    APCActivitiesViewSection *section = [self sectionForCellAtIndexPath: indexPath];
    APCTaskGroup *taskGroupForThisRow = [self taskGroupForCellAtIndexPath: indexPath];
    APCActivitiesTintedTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: kAPCActivitiesTintedTableViewCellIdentifier];

    [cell configureWithTaskGroup: taskGroupForThisRow
                     isTodayCell: section.isTodaySection
               showDebuggingInfo: NO];

    return cell;
}

- (CGFloat)       tableView: (UITableView *) __unused tableView
    heightForRowAtIndexPath: (NSIndexPath *) __unused indexPath
{
    return  kTintedCellHeight;
}

- (CGFloat)        tableView: (UITableView *) __unused tableView
    heightForHeaderInSection: (NSInteger) __unused section
{
    return kTableViewSectionHeaderHeight;
}

- (UIView *)     tableView: (UITableView *) tableView
    viewForHeaderInSection: (NSInteger) sectionNumber
{
    NSString *headerViewIdentifier = NSStringFromClass ([APCActivitiesSectionHeaderView class]);
    APCActivitiesSectionHeaderView *headerView = [tableView dequeueReusableHeaderFooterViewWithIdentifier: headerViewIdentifier];
    APCActivitiesViewSection *section = [self sectionForSectionNumber: sectionNumber];

    headerView.titleLabel.text = section.title;
    headerView.subTitleLabel.text = section.subtitle;
    
    return headerView;
}

- (BOOL)                tableView: (UITableView *) __unused tableView
    shouldHighlightRowAtIndexPath: (NSIndexPath *) indexPath
{
    return [self allowSelectionAtIndexPath: indexPath];
}

- (BOOL) allowSelectionAtIndexPath: (NSIndexPath *) indexPath
{
    APCActivitiesViewSection *section = [self sectionForCellAtIndexPath: indexPath];
    BOOL allowSelection = section.isTodaySection || section.isKeepGoingSection;
    return allowSelection;
}



// ---------------------------------------------------------
#pragma mark - Handling taps in the table
// ---------------------------------------------------------

- (void)          tableView: (UITableView *) tableView
    didSelectRowAtIndexPath: (NSIndexPath *) indexPath
{
    [tableView deselectRowAtIndexPath: indexPath
                             animated: YES];

    
    [self checkForAndMaybeRespondToSystemDateChange];

    if ([self allowSelectionAtIndexPath: indexPath])
    {
        APCBaseTaskViewController *viewControllerToShowNext = [self viewControllerToShowForCellAtIndexPath: indexPath];
        [self presentViewControllerToShowNext:viewControllerToShowNext];
    }
}

- (void)presentViewControllerToShowNext:(APCBaseTaskViewController*)taskViewController {
    
    if (taskViewController != nil)
    {
        if ([self.permissionManager isPermissionsGrantedForType:taskViewController.requiredPermission])
        {
            [self presentViewController: taskViewController
                               animated: YES
                             completion: nil];
        } else
        {
            /*
             https://sagebionetworks.jira.com/browse/BRIDGE-1258 - there were two problems associated with permissions:
             
             When the user declines permission for something (or fails to grant it) during the on-boarding process, there
             were issues allowing the user to manually grant the permission in Settings app and making mPower aware of
             the change.
             
             In the case of the coreMotion permission, the above call to isPermissionGrantedForType simply references
             a permission state value in memory that is assigned to 'notAllowed' upon startup. This value was never
             getting changed to 'allowed' even when the user went to their Settings app and allowed it because the
             call to permissionManager in viewDidLoad to request this permission was failing due to a bug (see comment there)
             
             In the case of the other permission types...if the user never declined permission (instead, they just did not
             grant it), then when they go to Settings app, mPower does not show up in the list of apps for that permission.
             For instance, if user doesn't grant microphone access during onboarding and they tap the Voice Activity row,
             the app checks for permission above and sees that it has not been granted. But, it's never been requested so
             when they go to the Microphone section in Settings > Privacy, mPower does not show up
             
             To fix both these cases, we now request the permission any time the status comes back denied or not determined.
             */
            
            __weak typeof(self) weakSelf = self;
            [self.permissionManager requestForPermissionForType:taskViewController.requiredPermission withCompletion:^(BOOL granted, __unused NSError *error) {
                if (granted) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self presentViewController: taskViewController
                                           animated: YES
                                         completion: nil];
                    });
                }else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        NSError *permissionsError = [self.permissionManager permissionDeniedErrorForType:taskViewController.requiredPermission];
                        [weakSelf presentSettingsAlert:permissionsError];
                        APCLogError2(permissionsError);
                    });
                }
            }];
        }
    }
}

- (void)presentSettingsAlert:(NSError *)error
{
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedStringWithDefaultValue(@"Permissions Denied", @"APCAppCore", APCBundle(), @"Permissions Denied", @"") message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *dismiss = [UIAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"Dismiss", @"APCAppCore", APCBundle(), @"Dismiss", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *__unused action) {
    }];
    [alertController addAction:dismiss];
    UIAlertAction *settings = [UIAlertAction actionWithTitle:NSLocalizedStringWithDefaultValue(@"Settings", @"APCAppCore", APCBundle(), @"Settings", @"") style:UIAlertActionStyleCancel handler:^(UIAlertAction * __unused action) {
        // Common misconception, this takes user to our app's settings page, not general settings page
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
    }];
    [alertController addAction:settings];
    
    [self.navigationController presentViewController:alertController animated:YES completion:nil];
}

// ---------------------------------------------------------
#pragma mark - The *real* data-source methods
// ---------------------------------------------------------

/*
 The methods in this section describe the *concepts* being
 represented by cells and rows in the TableView which is
 the main point of this screen.  Many methods in this file
 use these methods, not just -cellForRowAtIndexPath:.
 */

- (APCBaseTaskViewController *) viewControllerToShowForTaskGroup:(APCTaskGroup *) taskGroup {
    
    APCBaseTaskViewController *viewController   = nil;
    APCTask *task                               = taskGroup.task;
    NSString *viewControllerClassName           = task.taskClassName;
    
    // This call is safe, because it returns nil if such a class doesn't exist:
    Class viewControllerClass = NSClassFromString (viewControllerClassName);
    
    if (viewControllerClass != nil &&
        viewControllerClass != [NSNull class] &&
        [viewControllerClass isSubclassOfClass: [APCBaseTaskViewController class]])
    {
        viewController = [viewControllerClass configureTaskViewController:taskGroup];
    }
    
    return viewController;
}

- (APCBaseTaskViewController *) viewControllerToShowForCellAtIndexPath: (NSIndexPath *) indexPath
{
    APCTaskGroup *taskGroup = [self taskGroupForCellAtIndexPath: indexPath];
    return [self viewControllerToShowForTaskGroup:taskGroup];
}

- (APCActivitiesViewSection *) todaySection
{
    APCActivitiesViewSection *foundSection = nil;

    for (APCActivitiesViewSection *section in self.sections)
    {
        if (section.isTodaySection)
        {
            foundSection = section;
            break;
        }
    }

    return foundSection;
}

- (APCActivitiesViewSection *) sectionForCellAtIndexPath: (NSIndexPath *) indexPath
{
    return [self sectionForSectionNumber: indexPath.section];
}

- (APCActivitiesViewSection *) sectionForSectionNumber: (NSUInteger) sectionNumber
{
    APCActivitiesViewSection *section = nil;

    if (self.sections.count > sectionNumber)
    {
        section = self.sections [sectionNumber];
    }

    return section;
}

- (APCTaskGroup *) taskGroupForCellAtIndexPath: (NSIndexPath *) indexPath
{
    APCTaskGroup *taskGroup             = nil;
    NSUInteger indexOfTaskGroupWeWant   = indexPath.row;
    NSUInteger indexOfSectionWeWant     = indexPath.section;
    APCActivitiesViewSection *section   = [self sectionForSectionNumber: indexOfSectionWeWant];

    if (section.taskGroups.count > indexOfTaskGroupWeWant)
    {
        taskGroup = section.taskGroups [indexOfTaskGroupWeWant];
    }

    return taskGroup;
}

- (NSUInteger) countOfRequiredTasksToday
{
    NSUInteger result = 0;
    APCActivitiesViewSection *section = self.todaySection;

    for (APCTaskGroup *group in section.taskGroups)
    {
        result += group.totalRequiredTasksForThisTimeRange;
    }

    return result;
}

- (NSUInteger) countOfCompletedTasksToday
{
    NSUInteger result = 0;
    APCActivitiesViewSection *section = self.todaySection;

    for (APCTaskGroup *group in section.taskGroups)
    {
        result += group.requiredCompletedTasks.count;
    }

    return result;
}

- (NSUInteger) countOfRemainingTasksToday
{
    NSUInteger result = 0;
    APCActivitiesViewSection *section = self.todaySection;

    for (APCTaskGroup *group in section.taskGroups)
    {
        result += group.requiredRemainingTasks.count;
    }

    return result;
}



// ---------------------------------------------------------
#pragma mark - Outbound messages
// ---------------------------------------------------------

/*
 This viewController does a query that other people need.
 One aspect of the information they need is the number of
 required and completed tasks for "today."  Update them.
 */
- (void) reportNewTaskTotals
{
    NSUInteger requiredTasks  = self.countOfRequiredTasksToday;
    NSUInteger completedTasks = self.countOfCompletedTasksToday;

    [self.appDelegate.dataSubstrate updateCountOfTotalRequiredTasksForToday: requiredTasks
                                                andTotalCompletedTasksToday: completedTasks];
}



// ---------------------------------------------------------
#pragma mark - Reloading data from the server
// ---------------------------------------------------------

- (void) fetchNewestSurveysAndTasksFromServer: (id) __unused sender
{
    __weak APCActivitiesViewController * weakSelf = self;

    [self.appDelegate.dataMonitor refreshFromBridgeOnCompletion: ^(NSError *error) {

        if (error != nil)
        {
            UIAlertController * alert = [UIAlertController simpleAlertWithTitle: @"Error"
                                                                        message: error.localizedDescription];

            [weakSelf presentViewController: alert
                                   animated: YES
                                 completion: NULL];
        }

        [weakSelf reloadTasksFromCoreData];
    }];
}



// ---------------------------------------------------------
#pragma mark - Repainting the UI
// ---------------------------------------------------------

- (void) updateWholeUI
{
    [self.refreshControl endRefreshing];
    [self configureNoTasksView];
    [self updateBadge];
    [self.tableView reloadData];
    
}

- (void) updateBadge
{
    NSString *badgeValue = nil;
    NSUInteger remainingTasks = self.countOfRemainingTasksToday;

    if (remainingTasks > 0)
    {
        badgeValue = @(remainingTasks).stringValue;
    }

    self.myTabBarItem.badgeValue = badgeValue;
}



// ---------------------------------------------------------
#pragma mark - The "no tasks at this time" view.
// ---------------------------------------------------------

- (void) configureNoTasksView
{
    // Only add the noTasksView if there are no activities to show.
    if (self.sections.count == 0 && ! self.isFetchingFromCoreDataRightNow)
    {
        [self.view bringSubviewToFront:self.noTasksLabel];
        [self.noTasksLabel setHidden:NO];
    }
    else
    {
        [self.noTasksLabel setHidden:YES];
    }
}



// ---------------------------------------------------------
#pragma mark - Fetching current tasks from CoreData (NOT from server)
// ---------------------------------------------------------

- (void) reloadTasksFromCoreData
{
    APCSpinnerViewController *spinnerController = [[APCSpinnerViewController alloc] init];
    [self presentViewController:spinnerController animated:YES completion:^{
        [self actuallyReloadTasksFromCoreDataWithSpinnerController:spinnerController];
    }];
}

- (void)actuallyReloadTasksFromCoreDataWithSpinnerController:(APCSpinnerViewController *)spinnerController
{
    
    self.isFetchingFromCoreDataRightNow = YES;

    NSPredicate *filterForOptionalTasks = [NSPredicate predicateWithFormat: @"%K == %@",
                                           NSStringFromSelector(@selector(taskIsOptional)),
                                           @(YES)];

    NSPredicate *filterForRequiredTasks = [NSPredicate predicateWithFormat: @"%K == nil || %K == %@",
                                           NSStringFromSelector(@selector(taskIsOptional)),
                                           NSStringFromSelector(@selector(taskIsOptional)),
                                           @(NO)];

    NSDate *today = self.dateWeAreUsingForToday;
    NSDate *yesterday = today.dayBefore;
    NSDate *midnightThisMorning = today.startOfDay;
    BOOL sortNewestToOldest = YES;

    __weak typeof(self) weakSelf = self;
    [[APCScheduler defaultScheduler] fetchTaskGroupsFromDate: yesterday
                                                      toDate: today
                                      forTasksMatchingFilter: filterForRequiredTasks
                                                  usingQueue: [NSOperationQueue mainQueue]
                                             toReportResults: ^(NSDictionary *taskGroups, NSError * __unused queryError)
     {
         
         APCActivitiesViewSection *todaySection = nil;
         NSUInteger indexOfTodaySection = NSNotFound;

         NSMutableArray *sections = [NSMutableArray new];

         NSArray *sortedDates = [taskGroups.allKeys sortedArrayUsingComparator: ^NSComparisonResult (NSDate *date1, NSDate *date2) {

             NSComparisonResult result = (sortNewestToOldest ?
                                          [date2 compare: date1] :
                                          [date1 compare: date2] );
             return result;
         }];

         for (NSUInteger dateIndex = 0; dateIndex < sortedDates.count; dateIndex ++)
         {
             NSDate *date = sortedDates [dateIndex];
             NSArray *taskGroupsForThisDate = taskGroups [date];
             APCActivitiesViewSection *section = [[APCActivitiesViewSection alloc] initWithDate: date
                                                                                          tasks: taskGroupsForThisDate
                                                                         usingDateForSystemDate: today];
             
             if (section.isTodaySection)
             {
                 todaySection = section;
             }
             else if (section.isYesterdaySection)
             {
                 [section reduceToIncompleteExpiredTasks];
             }
             
             if (section.taskGroups.count)
             {
                 [sections addObject: section];
             }

             if ([date isEqualToDate: midnightThisMorning])
             {
                 indexOfTodaySection = dateIndex;
             }
         }

         /*
          Now that we've gotten all tasks for all the dates
          we care about, get the "optional" tasks for
          "today" (or the date we formally believe is
          "today"), and insert them between "today" and
          "yesterday" (if available, or at the bottom of
          the list of sections, if not).
          */
         [[APCScheduler defaultScheduler] fetchTaskGroupsFromDate: today
                                                           toDate: today
                                           forTasksMatchingFilter: filterForOptionalTasks
                                                       usingQueue: [NSOperationQueue mainQueue]
                                                  toReportResults: ^(NSDictionary *taskGroups, NSError * __unused queryError)
         {
             /*
              There should be exactly one date in the list
              of groups, and thus one list of values.
              */
             NSArray *optionalTaskGroups = taskGroups.allValues.firstObject;

             if (optionalTaskGroups.count)
             {
                 APCActivitiesViewSection *section = [[APCActivitiesViewSection alloc] initAsKeepGoingSectionWithTasks: optionalTaskGroups];

                 if (indexOfTodaySection == NSNotFound)
                 {
                     [sections addObject: section];
                 }
                 else
                 {
                     [sections insertObject: section atIndex: indexOfTodaySection + 1];
                 }
             }


             //
             // Regardless of whether we got any optional
             // groups, show everything, now.
             //
             weakSelf.sections = sections;


             //
             // Regenerate reminders for all these things.
             //
             NSArray *taskGroupsForToday = todaySection.taskGroups;
             [weakSelf.appDelegate.tasksReminder handleActivitiesUpdateWithTodaysTaskGroups: taskGroupsForToday];


             //
             // Update central data points, so other screens
             // can draw their graphics and whatnot.
             //
             [weakSelf reportNewTaskTotals];


             //
             // Per the above:  we always fetch optional tasks.
             // Now that the second fetch is complete:
             // update the UI.
             //
             weakSelf.isFetchingFromCoreDataRightNow = NO;
             [weakSelf updateWholeUI];
             
             if (spinnerController) {
                 // don't forget to dismiss the spinner!
                 dispatch_async(dispatch_get_main_queue(), ^{
                     [spinnerController dismissViewControllerAnimated:YES completion:nil];
                 });
             }

         }];  // second fetch:  optional tasks
     }];  // first fetch:  required tasks, for a range of dates
}  // method reloadFromCoreData



// ---------------------------------------------------------
#pragma mark - Utilities
// ---------------------------------------------------------

- (APCAppDelegate *) appDelegate
{
    return [APCAppDelegate sharedAppDelegate];
}

- (NSDate *) dateWeAreUsingForToday
{
    return [NSDate date];
}

- (UITabBarItem *) myTabBarItem
{
    UITabBarItem *activitiesTab = nil;
    UITabBar *tabBar = self.appDelegate.tabBarController.tabBar;

    for (UITabBarItem *item in tabBar.items)
    {
        if (item.tag == (NSInteger) kAPCActivitiesTabTag)
        {
            activitiesTab = item;
            break;
        }
    }

    return activitiesTab;
}

#pragma mark - Reconsent

- (APCUser *)user {
    return [[APCAppDelegate sharedAppDelegate] dataSubstrate].currentUser;
}

- (void)showReconsentIfNecessary {
    if (!self.user.userConsented) {
        if (!self.isShowingConsentFlow) {
            self.showingConsentFlow = YES;
            UIViewController *vc = [[APCAppDelegate sharedAppDelegate] consentViewController];
            [self presentViewController:vc animated:YES completion:nil];
        }
    }
    else if (!self.isAttemptingReconsent) {
        self.attemptingReconsent = YES;
        [self sendReconsentToServer];
    }
}

- (void)sendReconsentToServer {
    // If this is a reconsent, then send the reconsent
    __weak typeof(self) weakSelf = self;
    [self.user signInOnCompletion: ^(NSError *error) {
        [weakSelf handleSigninResponseWithError: error];
    }];
}

- (void)handleSigninResponseWithError:(NSError *)error {
    if ((error != nil) && (error.code != SBBErrorCodeServerPreconditionNotMet)) {
        APCLogError2(error);
        [self showConsentError: error];
    }
    else {
        __weak typeof(self) weakSelf = self;
        [self.user sendUserConsentedToBridgeOnCompletion: ^(NSError *error) {
            [weakSelf handleConsentResponseWithError: error];
        }];
    }
}

- (void)handleConsentResponseWithError:(NSError *)error {
    // 409 Conflict in this context means consent already signed, which happens if a user tries to re-sign-up
    // with an existing email account rather than signing in with it. In any case it means they've already signed
    // the consent so we can just mark the user as consented and move on.
    if (error && error.code != 409) {
        APCLogError2(error);
        [self showConsentError: error];
    }
    else {
        self.attemptingReconsent = NO;
        self.user.consented = YES;
        [[NSNotificationCenter defaultCenter] postNotificationName:APCUserDidConsentNotification object:nil];
        [self reloadData];
    }
}

- (void)showConsentError:(NSError *)error {
    self.attemptingReconsent = NO;
    UIAlertController *alert = [UIAlertController simpleAlertWithTitle:NSLocalizedStringWithDefaultValue(@"User Consent Error", @"APCAppCore", APCBundle(), @"User Consent Error", @"") message:error.localizedDescription];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
