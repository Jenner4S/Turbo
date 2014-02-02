/*
 The MIT License (MIT)

 Copyright (c) 2014 Mike Godenzi

 Permission is hereby granted, free of charge, to any person obtaining a copy of
 this software and associated documentation files (the "Software"), to deal in
 the Software without restriction, including without limitation the rights to
 use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
 the Software, and to permit persons to whom the Software is furnished to do so,
 subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
 FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
 COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
 IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import "TRBTabBarController.h"

typedef NS_ENUM(NSInteger, TRBTabs) {
	TRBTabsTorrents = 0,
	TRBTabsTVShows,
	TRBTabsMovieInfo,
	TRBTabsSearch,
	TRBTabsBrowse,
	TRBTabsReleases,
	TRBTabsLibrary,

	TRBTabsCount,
	TRBMandatory = TRBTabsLibrary
};

static NSString * StoryboardFiles[TRBTabsCount] = {
	@"Transmission", @"TVShows", @"Movies", @"Search", @"TPB", @"Releases", @"Library"
};

@interface TRBTabBarController () <UITabBarControllerDelegate>

@end

@implementation TRBTabBarController {
	UIPopoverController * _popoverViewController;
	id _observer;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
	self = [super initWithCoder:aDecoder];
	if (self) {
		[self loadControllers];
		self.delegate = self;
		typeof(self) __weak selfWeak = self;
		_observer = [[NSNotificationCenter defaultCenter] addObserverForName:TRBSettingsUpdatedNotification
																	  object:nil
																	   queue:[NSOperationQueue mainQueue]
																  usingBlock:^(NSNotification *note) {
																	  BOOL hasLibrary = [selfWeak checkHasLibrary];
																	  if (hasLibrary != (TRBTabsLibrary < [self.viewControllers count]))
																		  [selfWeak loadControllers];
																  }];
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	if (isIdiomPad) {
		UIStoryboard * storyboard = [UIStoryboard storyboardWithName:@"MainStoryboard_iPad" bundle:nil];
		UIViewController * settings = [storyboard instantiateViewControllerWithIdentifier:@"TRBSettingsViewController"];
		_popoverViewController = [[UIPopoverController alloc] initWithContentViewController:settings];
	}
}

- (BOOL)shouldAutorotate {
	BOOL result = YES;
	if (self.selectedViewController)
		result = [self.selectedViewController shouldAutorotate];
	return result;
}

- (NSUInteger)supportedInterfaceOrientations {
	NSUInteger result = UIInterfaceOrientationMaskAll;
	if (self.selectedViewController)
		result = [self.selectedViewController supportedInterfaceOrientations];
	return result;
}

- (UIViewController *)childViewControllerForStatusBarHidden {
	return self.selectedViewController;
}

- (UIViewController *)childViewControllerForStatusBarStyle {
	return self.selectedViewController;
}

- (void)showSettingsFromView:(UIView *)view {
	CGRect frame = [self.view convertRect:view.frame fromView:[view superview]];
	[_popoverViewController presentPopoverFromRect:frame
											inView:self.view
						  permittedArrowDirections:UIPopoverArrowDirectionUp
										  animated:YES];
}

- (void)showSettingsFromBarButtonItem:(UIBarButtonItem *)item {
	[_popoverViewController presentPopoverFromBarButtonItem:item
								   permittedArrowDirections:UIPopoverArrowDirectionUp
												   animated:YES];
}

- (void)toggleRightController {
	if (self.revealingViewController.state == TRBRevealingViewControllerStateConcealed)
		[self.revealingViewController revealRightViewControllerAnimated:YES completion:NULL];
	else
		[self.revealingViewController concealViewControllerAnimated:YES completion:NULL];
}

- (UIViewController *)newWebViewController {
	return [self.storyboard instantiateViewControllerWithIdentifier:@"TRBWebViewController"];
}

#pragma mark - UITabBarControllerDelegate Implementation

//- (void)tabBarController:(UITabBarController *)tabBarController willEndCustomizingViewControllers:(NSArray *)viewControllers changed:(BOOL)changed {
//	if (changed) {
//		
//	}
//}

#pragma mark - Private Methods

- (void)loadControllers {
	NSMutableArray * controllers = [NSMutableArray arrayWithCapacity:TRBTabsCount];
	NSInteger tabs = [self checkHasLibrary] ? TRBTabsCount : TRBMandatory;
	for (NSUInteger i = 0; i < tabs; i++) {
		NSString * storyboardName = StoryboardFiles[i];
		if (isIdiomPhone)
			storyboardName = [storyboardName stringByAppendingString:@"~iphone"];
		else
			storyboardName = [storyboardName stringByAppendingString:@"~ipad"];
		UIStoryboard * storyboard = [UIStoryboard storyboardWithName:storyboardName bundle:nil];
		UIViewController * controller = [storyboard instantiateInitialViewController];
		[controllers addObject:controller];
	}
	[self setViewControllers:controllers];
}

- (BOOL)checkHasLibrary {
	NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
	NSString * host = [defaults objectForKey:TRBSynologyHostKey];
	NSString * port = [defaults objectForKey:TRBSynologyPortKey];
	return [host length] && [port length];
}

@end

@implementation UIViewController (TRBTabBarControllerAddition)

- (TRBTabBarController *)tmTabBarController {
	TRBTabBarController * result = nil;
	if ([self.tabBarController isKindOfClass:[TRBTabBarController class]])
		result = (TRBTabBarController *)self.tabBarController;
	return result;
}

@end
