 /* Copyright 2017 Urban Airship and Contributors */

#import "UAAutomation+Internal.h"
#import "UASchedule+Internal.h"
#import "UAActionScheduleInfo.h"
#import "UAScheduleInfo+Internal.h"
#import "UAActionRunner+Internal.h"
#import "UAAutomationEngine+Internal.h"
#import "UAConfig.h"

NSUInteger const UAAutomationScheduleLimit = 100;
NSString *const UAAutomationStoreFileFormat = @"Automation-%@.sqlite";

@implementation UAAutomation


- (instancetype)initWithConfig:(UAConfig *)config dataStore:(UAPreferenceDataStore *)dataStore {
    self = [super initWithDataStore:dataStore];

    if (self) {

        NSString *storeName = [NSString stringWithFormat:UAAutomationStoreFileFormat, config.appKey];

        self.automationEngine = [UAAutomationEngine automationEngineWithAutomationStore:[UAAutomationStore automationStoreWithStoreName:storeName]
                                                                    scheduleLimit:UAAutomationScheduleLimit];
        self.automationEngine.delegate = self;
        
        if (self.componentEnabled) {
            [self.automationEngine start];
        }
    }

    return self;
}

+ (instancetype)automationWithConfig:(UAConfig *)config dataStore:(UAPreferenceDataStore *)dataStore {
    return [[UAAutomation alloc] initWithConfig:config dataStore:dataStore];
}

#pragma mark -
#pragma mark Public API

- (void)scheduleActions:(UAActionScheduleInfo *)scheduleInfo
      completionHandler:(void (^)(UASchedule *))completionHandler {

    [self.automationEngine schedule:scheduleInfo completionHandler:completionHandler];
}

- (void)cancelScheduleWithIdentifier:(NSString *)identifier {
    [self.automationEngine cancelScheduleWithIdentifier:identifier];
}

- (void)cancelAll {
    [self.automationEngine cancelAll];
}

- (void)cancelSchedulesWithGroup:(NSString *)group {
    [self.automationEngine cancelSchedulesWithGroup:group];
}

- (void)getScheduleWithIdentifier:(NSString *)identifier completionHandler:(void (^)(UASchedule *))completionHandler {
    [self.automationEngine getScheduleWithIdentifier:identifier completionHandler:completionHandler];
}

- (void)getSchedules:(void (^)(NSArray<UASchedule *> *))completionHandler {
    [self.automationEngine getSchedules:completionHandler];
}

- (void)getSchedulesWithGroup:(NSString *)group
            completionHandler:(void (^)(NSArray<UASchedule *> *))completionHandler {

    [self.automationEngine getSchedulesWithGroup:group completionHandler:completionHandler];
}

- (UAScheduleInfo *)createScheduleInfoWithBuilder:(UAScheduleInfoBuilder *)builder {
    return [[UAActionScheduleInfo alloc] initWithBuilder:builder];
}

-(BOOL)isScheduleReadyToExecute:(UASchedule *)schedule {
    return YES;
}

-(void)executeSchedule:(UASchedule *)schedule
     completionHandler:(void (^)(void))completionHandler {

    UAActionScheduleInfo *info = (UAActionScheduleInfo *)schedule.info;


    // Run the actions
    [UAActionRunner runActionsWithActionValues:info.actions
                                     situation:UASituationAutomation
                                      metadata:nil
                             completionHandler:^(UAActionResult *result) {
                                 completionHandler();
                             }];
}

- (void)dealloc {
    [self.automationEngine stop];
    self.automationEngine.delegate = nil;
}

- (void)onComponentEnableChange {
    if (self.componentEnabled) {
        // if component was disabled and is now enabled, resume automation engine
        [self.automationEngine resume];
    } else {
        // if component was enabled and is now disabled, pause automation engine
        [self.automationEngine pause];
    }
}

@end
