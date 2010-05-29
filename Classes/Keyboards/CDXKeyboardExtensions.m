//
//
// CDXKeyboardExtensions.m
//
//
// Copyright (c) 2009-2010 Arne Harren <ah@0xc0.de>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "CDXKeyboardExtensions.h"


@implementation CDXKeyboardExtensions

synthesize_singleton(sharedKeyboardExtensions, CDXKeyboardExtensions);

@synthesize responder;
@synthesize keyboardExtensions;

- (id)init {
    if ((self = [super init])) {
        ivar_assign(toolbar, [[UIToolbar alloc] init]);
        toolbar.barStyle = UIBarStyleDefault;
        ivar_assign(toolbarButtons, [[NSMutableArray alloc] init]);
        ivar_assign_and_retain(toolbarKeyboardButton, [self toolbarButtonWithTitle:@"abc"]);
        ivar_assign_and_retain(backgroundColor, [UIColor colorWithPatternImage:[UIImage imageNamed:@"KeyboardExtensionsBackground.png"]]);
        enabled = NO;
        visible = NO;
        activeExtensionTag = -1;
    }
    
    return self;
}

- (void)dealloc {
    ivar_release_and_clear(toolbar);
    ivar_release_and_clear(toolbarButtons);
    ivar_release_and_clear(responder);
    ivar_release_and_clear(keyboardExtensions);
    ivar_release_and_clear(backgroundColor);
    [super dealloc];
}

- (NSObject<CDXKeyboardExtension> *)keyboardExtensionByTag:(NSInteger)tag {
    if (tag >= 0) {
        return [[(NSObject<CDXKeyboardExtension> *)[keyboardExtensions objectAtIndex:tag] retain] autorelease];
    }
    
    return nil;
}

- (UIBarButtonItem *)toolbarButtonByTag:(NSInteger)tag {
    if (tag >= -1) {
        return [[(UIBarButtonItem *)[toolbarButtons objectAtIndex:tag + 1] retain] autorelease];
    }
    
    return toolbarKeyboardButton;
}

- (void)setToolbarHidden:(BOOL)hidden notification:(NSNotification *)notification {
    // get animation information for the keyboard
    CGRect keyboardBounds;
    [[notification.userInfo valueForKey:UIKeyboardBoundsUserInfoKey] getValue:&keyboardBounds];
    double keyboardAnimationDuration;
    [[notification.userInfo valueForKey:UIKeyboardAnimationDurationUserInfoKey] getValue:&keyboardAnimationDuration];
    CGPoint keyboardAnimationStartPoint;
    [[notification.userInfo valueForKey:UIKeyboardCenterBeginUserInfoKey] getValue:&keyboardAnimationStartPoint];
    CGPoint keyboardAnimationEndPoint;
    [[notification.userInfo valueForKey:UIKeyboardCenterEndUserInfoKey] getValue:&keyboardAnimationEndPoint];
    
    // animate the toolbar?
    BOOL keyboardAnimationHasYDistance = keyboardAnimationStartPoint.y != keyboardAnimationEndPoint.y;
    BOOL keyboardAnimationHasXDistance = keyboardAnimationStartPoint.x != keyboardAnimationEndPoint.x;
    BOOL animated = keyboardAnimationHasYDistance || keyboardAnimationHasXDistance;
    if (!hidden) {
        animated = animated & !visible;
    }
    
    // add the toolbar view to the application's main window
    [[[UIApplication sharedApplication] keyWindow] addSubview:toolbar];
    [toolbar sizeToFit];
    
    // get animation information for the toolbar
    CGRect toolbarFrame = [toolbar frame];
    CGRect toolbarFrameAnimationStart = toolbarFrame;
    toolbarFrameAnimationStart.origin.y = keyboardAnimationStartPoint.y - keyboardBounds.size.height/2 - toolbarFrame.size.height;
    toolbarFrameAnimationStart.origin.x = keyboardAnimationStartPoint.x - keyboardBounds.size.width/2;
    CGRect toolbarFrameAnimationEnd = toolbarFrame;
    toolbarFrameAnimationEnd.origin.y = keyboardAnimationEndPoint.y - keyboardBounds.size.height/2 - toolbarFrame.size.height;
    toolbarFrameAnimationEnd.origin.x = keyboardAnimationEndPoint.x - keyboardBounds.size.width/2;
    if (toolbarFrameAnimationStart.origin.y >= 480 - toolbarFrame.size.height) {
        toolbarFrameAnimationStart.origin.y = 480;
    }
    if (toolbarFrameAnimationEnd.origin.y >= 480 - toolbarFrame.size.height) {
        toolbarFrameAnimationEnd.origin.y = 480;
    }
    
    // now, animate and position the toolbar
    if (animated) {
        [toolbar setFrame:toolbarFrameAnimationStart];
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:keyboardAnimationDuration];
    }
    [toolbar setFrame:toolbarFrameAnimationEnd];
    
    if (hidden && activeExtensionTag != -1) {
        NSObject<CDXKeyboardExtension> *extension = [self keyboardExtensionByTag:activeExtensionTag];
        UIView *extensionView = [extension keyboardExtensionView];
        CGRect extensionViewFrameAnimationEnd = [extensionView frame];
        extensionViewFrameAnimationEnd.origin.y = keyboardAnimationEndPoint.y - keyboardBounds.size.height/2;
        extensionViewFrameAnimationEnd.origin.x = keyboardAnimationEndPoint.x - keyboardBounds.size.width/2;
        [extensionView setFrame:extensionViewFrameAnimationEnd];
    }
    if (!hidden && activeExtensionTag != -1) {
        [self deactivateKeyboardExtension:[self keyboardExtensionByTag:activeExtensionTag] tag:activeExtensionTag];
        [self activateKeyboardExtension:nil tag:-1];
    }
    
    if (animated) {
        [UIView commitAnimations];
    }
    
    // remember the rectangle for the extension views
    if (!hidden) {
        extensionViewRect.size = keyboardBounds.size;
        extensionViewRect.origin.x = keyboardAnimationEndPoint.x - keyboardBounds.size.width/2;
        extensionViewRect.origin.y = keyboardAnimationEndPoint.y - keyboardBounds.size.height/2;
        extensionViewRect.size.height = extensionViewRect.size.height;
    }
}

