/* Copyright 2017 Urban Airship and Contributors */

#import "UADefaultMessageCenterMessageViewController.h"
#import "UAWebViewDelegate.h"
#import "UAInbox.h"
#import "UAirship.h"
#import "UAInboxMessageList.h"
#import "UAInboxMessage.h"
#import "UAUtils.h"
#import "UIWebView+UAAdditions.h"
#import "UAMessageCenterLocalization.h"
#import "UABeveledLoadingIndicator.h"

#define kMessageUp 0
#define kMessageDown 1

@interface UADefaultMessageCenterMessageViewController () <UAUIWebViewDelegate, UARichContentWindow, UAMessageCenterMessageViewProtocol>

@property (nonatomic, strong) UAWebViewDelegate *webViewDelegate;

/**
 * The UIWebView used to display the message content.
 */
@property (nonatomic, strong) UIWebView *webView;

/**
 * The loading indicator.
 */
@property (weak, nonatomic) IBOutlet UABeveledLoadingIndicator *loadingIndicatorView;

/**
 * The index of the currently displayed message.
 */
@property (nonatomic, assign) NSUInteger messageIndex;

/**
 * The view displayed when there are no messages.
 */
@property (nonatomic, weak) IBOutlet UIView *coverView;

/**
 * The label displayed in the coverView.
 */
@property (nonatomic, weak) IBOutlet UILabel *coverLabel;

/**
 * Boolean indicating whether or not the view is visible
 */
@property (nonatomic, assign) BOOL isVisible;

/**
 * The messages displayed in the message table.
 */
@property (nonatomic, copy) NSArray *messages;

@end

@implementation UADefaultMessageCenterMessageViewController

@synthesize message = _message;
@synthesize closeBlock = _closeBlock;

- (void)dealloc {
    self.webView.delegate = nil;
    self.message = nil;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.webViewDelegate = [[UAWebViewDelegate alloc] init];
    self.webViewDelegate.forwardDelegate = self;
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
    self.webViewDelegate.richContentWindow = self;
#pragma GCC diagnostic pop
    self.webView.delegate = self.webViewDelegate;

    // Allow the webView to detect data types (e.g. phone numbers, addresses) at will
    [self.webView setDataDetectorTypes:UIDataDetectorTypeAll];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:UAMessageCenterLocalizedString(@"ua_delete")
                                                                               style:UIBarButtonItemStylePlain
                                                                             target:self
                                                                             action:@selector(delete:)];
    
    // get initial list of messages in the inbox
    [self copyMessages];
    
    if (self.message) {
        [self loadMessage:self.message onlyIfChanged:NO];
    } else {
        [self coverWithMessage:UAMessageCenterLocalizedString(@"ua_message_not_selected")];
    }
    
    self.isVisible = NO;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(messageListUpdated)
                                                 name:UAInboxMessageListUpdatedNotification object:nil];
}

- (void)viewDidAppear:(BOOL)animated {
    self.isVisible = YES;
    
    [super viewDidAppear:animated];
    
    if (self.message) {
        // if webview has already finished loading, we need to hide the loading indicator and uncover the view.
        if (!self.webView.loading) {
            [self uncoverAndHideLoadingIndicator];
        }
    } else {
        [self coverWithMessage:UAMessageCenterLocalizedString(@"ua_message_not_selected")];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UAInboxMessageListUpdatedNotification object:nil];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    self.isVisible = NO;
}

#pragma mark -
#pragma mark UI

- (void)delete:(id)sender {
    if (self.message) {
        [[UAirship inbox].messageList markMessagesDeleted:@[self.message] completionHandler:nil];
    }
}

- (void)coverWithMessage:(NSString *)message {
    self.title = nil;
    self.coverLabel.text = message;
    self.coverView.hidden = NO;
    self.navigationItem.rightBarButtonItem.enabled = NO;
}

- (void)coverWithBlankViewAndShowLoadingIndicator {
    self.coverLabel.text = nil;
    self.coverView.hidden = NO;
    self.navigationItem.rightBarButtonItem.enabled = NO;
    [self.loadingIndicatorView show];
}

- (void)uncoverAndHideLoadingIndicator {
    self.coverView.hidden = YES;
    self.navigationItem.rightBarButtonItem.enabled = YES;
    [self.loadingIndicatorView hide];
}

- (void)loadMessageForID:(NSString *)mid {
    [self loadMessage:[self messageForID:mid] onlyIfChanged:NO];
}

- (void)loadMessageAtIndex:(NSUInteger)index {
    [self loadMessage:[self messageAtIndex:index] onlyIfChanged:NO];
}

static NSString *urlForBlankPage = @"about:blank";

- (void)loadMessage:(UAInboxMessage *)message onlyIfChanged:(BOOL)onlyIfChanged {
    if (!message) {
        self.message = message;
        self.messageIndex=NSNotFound;
        [self coverWithMessage:UAMessageCenterLocalizedString(@"ua_message_not_selected")];
        return;
    }
    
    self.messageIndex = [self indexOfMessage:message];
    
    if (!onlyIfChanged || !self.message || ![message.messageID isEqualToString:self.message.messageID] || ![message.title isEqualToString:self.message.title] || ![message.messageBodyURL isEqual:self.message.messageBodyURL]) {
        [self.webView stopLoading];
        
        // start by covering the view and showing the loading indicator
        [self coverWithBlankViewAndShowLoadingIndicator];
        
        // now load a blank page, so when the view is uncovered, it isn't still showing the previous web page
        // note: when the blank page has finished loading, it will load the message
        [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:urlForBlankPage]]];

        self.message = message;
    } else {
        if (!self.webView.loading) {
            [self uncoverAndHideLoadingIndicator];
        }
    }
}

