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

#import "TRBReleasesViewController.h"
#import "TRBRelease.h"
#import "NSString+TRBAdditions.h"
#import "TRBSearchViewController.h"
#import "TRBReleseFiltersViewController.h"
#import "TRBTabBarController.h"
#import "TRBXMLElement.h"
#import "TRBHTTPSession.h"
#import "TKAlertCenter.h"
#import <objc/runtime.h>

@interface TRBReleasesViewController ()
@property (nonatomic, readonly, weak) TRBReleseFiltersViewController * filtersViewController;
@end

@implementation TRBReleasesViewController {
	NSMutableArray * _releases;
	UINavigationController * _filtersNavController;
	TRBHTTPSession * _session;
}

@dynamic filtersViewController;

#pragma mark - Initialization

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        _releases = [NSMutableArray new];
		_session = [[TRBHTTPSession alloc] initWithConfiguration:nil];
		_session.acceptedHTTPStatusCodes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(200, 100)];
    }
    return self;
}

- (void)dealloc {
    [_session invalidateAndCancel];
}

#pragma mark - View Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
	self.refreshControl = [[UIRefreshControl alloc] init];
	[self.refreshControl addTarget:self action:@selector(fetchReleases) forControlEvents:UIControlEventValueChanged];
	TRBReleseFiltersViewController * controller = nil;
	if (self.revealingViewController) {
		controller = [self.storyboard instantiateViewControllerWithIdentifier:@"TRBReleseFiltersViewController"];
		_filtersNavController = [[UINavigationController alloc] initWithRootViewController:controller];
	} else if ([self.splitViewController.viewControllers count]) {
		UINavigationController * nav = self.splitViewController.viewControllers[0];
		controller = (TRBReleseFiltersViewController *)[nav.viewControllers firstObject];
	}
	__weak TRBReleasesViewController * selfWeak = self;
	[controller setFiltersUpadated:^(NSDictionary * filters) {
		[selfWeak fetchReleases];
	}];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	self.revealingViewController.rightViewController = _filtersNavController;
	if (![_releases count])
		[self fetchReleases];
}

//- (void)viewDidAppear:(BOOL)animated {
//	[super viewDidAppear:animated];
//}

//- (void)viewWillDisappear:(BOOL)animated {
//	[super viewWillDisappear:animated];
//}

#pragma mark - Dynamic Properties

- (TRBReleseFiltersViewController *)filtersViewController {
	UINavigationController * nav = nil;
	if (self.splitViewController)
		nav = self.splitViewController.viewControllers[0];
	else if (self.revealingViewController)
		nav = _filtersNavController;
	return nav.viewControllers[0];
}

#pragma mark - Public Methods

- (void)fetchReleases {
	NSDictionary * filters = self.filtersViewController.filters;
	if (![self.refreshControl isRefreshing])
		[self.refreshControl beginRefreshing];
	NSString * URLString = [NSString stringWithFormat:@"http://www.vcdq.com/browse/rss/%@/%@/%@/%@/0/%@/%@",
							filters[@"Type"], filters[@"Subtype"], filters[@"Video Format"], filters[@"Source"], filters[@"Year"], filters[@"Genre"]];
	[_session GETXML:URLString parameters:nil completion:^(id data, NSURLResponse *response, NSError *error) {
		[self.refreshControl endRefreshing];
		[_releases removeAllObjects];
		if (!error) {
			TRBXMLElement * element = data;
			NSArray * items = [element[0] elementsAtPath:@"channel.item"];
			[self processRSSItems:items];
		} else {
			NSData * errorData = data;
			if ([error code] == 666 && [errorData length]) {
				error = nil;
				NSString * xml = [[NSString alloc] initWithData:errorData encoding:NSUTF8StringEncoding];
				xml = [xml stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"];
				errorData = [xml dataUsingEncoding:NSUTF8StringEncoding];
				TRBXMLElement * element = [TRBXMLElement XMLElementWithData:errorData error:&error];
				if (!error) {
					NSArray * items = [element[0] elementsAtPath:@"channel.item"];
					[self processRSSItems:items];
				}
			} else if (error) {
				NSString * message = error ? [error localizedDescription] : @"Unsupported status code";
				[[TKAlertCenter defaultCenter] postAlertWithMessage:message];
			}
		}
		[self.tableView reloadData];
		if ([_releases count]) {
			[self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]
								  atScrollPosition:UITableViewScrollPositionTop
										  animated:YES];
		}
	}];
}

#pragma mark - UITableViewDataSource Implementation

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [_releases count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_releases[section] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString * CellIdentifier = @"TRBReleaseCell";
    TRBReleaseCell * cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    TRBRelease * release = _releases[indexPath.section][indexPath.row];
	[cell setupWithRelease:release];
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	TRBRelease * release = _releases[section][0];
	NSDateFormatter * formatter = [NSDateFormatter new];
	[formatter setLocale:[NSLocale currentLocale]];
	[formatter setDateStyle:NSDateFormatterMediumStyle];
	return [formatter stringFromDate:release.pubDate];
}

