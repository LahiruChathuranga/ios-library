/* Copyright Airship and Contributors */

#import "UAOpenExternalURLAction.h"

#define kUADeepLinkActionDefaultRegistryName @"deep_link_action"
#define kUADeepLinkActionDefaultRegistryAlias @"^d"

/**
 * Opens a deep link URL. This action is registered under
 * the names ^d and deep_link_action.
 *
 * Expected argument values: NSString
 *
 * Valid situations: UASituationForegroundPush, UASituationLaunchedFromPush
 * UASituationWebViewInvocation, UASituationForegroundInteractiveButton,
 * UASituationManualInvocation, and UASituationAutomation
 *
 * Result value: An NSString representation of the input
 *
 * Error: `UAOpenExternalURLActionErrorCodeURLFailedToOpen` if the URL could not be opened
 *
 * Fetch result: UAActionFetchResultNoData
 */
@interface UADeepLinkAction : UAOpenExternalURLAction

@end
