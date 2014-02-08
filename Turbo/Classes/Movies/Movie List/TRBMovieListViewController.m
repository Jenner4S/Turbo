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

#import "TRBMovieListViewController.h"
#import "TRBMovieListMenuViewController.h"
#import "TRBRottenTomatoesClient.h"
#import "TRBTabBarController.h"
#import "TRBMovieInfoViewController.h"
#import "TRBMovie.h"
#import "TKAlertCenter.h"
#import "TRBAsyncOperation.h"

static NSString * const RTSectionTitles[TRBRTListTypeCount] = {
	@"Box Office",
	@"In Theaters",
	@"Opening",
	@"Upcoming",
	@"Top Rentals",
	@"Current Releases",
	@"New Releases",
	@"Upcoming DVDs",
};

typedef NS_ENUM(NSUInteger, TRBMovieMode) {
	TRBMovieModeList = 0,
	TRBMovieModeSearch,

	TRBMovieModeCount
};

@interface TRBMovieListViewController ()<UIActionSheetDelegate, UISearchBarDelegate, UISearchDisplayDelegate>

@end

@implementation TRBMovieListViewController {
	TRBRTListType _currentList;
	UINavigationController * _rtListNavController;
	NSMutableArray * _movies[TRBMovieModeCount];
	TRBMovie * _selectedMovie;

	__weak IBOutlet UISearchBar * _searchBar;
	__weak IBOutlet UIBarButtonItem *_listsButton;
	NSString * _currentQuery;
	id _observer;

	NSUInteger _totalResults;
	NSUInteger _page;

	NSOperationQueue * _queue;
	BOOL _shouldPerformSearch;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
		_queue = [[NSOperationQueue alloc] init];
		[_queue setMaxConcurrentOperationCount:1];
		_movies[TRBMovieModeList] = [NSMutableArray new];
		_page = 1;
		_movies[TRBMovieModeSearch] = [NSMutableArray new];
		_observer = [[NSNotificationCenter defaultCenter] addObserverForName:TRBMovieSearchNotification
																	  object:nil
																	   queue:[NSOperationQueue mainQueue]
																  usingBlock:^(NSNotification * note) {
																	  self.tabBarController.selectedViewController = self.splitViewController ? self.splitViewController : self.parentViewController;
																	  NSString * query = [note userInfo][TRBSearchQueryKey];
																	  if ([query length]) {
																		  _currentQuery = query;
																		  [_movies[TRBMovieModeSearch] removeAllObjects];
																		  if (self.isViewLoaded) {
																			  [self.searchDisplayController setActive:YES animated:NO];
																			  _searchBar.text = query;
																			  [self startSearch];
																		  } else
																			  _shouldPerformSearch = YES;
																	  }
																  }];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];
	self.tableView.tag = TRBMovieModeList;
	_searchBar.placeholder = @"Search Movie";
	self.searchDisplayController.searchResultsTableView.rowHeight = 100.0;
	self.searchDisplayController.searchResultsTableView.tag = TRBMovieModeSearch;
	self.searchDisplayController.displaysSearchBarInNavigationBar = isIdiomPhone;
	self.searchDisplayController.navigationItem.title = @"Movies";
	self.navigationItem.rightBarButtonItem = _listsButton;
	self.refreshControl = [[UIRefreshControl alloc] init];
	[self.refreshControl addTarget:self action:@selector(refreshResults) forControlEvents:UIControlEventValueChanged];

	TRBMovieListMenuViewController * controller = nil;
	if (self.revealingViewController) {
		controller = [self.storyboard instantiateViewControllerWithIdentifier:@"TRBRTListsViewController"];
		_rtListNavController = [[UINavigationController alloc] initWithRootViewController:controller];
	} else if ([self.splitViewController.viewControllers count]) {
		UINavigationController * nav = self.splitViewController.viewControllers[0];
		controller = (TRBMovieListMenuViewController *)[nav.viewControllers firstObject];
	}
	
	__weak TRBMovieListViewController * selfWeak = self;
	[controller setListUpdated:^(NSUInteger list) {
		[selfWeak showListAtIndex:list];
	}];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	self.revealingViewController.rightViewController = _rtListNavController;
	if (![_movies[TRBMovieModeList] count])
		[self fetchList];
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	if ([_currentQuery length] && _shouldPerformSearch) {
		_shouldPerformSearch = NO;
		[self.searchDisplayController setActive:YES animated:NO];
		_searchBar.text = _currentQuery;
		[self startSearch];
	}
}

#pragma mark - Public Methods

- (void)showListAtIndex:(NSUInteger)idx {
	if (idx != _currentList && idx < TRBRTListTypeCount) {
		if ([self.searchDisplayController isActive])
			[self.searchDisplayController setActive:NO animated:YES];
		_currentList = idx;
		[self fetchList];
	}
}

#pragma mark - UISearchDisplayControllerDelegate Implementation