// load the message into the web view
- (void)loadMessageIntoWebView {
    self.title = self.message.title;
    
    NSMutableURLRequest *requestObj = [NSMutableURLRequest requestWithURL:self.message.messageBodyURL];
    requestObj.timeoutInterval = 60;
    
    NSString *auth = [UAUtils userAuthHeaderString];
    [requestObj setValue:auth forHTTPHeaderField:@"Authorization"];
    
    [self.webView loadRequest:requestObj];
}

- (void)displayAlert:(BOOL)retry {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:UAMessageCenterLocalizedString(@"ua_connection_error")
                                                                   message:UAMessageCenterLocalizedString(@"ua_mc_failed_to_load")
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:UAMessageCenterLocalizedString(@"ua_ok")
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * action) {}];
    
    [alert addAction:defaultAction];

    if (retry) {
        UIAlertAction *retryAction = [UIAlertAction actionWithTitle:UAMessageCenterLocalizedString(@"ua_retry_button")
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction * _Nonnull action) {
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
                                                                [self loadMessage:self.message onlyIfChanged:NO];
#pragma GCC diagnostic pop
        }];

        [alert addAction:retryAction];
    }

    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark -
#pragma mark Methods to manage copy of inbox message list

- (void)copyMessages {
    if (self.filter) {
        self.messages = [NSArray arrayWithArray:[[UAirship inbox].messageList.messages filteredArrayUsingPredicate:self.filter]];
    } else {
        self.messages = [NSArray arrayWithArray:[UAirship inbox].messageList.messages];
    }
}


- (UAInboxMessage *)messageAtIndex:(NSUInteger)index {
    if (index < self.messages.count) {
        return [self.messages objectAtIndex:index];
    } else {
        return nil;
    }
}

- (NSUInteger)indexOfMessage:(UAInboxMessage *)messageToFind {
    if (!messageToFind) {
        return NSNotFound;
    }
    
    for (NSUInteger index = 0;index<self.messages.count;index++) {
        UAInboxMessage *message = [self messageAtIndex:index];
        if ([messageToFind.messageID isEqualToString:message.messageID]) {
            return index;
        }
    }
    
    return NSNotFound;
}

- (UAInboxMessage *)messageForID:(NSString *)messageIDToFind {
    if (!messageIDToFind) {
        return nil;
    } else {
        for (UAInboxMessage *message in self.messages) {
            if ([messageIDToFind isEqualToString:message.messageID]) {
                return message;
            }
        }
    }
    
    return nil;
}


#pragma mark UAUIWebViewDelegate

- (void)webViewDidFinishLoad:(UIWebView *)wv {
    NSCachedURLResponse *cachedResponse = [[NSURLCache sharedURLCache] cachedResponseForRequest:wv.request];
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)cachedResponse.response;
    NSInteger status = httpResponse.statusCode;

    // If the server returns something in the error range, load a blank page
    if (status >= 400 && status <= 599) {
        [self coverWithBlankViewAndShowLoadingIndicator];
        if (status >= 500) {
            // Display a retry alert
            [self displayAlert:YES];
        } else {
            // Display a generic alert
            [self displayAlert:NO];
        }
        return;
    } else if ([wv.request.URL.absoluteString isEqualToString:urlForBlankPage]) {
        [self loadMessageIntoWebView];
        return;
    }

    // Mark message as read after it has finished loading
    if (self.message.unread) {
        [self.message markMessageReadWithCompletionHandler:nil];
    }

    [self.webView injectInterfaceOrientation:(UIInterfaceOrientation)[[UIDevice currentDevice] orientation]];
    
    // if view has already appeared, we need to hide the loading indicator and uncover the view.
    if (self.isVisible) {
        [self uncoverAndHideLoadingIndicator];
    }
}

- (void)webView:(UIWebView *)wv didFailLoadWithError:(NSError *)error {
    if (error.code == NSURLErrorCancelled)
        return;
    UA_LDEBUG(@"Failed to load message: %@", error);
    [self uncoverAndHideLoadingIndicator];
    [self displayAlert:YES];
    
}

- (void)closeWindowAnimated:(BOOL)animated {
    if (self.closeBlock) {
        self.closeBlock(animated);
    }
}

#pragma mark UARichContentWindow

- (void)closeWebView:(UIWebView *)webView animated:(BOOL)animated {
    [self closeWindowAnimated:animated];
}

#pragma mark NSNotificationCenter callbacks

- (void)messageListUpdated {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        // copy the back-end list of messages as it can change from under the UI
        [self copyMessages];
        if ((self.messages.count == 0) || !self.message) {
            [self coverWithMessage:UAMessageCenterLocalizedString(@"ua_message_not_selected")];
        } else {
            if ([self indexOfMessage:self.message] == NSNotFound) {
                // If the index path is still accessible,
                // find the nearest accessible neighbor
                NSUInteger index = MIN(self.messages.count - 1, self.messageIndex);
                
                [self loadMessageAtIndex:index];
            }
        }
    });
}

@end
