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

#import "TRBBrowseTorrentsViewController.h"
#import "TRBBrowseCategoriesViewController.h"
#import "TRBRSSFeed.h"
#import "TRBTabBarController.h"
#import "TRBHTTPSession.h"
#import "TRBHost.h"
#import "TRBTorrentClient.h"
#import "NSString+TRBAdditions.h"
#import "TKAlertCenter.h"

@interface TRBBrowseTorrentsViewController ()

@end

@implementation TRBBrowseTorrentsViewController {
	TRBRSSFeed * _rss;
	UINavigationController * _categoriesNavController;
	TRBHTTPSession * _session;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        _categoryTag = 208; // High Res TV-Shows
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
	[self.refreshControl addTarget:self action:@selector(fetchRSSFeed) forControlEvents:UIControlEventValueChanged];
	TRBBrowseCategoriesViewController * controller = nil;
	if (self.revealingViewController) {
		controller = [self.storyboard instantiateViewControllerWithIdentifier:@"TRBBrowseCategoryViewController"];
		_categoriesNavController = [[UINavigationController alloc] initWithRootViewController:controller];
	} else if ([self.splitViewController.viewControllers count]) {
		UINavigationController * nav = self.splitViewController.viewControllers[0];
		controller = [nav.viewControllers firstObject];
	}
	__weak TRBBrowseTorrentsViewController * selfWeak = self;
	[controller setSelectionBlock:^(NSInteger category) {
		selfWeak.categoryTag = category;
		[selfWeak fetchRSSFeed];
	}];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	self.revealingViewController.rightViewController = _categoriesNavController;
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	if (!_rss)
		[self fetchRSSFeed];
}

//- (void)viewWillDisappear:(BOOL)animated {
//	[super viewWillDisappear:animated];
//}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark - Public Methods

- (void)fetchRSSFeed {
	NSString * url = [NSString stringWithFormat:@"http://rss.thepiratebay.se/%li", (long)_categoryTag];
	[_session GETXML:url parameters:nil completion:^(id data, NSURLResponse *response, NSError *error) {
		if (!error) {
			TRBXMLElement * xml = data;
			_rss = [[TRBRSSFeed alloc] initWithXMLElement:xml];
		} else {
			_rss = nil;
			NSString * message = [error localizedDescription];
			if (![message length])
				message = @"Unsupported status code";
			[[TKAlertCenter defaultCenter] postAlertWithMessage:message];
		}
		[self.refreshControl endRefreshing];
		[self.tableView reloadData];
		if ([_rss.items count]) {
			[self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]
								  atScrollPosition:UITableViewScrollPositionTop
										  animated:YES];
		}
	}];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_rss.items count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString * CellIdentifier = @"TorrentRSS";
    TRBRSSTorrentCell * cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
	TRBRSSItem * item = _rss.items[indexPath.row];
	[cell setupWithItem:item];
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	return [_rss.title stringByReplacingOccurrencesOfString:@"The Pirate Bay - " withString:@""];
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	UIViewController * destination = [self.tmTabBarController newWebViewController];
	destination.title = @"Comments";
	TRBRSSItem * item = _rss.items[indexPath.row];
	UIWebView * webView = (UIWebView *)destination.view;
	NSURL * url = [NSURL URLWithString:item.comments];
	NSURLRequest * request = [NSURLRequest requestWithURL:url];
	[webView loadRequest:request];
	[self.navigationController pushViewController:destination animated:YES];
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
	[tableView selectRowAtIndexPath:indexPath animated:YES scrollPosition:UITableViewScrollPositionNone];
	TRBRSSItem * item = _rss.items[indexPath.row];
	UIActionSheet * actionSheet = [[UIActionSheet alloc] initWithTitle:item.title
															  delegate:self
													 cancelButtonTitle:(isIdiomPhone ? @"Cancel": nil)
												destructiveButtonTitle:nil
													 otherButtonTitles:@"Add Torrent", @"Search on IMDb", @"Search Movie Info", nil];
	UITableViewCell * cell = [tableView cellForRowAtIndexPath:indexPath];
	CGRect slice, remainder;
	CGRectDivide(cell.bounds, &slice, &remainder, 50.0, CGRectMaxXEdge);
	[actionSheet showFromRect:slice inView:cell animated:YES];
}

#pragma mark UIActionSheetDelegate Implementation

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
	NSIndexPath * indexPath = [self.tableView indexPathForSelectedRow];
	[self.tableView deselectRowAtIndexPath:indexPath animated:YES];
	TRBRSSItem * item = _rss.items[indexPath.row];
	switch (buttonIndex) {
		case 0:
			[self addTorrent:item];
			break;
		case 1: {
			NSString * query = [[item.title beautifyTorrentName] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
			[self searchOnIMDb:query];
			break;
		} case 2:
			[self searchMovieInfo:[item.title beautifyTorrentName]];
			break;
		default:
			break;
	}
}

#pragma mark - IBActions

- (IBAction)showCategories:(id)sender {
	[self.tmTabBarController toggleRightController];
}

- (IBAction)settingsButtonPressed:(UIBarButtonItem *)sender {
	[self.tmTabBarController showSettingsFromBarButtonItem:sender];
}

#pragma mark - Segues

- (IBAction)exitWebView:(UIStoryboardSegue *)segue {
	if (isIdiomPad)
		[self dismissViewControllerAnimated:YES completion:NULL];
}

#pragma mark - Private Methods

- (void)addTorrent:(TRBRSSItem *)item {
	[TRBGetAppDelegate() pickHostWithCompletion:^(TRBHost * host) {
		[host.client addTorrentAtURL:item.link completion:^(BOOL success, NSError * error) {
			if (success) {
				[[TKAlertCenter defaultCenter] postAlertWithMessage:@"Torrent added"];
			} else if (error && error.code != 1337) {
				[[TKAlertCenter defaultCenter] postAlertWithMessage:[error localizedDescription]];
			}
		}];
	}];
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

@implementation TRBRSSTorrentCell

- (void)setupWithItem:(TRBRSSItem *)item {
	self.title.text = item.title;
	self.desc.text = item.creator;
	self.date.text = item.pubDate;
}

@end