- (void)searchDisplayControllerWillBeginSearch:(UISearchDisplayController *)controller {
	self.navigationItem.rightBarButtonItem = nil;
	_searchBar.showsCancelButton = YES;
}

- (void)searchDisplayControllerWillEndSearch:(UISearchDisplayController *)controller {
	_searchBar.showsCancelButton = NO;
	self.navigationItem.rightBarButtonItem = _listsButton;
}

- (void)searchDisplayControllerDidEndSearch:(UISearchDisplayController *)controller {
	[self.tableView reloadData];
}

- (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString {
	return NO;
}

#pragma mark - UISearchBarDelegate Implementation

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
	_currentQuery = searchBar.text;
	if ([_currentQuery length]) {
		[_movies[TRBMovieModeSearch] removeAllObjects];
		[self startSearch];
	}
	[searchBar resignFirstResponder];
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
	UITableView * tableView = (UITableView *)scrollView;
	 NSInteger count = [_movies[tableView.tag] count];
	if (![self.refreshControl isRefreshing] && (tableView != self.tableView) && _totalResults > count) {
		CGFloat actualPosition = scrollView.contentOffset.y;
		CGFloat contentHeight = scrollView.contentSize.height - (tableView.rowHeight * 6.0);
		if (actualPosition >= contentHeight) {
			_page++;
			[self startSearch];
		}
	}
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_movies[tableView.tag] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString * CellIdentifier = @"TRBRTCell";

	UITableViewCell * result = nil;

	if (indexPath.row < [_movies[tableView.tag] count]) {
		TRBMovieListCell * cell = nil;
		if (tableView == self.tableView)
			cell = [self.tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
		else {
			cell = [self.tableView dequeueReusableCellWithIdentifier:CellIdentifier];
			if (!cell)
				cell = [[TRBMovieListCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
		}

		TRBMovie * movie = _movies[tableView.tag][indexPath.row];

		[cell setupWithMovie:movie];

		UIImage * poster = movie.posterImage;
		if (!poster && [movie.posters count])
			[self fetchPosterForMovie:movie inTable:tableView atIndexPath:indexPath];
		
		result = cell;
	}

    return result;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	NSString * title = nil;
	switch (tableView.tag) {
		case TRBMovieModeList:
			title = RTSectionTitles[_currentList];
			break;
		case TRBMovieModeSearch:
			title = _currentQuery ? [NSString stringWithFormat:@"Results for: %@", _currentQuery] : nil;
			break;
		default:
			break;
	}
	return title;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.row < [_movies[tableView.tag] count]) {
		_selectedMovie = _movies[tableView.tag][indexPath.row];
		[self performSegueWithIdentifier:@"TRBRTShowMovie" sender:tableView];
	}
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.row < [_movies[tableView.tag] count]) {
		[tableView selectRowAtIndexPath:indexPath animated:YES scrollPosition:UITableViewScrollPositionNone];
		TRBMovie * movie = _movies[tableView.tag][indexPath.row];
		UIActionSheet * actionSheet = [[UIActionSheet alloc] initWithTitle:movie.title
																  delegate:self
														 cancelButtonTitle:(isIdiomPhone ? @"Cancel": nil)
													destructiveButtonTitle:nil
														 otherButtonTitles:@"Search torrent", nil];
		actionSheet.delegate = self;
		actionSheet.tag = tableView.tag;
		UITableViewCell * cell = [tableView cellForRowAtIndexPath:indexPath];
		CGRect slice, remainder;
		CGRectDivide(cell.bounds, &slice, &remainder, 50.0, CGRectMaxXEdge);
		[actionSheet showFromRect:slice inView:cell animated:YES];
	}
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	CGFloat result = 100.0;
	if (indexPath.row < [_movies[tableView.tag] count]) {
		TRBMovie * movie = _movies[tableView.tag][indexPath.row];
		UIImage * poster = movie.posterImage;
		if (poster)
			result = MAX(poster.size.height, result);
	}
	return result;
}

#pragma mark - UIActionSheetDelegate Implementation

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
	UITableView * tableView = actionSheet.tag == self.tableView.tag ? self.tableView : self.searchDisplayController.searchResultsTableView;
	NSIndexPath * indexPath = [tableView indexPathForSelectedRow];
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	TRBMovie * movie = _movies[tableView.tag][indexPath.row];
	if (buttonIndex == 0)
		[self searchOnTorrentz:movie];
}

#pragma mark - IBActions

- (IBAction)showLists:(UIBarButtonItem *)sender {
	[self.tmTabBarController toggleRightController];
}

- (IBAction)settingsButtonPressed:(UIBarButtonItem *)sender {
	[self.tmTabBarController showSettingsFromBarButtonItem:sender];
}

#pragma mark - Segues

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
	if ([segue.identifier isEqualToString:@"TRBRTShowMovie"]) {
		TRBMovieInfoViewController * movieController = segue.destinationViewController;
		[movieController showMovie:_selectedMovie];
	}
}

