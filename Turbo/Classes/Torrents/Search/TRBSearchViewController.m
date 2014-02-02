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

#import "TRBSearchViewController.h"
#import "TRBRSSFeed.h"
#import "NSString+TRBAdditions.h"
#import "TRBSearchOptionsViewController.h"
#import "TRBTabBarController.h"
#import "TRBNavigationController.h"
#import "TRBHTTPSession.h"
#import "TRBHost.h"
#import "TRBTorrentClient.h"
#import "TKAlertCenter.h"

#define kMaxResultsPerSearch 100

__attribute__((always_inline)) static inline NSIndexPath * TRBRealIndexPath(NSIndexPath * indexPath) {
	NSInteger row = indexPath.row;
	NSInteger index1 = row / kMaxResultsPerSearch;
	NSInteger index2 = row - (index1 * kMaxResultsPerSearch);
	return [NSIndexPath indexPathForRow:index2 inSection:index1];
}

@interface TRBSearchViewController ()
@property (nonatomic, weak, readonly) TRBSearchOptionsViewController * searchOptionsViewController;
@end

@implementation TRBSearchViewController {
	NSMutableArray * _searchResults;
	NSString * _currentQuery;
	NSNumber * _page;
	BOOL _isSearching;
	UISearchBar * _searchBar;
	NSInteger _currentCount;
	id _observer;
	UINavigationController * _searchOptionsNavController;
	TRBHTTPSession * _session;
}

@dynamic searchOptionsViewController;

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        _searchResults = [NSMutableArray new];
		_searchBar = [[UISearchBar alloc] init];
		_searchBar.barStyle = UIBarStyleDefault;
		_searchBar.delegate = self;
		_searchBar.placeholder = @"Search torrents";
		self.navigationItem.titleView = _searchBar;
		_observer = [[NSNotificationCenter defaultCenter] addObserverForName:TRBTorrentzSearchNotification
																	  object:nil
																	   queue:[NSOperationQueue mainQueue]
																  usingBlock:^(NSNotification * note) {
																	  self.tabBarController.selectedViewController = self.splitViewController ? self.splitViewController : self.parentViewController;
																	  NSString * query = [note userInfo][TRBSearchQueryKey];
																	  if ([query length]) {
																		  _currentQuery = query;
																		  _searchBar.text = query;
																		  [self.searchOptionsViewController reset];
																		  [self.revealingViewController concealViewControllerAnimated:YES completion:NULL];
																		  [self restartSearch];
																	  }
																  }];
		_session = [[TRBHTTPSession alloc] initWithConfiguration:nil];
		_session.acceptedHTTPStatusCodes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(200, 100)];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:_observer];
	[_session invalidateAndCancel];
}

#pragma mark - View Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
	TRBSearchOptionsViewController * controller = nil;
	if (self.revealingViewController) {
		controller = [self.storyboard instantiateViewControllerWithIdentifier:@"TRBSearchOptionsViewController"];
		_searchOptionsNavController = [[UINavigationController alloc] initWithRootViewController:controller];
	} else if ([self.splitViewController.viewControllers count]) {
		UINavigationController * nav = self.splitViewController.viewControllers[0];
		controller = [nav.viewControllers firstObject];
	}
	__weak TRBSearchViewController * selfWeak = self;
	[controller setOptionsUpadated:^(NSDictionary * options) {
		[selfWeak restartSearch];
	}];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	self.revealingViewController.rightViewController = _searchOptionsNavController;
}

#pragma mark - Dynamic Properties

- (TRBSearchOptionsViewController *)searchOptionsViewController {
	TRBSearchOptionsViewController * result = nil;
	if (self.revealingViewController)
		result = _searchOptionsNavController.viewControllers[0];
	else if (self.splitViewController) {
		UINavigationController * nav = (UINavigationController *)self.splitViewController.viewControllers[0];
		result = nav.viewControllers[0];
	}
	return result;
}

#pragma mark - UISearchBarDelegate Implementation

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
	_currentQuery = searchBar.text;
	[self restartSearch];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
	[searchBar resignFirstResponder];
}

#pragma mark - UIScrollViewDelegate



- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
	[_searchBar resignFirstResponder];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
	if (!_isSearching && _currentCount && ((_currentCount % kMaxResultsPerSearch) == 0)) {
		CGFloat actualPosition = scrollView.contentOffset.y;
		CGFloat contentHeight = scrollView.contentSize.height - (self.tableView.rowHeight * 6.0);
		if (actualPosition >= contentHeight) {
			_page = @([_page unsignedIntegerValue] + 1);
			[self startSearch];
		}
	}
}

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return _currentCount;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString * CellResultIdentifier = @"SearchResult";
	UITableViewCell * cell = nil;
	if (indexPath.row < _currentCount) {
		TRBSearchCell * resultCell = [tableView dequeueReusableCellWithIdentifier:CellResultIdentifier forIndexPath:indexPath];
		NSIndexPath * convertedIndexPath = TRBRealIndexPath(indexPath);
		TRBRSSItem * item = ((TRBRSSFeed *)_searchResults[convertedIndexPath.section]).items[convertedIndexPath.row];
		[resultCell setupWithRSSItem:item];
		cell = resultCell;
	}
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.row < _currentCount) {
		UIViewController * destination = [self.tmTabBarController newWebViewController];
		destination.title = @"Torrent Page";
		TRBRSSItem * item = ((TRBRSSFeed *)_searchResults[indexPath.section]).items[indexPath.row];
		UIWebView * webView = (UIWebView *)destination.view;
		NSURL * url = [NSURL URLWithString:item.link];
		NSURLRequest * request = [NSURLRequest requestWithURL:url];
		[webView loadRequest:request];
		[self.navigationController pushViewController:destination animated:YES];
	}
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.row < _currentCount) {
		[tableView selectRowAtIndexPath:indexPath animated:YES scrollPosition:UITableViewScrollPositionNone];
		indexPath = TRBRealIndexPath(indexPath);
		TRBRSSItem * item = ((TRBRSSFeed *)_searchResults[indexPath.section]).items[indexPath.row];
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
}

