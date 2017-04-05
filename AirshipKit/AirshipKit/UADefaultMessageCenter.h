/* Copyright 2017 Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class UAInboxMessage;
@class UADefaultMessageCenterStyle;
@class UAConfig;

/**
 * The UADefaultMessageCenter class provides a default implementation of a
 * message center, as well as a high-level interface for its configuration and display.
 */
@interface UADefaultMessageCenter : NSObject


/**
 * The title of the message center.
 */
@property (nonatomic, strong) NSString *title;

/**
 * The style to apply to the default message center.
 */
@property (nonatomic, strong) UADefaultMessageCenterStyle *style;

/**
 * An optional predicate for filtering messages.
 */
@property (nonatomic, strong) NSPredicate *filter;


/**
 * Factory method for creating message center with style specified in a config.
 *
 * @return A Message Center instance initialized with the style specified in the provided config.
 */
+ (instancetype)messageCenterWithConfig:(UAConfig *)config;

/**
 * Display the message center.
 *
 * @param animated Whether the transition should be animated.
 */
- (void)display:(BOOL)animated;

/**
 * Display the message center with animation.
 */
- (void)display;

/**
 * Display the given message.
 *
 * @param message The message.
 * @param animated Whether the transition should be animated.
 */
- (void)displayMessage:(UAInboxMessage *)message animated:(BOOL)animated;

/**
 * Display the given message without animation.
 *
 * @pararm message The message.
 */
- (void)displayMessage:(UAInboxMessage *)message;

/**
 * Dismiss the message center.
 *
 * @param animated Whether the transition should be animated.
 */
- (void)dismiss:(BOOL)animated;

/**
 * Dismiss the message center with animation.
 */
- (void)dismiss;

@end