- (void)keyboardWillShow:(NSNotification *)notification {
    [self setToolbarHidden:NO notification:notification];
}

- (void)keyboardDidShow:(NSNotification *)notification {
    visible = YES;
}

- (void)keyboardWillHide:(NSNotification *)notification {
    [self setToolbarHidden:YES notification:notification];
}

- (void)keyboardDidHide:(NSNotification *)notification {
    [toolbar removeFromSuperview];
    visible = NO;
}

- (void)setEnabled:(BOOL)aEnabled {
    // nothing to do if already enabled
    if (enabled == aEnabled)
        return;
    
    enabled = aEnabled;
    
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    if (enabled) {
        // register for keyboard...Show events
        [notificationCenter addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
        [notificationCenter addObserver:self selector:@selector(keyboardDidShow:) name:UIKeyboardDidShowNotification object:nil];
        [notificationCenter addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
        [notificationCenter addObserver:self selector:@selector(keyboardDidHide:) name:UIKeyboardDidHideNotification object:nil];
    } else {
        // deregister for all events
        [notificationCenter removeObserver:self];
    }
}

- (void)setResponder:(NSObject *)aResponder keyboardExtensions:(NSArray *)aKeyboardExtensions {
    NSInteger tag = -1;
    ivar_assign_and_retain(responder, aResponder);
    [toolbarButtons removeAllObjects];
    [toolbarButtons addObject:toolbarKeyboardButton];
    toolbarKeyboardButton.tag = tag;
    
    ivar_assign_and_copy(keyboardExtensions, aKeyboardExtensions);
    for (NSObject<CDXKeyboardExtension> *extension in keyboardExtensions) {
        UIBarButtonItem *button = [self toolbarButtonWithTitle:[extension keyboardExtensionTitle]];
        button.tag = ++tag;
        [toolbarButtons addObject:button];
        [extension keyboardExtensionInitialize];
    }
    
    // set the toolbar buttons
    [toolbar setItems:toolbarButtons animated:NO];
    
    [self activateKeyboardExtension:nil tag:-1];
}

- (UIWindow *)keyboardWindow {
    // try to find the keyboard's window
    NSArray *applicationWindows = [[UIApplication sharedApplication] windows];
    for (UIWindow *window in applicationWindows) {
        for (UIView *view in [window subviews]) {
            if ([@"UIKeyboard" isEqualToString:NSStringFromClass([view class])]) {
                return window;
            }
        }
    }
    // return the second window
    if ([applicationWindows count] > 1) {
        return [applicationWindows objectAtIndex:1];
    }
    // fail
    return nil;
}

- (UIBarButtonItem *)toolbarButtonWithTitle:(NSString *)title {
    UIBarButtonItem *button = [[[UIBarButtonItem alloc] 
                                initWithTitle:title
                                style:UIBarButtonItemStyleBordered
                                target:self action:@selector(toolbarButtonPressed:)]
                               autorelease];
    button.width = 40;
    return button;
}

- (void)refreshKeyboardExtensions {
    NSUInteger count = [keyboardExtensions count];
    for (NSUInteger tag = 0; tag < count; tag++) {
        NSObject<CDXKeyboardExtension> *keyboardExtension = [keyboardExtensions objectAtIndex:tag];
        if (tag == activeExtensionTag) {
            if ([keyboardExtension respondsToSelector:@selector(keyboardExtensionWillBecomeActive)]) {
                [keyboardExtension keyboardExtensionWillBecomeActive];
            }
        }
        UIBarButtonItem *button = [toolbarButtons objectAtIndex:tag+1];
        button.title = [keyboardExtension keyboardExtensionTitle];
        if (tag == activeExtensionTag) {
            if ([keyboardExtension respondsToSelector:@selector(keyboardExtensionDidBecomeActive)]) {
                [keyboardExtension keyboardExtensionDidBecomeActive];
            }
        }
    }
}

- (void)activateKeyboardExtension:(NSObject<CDXKeyboardExtension> *)keyboardExtension tag:(NSInteger)tag {
    if ([keyboardExtension respondsToSelector:@selector(keyboardExtensionWillBecomeActive)]) {
        [keyboardExtension keyboardExtensionWillBecomeActive];
    }
    
    if (keyboardExtension != nil) {
        UIView *view = [keyboardExtension keyboardExtensionView];
        view.frame = extensionViewRect;
        [[self keyboardWindow] addSubview:view];
    }
    
    if ([keyboardExtension respondsToSelector:@selector(keyboardExtensionDidBecomeActive)]) {
        [keyboardExtension keyboardExtensionDidBecomeActive];
    }
    
    activeExtensionTag = tag;
    UIBarButtonItem *button = [self toolbarButtonByTag:tag];
    button.enabled = NO;
    if (tag != -1) {
        button.title = [keyboardExtension keyboardExtensionTitle];
    }
}

- (void)deactivateKeyboardExtension:(NSObject<CDXKeyboardExtension> *)keyboardExtension tag:(NSInteger)tag {
    if ([keyboardExtension respondsToSelector:@selector(keyboardExtensionWillBecomeInactive)]) {
        [keyboardExtension keyboardExtensionWillBecomeInactive];
    }    
    
    if (keyboardExtension != nil) {
        UIView *view = [keyboardExtension keyboardExtensionView];
        [view removeFromSuperview];
    }
    
    if ([keyboardExtension respondsToSelector:@selector(keyboardExtensionDidBecomeInactive)]) {
        [keyboardExtension keyboardExtensionDidBecomeInactive];
    }    
    
    UIBarButtonItem *button = [self toolbarButtonByTag:tag];
    button.enabled = YES;
}

- (void)toolbarButtonPressed:(id)sender {
    UIBarButtonItem *toolbarButton = (UIBarButtonItem *)sender;
    NSInteger eventExtensionTag = toolbarButton.tag;
    
    if (activeExtensionTag == eventExtensionTag) {
        // nothing to do
        return;
    }
    
    [self deactivateKeyboardExtension:[self keyboardExtensionByTag:activeExtensionTag] tag:activeExtensionTag];
    [self activateKeyboardExtension:[self keyboardExtensionByTag:eventExtensionTag] tag:eventExtensionTag];
}

- (UIColor *)backgroundColor {
    return [[backgroundColor retain] autorelease];
}

@end
