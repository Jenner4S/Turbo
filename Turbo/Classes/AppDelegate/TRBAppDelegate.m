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

#import "TRBAppDelegate.h"
#import "NSData+Base64.h"
#import "TRBTVShowsStorage.h"
#import "TRBTVShowsViewController.h"
#import "TRBTVShowEpisode.h"
#import "TRBTVShowSeason.h"
#import "TRBTVShow.h"
#import "TRBTabBarController.h"
#import "TRBHost.h"
#import "TRBTorrentClient.h"
#import "TRBHostSelectionController.h"
#import "TKAlertCenter.h"

@implementation TRBAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
	_window.backgroundColor = [UIColor whiteColor];
	UILocalNotification * note = launchOptions[UIApplicationLaunchOptionsLocalNotificationKey];
	CGFloat color = (230.0 / 255.0);
	UIColor * barColor = [UIColor colorWithRed:color green:color blue:color alpha:1.0];
	UIColor * tintColor = [UIColor colorWithRed:0.0 green:(64.0 / 255.0) blue:(128.0 / 255.0) alpha:1.0];
	[[UINavigationBar appearance] setBarTintColor:barColor];
	[[UITabBar appearance] setBarTintColor:barColor];
	[_window setTintColor:tintColor];
    if (note)
		[self processLocalNotification:note];

    return YES;
}

- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification {
	[self processLocalNotification:notification];
}

- (void)applicationWillResignActive:(UIApplication *)application {
	// Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
	// Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
	// Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
	// If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
	// Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
	// Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
	LogV(@"Scheduled notifications: %@", application.scheduledLocalNotifications);
}

- (void)applicationWillTerminate:(UIApplication *)application {
	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
	LogV(@"open url: %@", url);
	LogV(@"annotation: %@", annotation);
	[self pickHostWithCompletion:^(TRBHost * host) {
		if ([url isFileURL]) {
			NSData * torrentData = [NSData dataWithContentsOfURL:url];
			NSString * base64String = [torrentData base64EncodedString];
			if ([base64String length]) {
				[host.client addTorrentWithBase64String:base64String completion:^(BOOL success, NSError * error) {
					LogV(@"success: %i", success);
					NSString * message = success ? @"Torrent added" : [error localizedDescription];
					[[TKAlertCenter defaultCenter] postAlertWithMessage:message];
				}];
			}
		} else {
			[host.client addTorrentAtURL:[url absoluteString] completion:^(BOOL success, NSError * error) {
				LogV(@"success: %i", success);
				NSString * message = success ? @"Torrent added" : [error localizedDescription];
				[[TKAlertCenter defaultCenter] postAlertWithMessage:message];
			}];
		}
	}];
	return YES;
}

//- (BOOL)application:(UIApplication *)application shouldSaveApplicationState:(NSCoder *)coder {
//	return YES;
//}
//
//- (BOOL)application:(UIApplication *)application shouldRestoreApplicationState:(NSCoder *)coder {
//	return YES;
//}

//- (UIViewController *)application:(UIApplication *)application viewControllerWithRestorationIdentifierPath:(NSArray *)identifierComponents coder:(NSCoder *)coder {
//	return nil;
//}

- (void)pickHostWithCompletion:(void(^)(TRBHost *))completion {
	TRBHostList * hostList = [TRBHostList new];
	if ([hostList activeHostCount] == 1 && [hostList inactiveHostCount] == 0) {
		if (completion) {
			completion([hostList activeHostAtIndex:0]);
        }
	} else if (([hostList activeHostCount] > 1) || ([hostList inactiveHostCount] > 0)) {
		TRBHostPickerViewController * hostPickerViewController = [[TRBHostPickerViewController alloc] initWithHostList:hostList];
		[hostPickerViewController setOnHostPick:completion];
		UINavigationController * navigationController = [[UINavigationController alloc] initWithRootViewController:hostPickerViewController];
		[_window.rootViewController presentViewController:navigationController animated:YES completion:NULL];
	} else if (completion) {
		completion(nil);
	}
}

#pragma mark - Private Methods

- (void)processLocalNotification:(UILocalNotification *)note {
	NSNumber * episodeID = note.userInfo[@"episodeID"];
	[[TRBTVShowsStorage sharedInstance] fetchTVShowEpisodeWithID:[episodeID unsignedIntegerValue] andHandler:^(TRBTVShowEpisode * episode) {
		if (episode) {
			[[NSNotificationCenter defaultCenter] postNotificationName:TRBTVShowNotification
																object:nil
															  userInfo:@{TRBTVShowEpisodeKey: episode}];
		}
		[[UIApplication sharedApplication] cancelLocalNotification:note];
	}];
}


@end