#pragma mark UIActionSheetDelegate Implementation

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
	NSIndexPath * indexPath = [self.tableView indexPathForSelectedRow];
	[self.tableView deselectRowAtIndexPath:indexPath animated:YES];
	indexPath = TRBRealIndexPath(indexPath);
	TRBRSSItem * item = ((TRBRSSFeed *)_searchResults[indexPath.section]).items[indexPath.row];
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

- (IBAction)settingsButtonPressed:(UIBarButtonItem *)sender {
	[self.tmTabBarController showSettingsFromBarButtonItem:sender];
}

- (IBAction)showSearchOptions:(id)sender {
	[self.tmTabBarController toggleRightController];
}

- (IBAction)exitWebView:(UIStoryboardSegue *)segue {
	if (isIdiomPad)
		[self dismissViewControllerAnimated:YES completion:NULL];
}

#pragma mark - Public Methods

- (void)restartSearch {
	if ([_currentQuery length]) {
		[_searchResults removeAllObjects];
		_page = @0;
		_currentCount = 0;
		[self startSearch];
	}
}

#pragma mark - Private Methods

- (void)startSearch {
	if (!_isSearching) {
		_isSearching = YES;
		NSDictionary * parameters = @{@"q": [self searchQuery], @"p": [_page description]};
		[_session GETXML:@"http://torrentz.eu/feed" parameters:parameters completion:^(id data, NSURLResponse * response, NSError * error) {
			_isSearching = NO;
			NSString * message = nil;
			if (!error) {
				TRBXMLElement * rss = data;
				TRBRSSFeed * result = [[TRBRSSFeed alloc] initWithXMLElement:rss];
				if ([result.items count]) {
					[_searchResults addObject:result];
					_currentCount += [result.items count];
				} else
					message = @"No results";
				[_searchBar resignFirstResponder];
			} else {
				[_searchResults removeAllObjects];
				message = [error localizedDescription];
				if (![message length])
					message = @"Unsupported status code";
			}
			if (message)
				[[TKAlertCenter defaultCenter] postAlertWithMessage:message];
			[self.tableView reloadData];
			if (_currentCount && _currentCount <= kMaxResultsPerSearch) {
				[self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]
									  atScrollPosition:UITableViewScrollPositionTop animated:YES];
			}
		}];
	}
}

- (void)addTorrent:(TRBRSSItem *)item {
	NSDictionary * info = [item infoFromDescription];
	NSString * url = [NSString stringWithFormat:@"magnet:?xt=urn:btih:%@", [info valueForKey:@"Hash"]];
	[TRBGetAppDelegate() pickHostWithCompletion:^(TRBHost * host) {
		[host.client addTorrentAtURL:url completion:^(BOOL success, NSError * error) {
			if (success)
				[[TKAlertCenter defaultCenter] postAlertWithMessage:@"Torrent added"];
			else if (error && error.code != 1337)
				[[TKAlertCenter defaultCenter] postAlertWithMessage:[error localizedDescription]];
		}];
	}];
}

- (NSString *)searchQuery {
	NSString * result = _currentQuery;
	if ([self.searchOptionsViewController.options count]) {
		NSDictionary * options = self.searchOptionsViewController.options;
		NSMutableString * query = [NSMutableString stringWithFormat:@"%@ ", result];
		[options enumerateKeysAndObjectsUsingBlock:^(NSString * key, NSString * option, BOOL *stop) {
			[query appendString:option];
			[query appendString:@" "];
		}];
		result = query;
	}
	return result;
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

@implementation TRBSearchCell

- (void)setupWithRSSItem:(TRBRSSItem *)item {
	NSDictionary * info = [item infoFromDescription];
	self.title.text = item.title;
	self.seeds.text = info[@"Seeds"];
	self.leechers.text = info[@"Peers"];
	self.size.text = info[@"Size"];
	self.date.text = item.pubDate;
}

- (NSAttributedString *)formattedString:(NSString *)string {
	NSMutableAttributedString * result = [[NSMutableAttributedString alloc] initWithString:string];
	[result addAttribute:NSFontAttributeName
				   value:[UIFont systemFontOfSize:self.title.font.pointSize]
				   range:NSMakeRange(0, [result length])];
	while (YES) {
		NSRange boldStart = [string rangeOfString:@"<b>"];
		NSRange boldEnd = [string rangeOfString:@"</b>"];
		if (boldStart.location != NSNotFound && boldEnd.location != NSNotFound) {
			string = [string stringByReplacingCharactersInRange:boldEnd withString:@""];
			string = [string stringByReplacingCharactersInRange:boldStart withString:@""];
			[result deleteCharactersInRange:boldEnd];
			[result deleteCharactersInRange:boldStart];
			boldEnd.location = MIN(boldEnd.location - boldStart.length, [result length]);
			NSRange boldRange = NSMakeRange(boldStart.location, boldEnd.location - boldStart.location);
			[result addAttribute:NSFontAttributeName
						   value:[UIFont boldSystemFontOfSize:self.title.font.pointSize]
						   range:boldRange];
		} else
			break;
	}
	return result;
}

@end