- (IBAction)returnToMovieList:(UIStoryboardSegue *)segue {
	if (isIdiomPad)
		[self dismissViewControllerAnimated:YES completion:NULL];
}

#pragma mark - Private Methods

- (void)refreshResults {
	[self fetchList];
}

- (void)fetchList {
	[_queue addOperation:[TRBAsyncOperation operationWithBlock:^(TRBAsyncOperation *op) {
		if (![self.refreshControl isRefreshing])
			[self.refreshControl beginRefreshing];
		[[TRBRottenTomatoesClient sharedInstance] fetchMovieList:_currentList withHandler:^(NSDictionary *json, NSError *error) {
			[self.refreshControl endRefreshing];
			LogCE(error != nil, [error localizedDescription]);
			[_movies[TRBMovieModeList] removeAllObjects];
			if (json) {
				NSArray * movies = json[@"movies"];
				for (NSDictionary * movie in movies) {
					TRBMovie * tmMovie = [[TRBMovie alloc] initWithRTJSON:movie];
					[_movies[TRBMovieModeList] addObject:tmMovie];
				}
				if (!self.searchDisplayController.isActive) {
					[self.tableView reloadData];
					if ([_movies[TRBMovieModeList] count])
						[self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]
											  atScrollPosition:UITableViewScrollPositionTop
													  animated:YES];
				}
			} else if (error)
				[[TKAlertCenter defaultCenter] postAlertWithMessage:[error localizedDescription]];
			[op stop];
		}];
	}]];
}

- (void)fetchPosterForMovie:(TRBMovie *)movie inTable:(UITableView *)tableView atIndexPath:(NSIndexPath *)indexPath {
	CGFloat scale = [UIScreen mainScreen].scale;
	NSString * imageType = scale > 1.0 ? @"detailed" : @"thumbnail";
	NSString * url = movie.posters[imageType];
	[[TRBRottenTomatoesClient sharedInstance] fetchImageAtURL:url withHandler:^(UIImage * image, NSError *error) {
		LogCE(error != nil, [error localizedDescription]);
		if (image)
			movie.posterImage = image;
		else
			movie.posterImage = [UIImage imageNamed:@"profile"];
		[tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
	}];
}

- (void)startSearch {
	[_queue addOperation:[TRBAsyncOperation operationWithBlock:^(TRBAsyncOperation *op) {
		_searchBar.showsSearchResultsButton = NO;
		if (![self.refreshControl isRefreshing])
			[self.refreshControl beginRefreshing];
		[[TRBRottenTomatoesClient sharedInstance] searchWithQuery:_currentQuery page:_page andHandler:^(NSDictionary *json, NSError *error) {
			[self.refreshControl endRefreshing];
			LogCE(error != nil, [error localizedDescription]);
			if (json) {
				NSArray * movies = json[@"movies"];
				for (NSDictionary * movie in movies) {
					TRBMovie * tmMovie = [[TRBMovie alloc] initWithRTJSON:movie];
					[_movies[TRBMovieModeSearch] addObject:tmMovie];
				}
				_totalResults = [json[@"total"] unsignedIntegerValue];
			} else if (error)
				[[TKAlertCenter defaultCenter] postAlertWithMessage:[error localizedDescription]];
			[self.searchDisplayController.searchResultsTableView reloadData];
			[op stop];
		}];
	}]];
}

- (void)searchOnTorrentz:(TRBMovie *)movie {
	[[NSNotificationCenter defaultCenter] postNotificationName:TRBTorrentzSearchNotification
														object:nil
													  userInfo:@{TRBSearchQueryKey : movie.title}];
}

@end

@interface TRBMovieListCell ()
@property (weak, nonatomic) IBOutlet NSLayoutConstraint * posterWidth;
@end

@implementation TRBMovieListCell

- (void)prepareForReuse {
	_poster.image = nil;
	_poster.highlightedImage = nil;
	_criticsImage.image = nil;
	_audienceImage.image = nil;
}

- (void)setupWithMovie:(TRBMovie *)movie {
	_title.text = movie.title;

	if ([movie.criticsRating length]) {
		_criticsRating.text = [NSString stringWithFormat:@"%@%%", movie.criticsScore];
		_criticsImage.image = [UIImage imageNamed:movie.criticsRating];
	} else
		_criticsRating.text = @"- %";

	if ([movie.audienceRating length]) {
		_audienceRating.text = [NSString stringWithFormat:@"%@%%", movie.audienceScore];
		_audienceImage.image = [UIImage imageNamed:movie.audienceRating];
	} else
		_audienceRating.text = @"- %";

	_consensus.text = movie.criticsConsensus;
	_year.text = [movie.year description];

	_cast.text = movie.cast;

	UIImage * poster = movie.posterImage;

	if (!poster && ![movie.posters count])
		poster = [UIImage imageNamed:@"profile"];

	_poster.image = poster;

	if (_posterWidth.constant != _poster.image.size.width) {
		_posterWidth.constant = _poster.image.size.width;
		[self setNeedsUpdateConstraints];
	}
}

@end