#pragma mark - UITableViewDelegate Implementation

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	UIViewController * destination = [self.tmTabBarController newWebViewController];
	destination.title = @"Release Details";
	TRBRelease * release = _releases[indexPath.section][indexPath.row];
	UIWebView * webView = (UIWebView *)destination.view;
	NSURL * url = [NSURL URLWithString:release.link];
	NSURLRequest * request = [NSURLRequest requestWithURL:url];
	[webView loadRequest:request];
	[self.navigationController pushViewController:destination animated:YES];
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
	[tableView selectRowAtIndexPath:indexPath animated:YES scrollPosition:UITableViewScrollPositionNone];
	TRBRelease * release = _releases[indexPath.section][indexPath.row];
	UIActionSheet * actionSheet = [[UIActionSheet alloc] initWithTitle:release.title
															  delegate:self
													 cancelButtonTitle:(isIdiomPhone ? @"Cancel": nil)
												destructiveButtonTitle:nil
													 otherButtonTitles:@"Search torrent", @"Search on IMDb", @"Search Movie Info", nil];
	UITableViewCell * cell = [tableView cellForRowAtIndexPath:indexPath];
	CGRect slice, remainder;
	CGRectDivide(cell.bounds, &slice, &remainder, 50.0, CGRectMaxXEdge);
	[actionSheet showFromRect:slice inView:cell animated:YES];
}

#pragma mark UIActionSheetDelegate Implementation

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
	NSIndexPath * indexPath = [self.tableView indexPathForSelectedRow];
	[self.tableView deselectRowAtIndexPath:indexPath animated:YES];
	TRBRelease * release = _releases[indexPath.section][indexPath.row];
	switch (buttonIndex) {
		case 0:
			[self searchOnTorrentz:release];
			break;
		case 1: {
			NSString * query = [[release.title beautifyTorrentName] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
			[self searchOnIMDb:query];
			break;
		} case 2:
			[self searchMovieInfo:[release.title beautifyTorrentName]];
			break;
		default:
			break;
	}
}

#pragma mark - IBActions

- (IBAction)showFilters:(id)sender {
	[self.tmTabBarController toggleRightController];
}

- (IBAction)settingsButtonPressed:(UIBarButtonItem *)sender {
	[self.tmTabBarController showSettingsFromBarButtonItem:sender];
}

- (IBAction)exitWebView:(UIStoryboardSegue *)segue {
	if (isIdiomPad)
		[self dismissViewControllerAnimated:YES completion:NULL];
}

#pragma mark - Private Methods

- (void)processRSSItems:(NSArray *)items {
	__block NSMutableArray * section = [NSMutableArray new];
	__block NSDateComponents * components = nil;
	NSCalendar * calendar = [NSCalendar currentCalendar];
	[items enumerateObjectsUsingBlock:^(TRBXMLElement * item, NSUInteger idx, BOOL *stop) {
		TRBRelease * release = [[TRBRelease alloc] initWithXMLElement:item];
		NSDateComponents * releaseComps = [calendar components:NSYearCalendarUnit|NSMonthCalendarUnit|NSDayCalendarUnit fromDate:release.pubDate];
		if (!components)
			components = releaseComps;
		if (components.day == releaseComps.day && components.month == releaseComps.month && components.year == releaseComps.year)
			[section addObject:release];
		else {
			[_releases addObject:section];
			section = [NSMutableArray new];
			[section addObject:release];
		}
		components = releaseComps;
	}];
	if ([section count])
		[_releases addObject:section];
}

- (void)searchOnTorrentz:(TRBRelease *)release {
	[[NSNotificationCenter defaultCenter] postNotificationName:TRBTorrentzSearchNotification
														object:nil
													  userInfo:@{TRBSearchQueryKey : release.title}];
}

- (void)searchOnIMDb:(NSString *)query {
	BOOL webOnly = [[NSUserDefaults standardUserDefaults] boolForKey:TRBIMDbSearchWebOnlyKey];
	if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"imdb:///"]] && !webOnly) {
		[[UIApplication sharedApplication] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"imdb:///find?q=%@", query]]];
	} else {
		UIViewController * controller = [self.tmTabBarController newWebViewController];
		controller.title = @"IMDb";
		UIWebView * webView = (UIWebView *)controller.view;
		NSURL * url = [NSURL URLWithString:[NSString stringWithFormat:@"http://www.imdb.com/find?q=%@", query]];
		NSURLRequest * request = [NSURLRequest requestWithURL:url];
		[webView loadRequest:request];
		[self.navigationController pushViewController:controller animated:YES];
	}
}

- (void)searchMovieInfo:(NSString *)query {
	[[NSNotificationCenter defaultCenter] postNotificationName:TRBMovieSearchNotification
														object:nil
													  userInfo:@{TRBSearchQueryKey : query}];
}

@end

@implementation TRBReleaseCell

- (void)setupWithRelease:(TRBRelease *)release {
	_title.text = release.title;
	_type.text = release.type;
	_genre.text = release.genre;
	_source.text = release.source;
	_year.text = release.year;
}

@end
