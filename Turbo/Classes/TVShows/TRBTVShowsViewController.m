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

#import "TRBTVShowsViewController.h"
#import "TRBTVShowsStorage.h"
#import "TRBTvDBClient.h"
#import "TRBTVShow.h"
#import "TRBTVShowEpisode.h"
#import "TRBTVShowEpisode+TRBAddtions.h"
#import "TRBTVShowSeason.h"
#import "TRBXMLElement+TRBTVShow.h"
#import "TRBTVShowDetailsViewController.h"
#import "TRBTVShowCalendarViewController.h"
#import "TRBTabBarController.h"
#import "TKAlertCenter.h"

typedef NS_ENUM(NSUInteger, TRBTVShowMode) {
	TRBTVShowModeList = 0,
	TRBTVShowModeSearch,

	TRBTVShowModeCount
};

@interface TRBTVShowsViewController ()<UISearchBarDelegate, UISearchDisplayDelegate, UIActionSheetDelegate>

@end

@implementation TRBTVShowsViewController {
	TRBTVShowMode _mode;
	NSMutableArray * _tvShows[TRBTVShowModeCount];
	NSMutableDictionary * _images;

	NSString * _currentQuery;
	id _observer;
	id _observer2;

	BOOL _shouldPreventEditing;

	UINavigationController * _calendarNavController;
	__weak IBOutlet UISearchBar * _searchBar;
	__weak IBOutlet UIBarButtonItem *_calendarButton;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        _tvShows[TRBTVShowModeList] = [NSMutableArray new];
		_tvShows[TRBTVShowModeSearch] = [NSMutableArray new];
		_images = [NSMutableDictionary new];
		_observer = [[NSNotificationCenter defaultCenter] addObserverForName:TRBTVShowSearchNotification
																	  object:nil
																	   queue:[NSOperationQueue mainQueue]
																  usingBlock:^(NSNotification * note) {
																	  self.tabBarController.selectedViewController = self.splitViewController ? self.splitViewController : self.parentViewController;
																	  NSString * query = [note userInfo][TRBSearchQueryKey];
																	  if ([query length]) {
																		  _currentQuery = query;
																		  _searchBar.text = query;
																		  [_tvShows[TRBTVShowModeSearch] removeAllObjects];
																		  [self startSearch];
																	  }
																  }];
		_observer2 = [[NSNotificationCenter defaultCenter] addObserverForName:TRBTVShowNotification
																	   object:nil
																		queue:[NSOperationQueue mainQueue]
																   usingBlock:^(NSNotification * note) {
																	   self.tabBarController.selectedViewController = self.splitViewController ? self.splitViewController : self.parentViewController;
																	   TRBTVShowEpisode * episode = [note userInfo][TRBTVShowEpisodeKey];
																	   if (episode)
																		   [self showTVShow:episode.season.series];
																   }];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
	[[TRBTvDBClient sharedInstance] updateSeriesRecordsWithCompletion:NULL];
	_searchBar.placeholder = @"Search TV Show";
	self.searchDisplayController.searchResultsTableView.rowHeight = 100.0;
	self.searchDisplayController.displaysSearchBarInNavigationBar = isIdiomPhone;
	self.navigationItem.rightBarButtonItem = _calendarButton;
	if (self.revealingViewController)
		_calendarNavController = [self.storyboard instantiateViewControllerWithIdentifier:@"TRBTVShowCalendarNavController"];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	self.revealingViewController.rightViewController = _calendarNavController;
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	if (_mode == TRBTVShowModeList && ![_tvShows[_mode] count])
		[self fetchList];
}

#pragma mark - Public Methods

- (void)showTVShow:(TRBTVShow *)tvShow {
	[self performSegueWithIdentifier:@"TRBShowTVShow" sender:tvShow];
}

#pragma mark - UISearchDisplayControllerDelegate Implementation

- (void)searchDisplayControllerWillBeginSearch:(UISearchDisplayController *)controller {
	_mode = TRBTVShowModeSearch;
	_searchBar.showsCancelButton = YES;
	self.navigationItem.rightBarButtonItem = nil;
}

- (void)searchDisplayControllerWillEndSearch:(UISearchDisplayController *)controller {
	_mode = TRBTVShowModeList;
	_searchBar.showsCancelButton = NO;
	self.navigationItem.rightBarButtonItem = _calendarButton;
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
		[_tvShows[TRBTVShowModeSearch] removeAllObjects];
		[self startSearch];
	}
	[searchBar resignFirstResponder];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_tvShows[_mode] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString * CellIdentifiers[TRBTVShowModeCount] = {@"TRBTVShowCell", @"TRBTVShowSearchCell"};
	TRBTVShowCell * cell = nil;
	id<TRBTVShow> tvShow = _tvShows[_mode][indexPath.row];
	if (_mode == TRBTVShowModeList)
		cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifiers[_mode] forIndexPath:indexPath];
	else {
		cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifiers[_mode]];
		if (!cell)
			cell = [[TRBTVShowCell alloc] initWithReuseIdentifier:CellIdentifiers[_mode]];
	}

	cell.titleLabel.text = tvShow.title;
	cell.overviewLabel.text = tvShow.overview;
	if ([tvShow.poster length]) {
		UIImage * poster = _images[tvShow.poster];
		cell.posterImageView.image = poster;
		if (!poster) {
			[[TRBTvDBClient sharedInstance] fetchSeriesBannerAtPath:tvShow.poster completion:^(UIImage *image, NSError *error) {
				LogCE(error, [error localizedDescription]);
				if (image) {
					_images[tvShow.poster] = image;
					[self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
				}
			}];
		}
	}

    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	NSString * title = nil;
	switch (_mode) {
		case TRBTVShowModeList:
			title = @"Tracked Shows";
			break;
		case TRBTVShowModeSearch:
			title = _currentQuery ? [NSString stringWithFormat:@"Results for: %@", _currentQuery] : nil;
			break;
		default:
			break;
	}
	return title;
}


- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return _mode == TRBTVShowModeList;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
		TRBTVShow * tvShow = _tvShows[TRBTVShowModeList][indexPath.row];
		[_tvShows[TRBTVShowModeList] removeObjectAtIndex:indexPath.row];
		[[TRBTVShowsStorage sharedInstance] removeTVShow:tvShow];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationLeft];
		[tableView setEditing:NO animated:YES];
//		[tableView reloadData];
    }
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if (_mode == TRBTVShowModeSearch)
		[self showTrackTVShowActionSheetForIndexPath:indexPath];
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
	if (_mode == TRBTVShowModeList) {
		[tableView selectRowAtIndexPath:indexPath animated:YES scrollPosition:UITableViewScrollPositionNone];
		[self showSearchLastEpisodeActionSheetForIndexPath:indexPath];
	}
}

#pragma mark - UIActionSheetDelegate Implementation

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
	NSIndexPath * indexPath = [self.searchDisplayController.searchResultsTableView indexPathForSelectedRow];
	[self.searchDisplayController.searchResultsTableView deselectRowAtIndexPath:indexPath animated:YES];
	if (buttonIndex == 0) {
		switch (actionSheet.tag) {
			case TRBTVShowModeList: {
				TRBTVShow * series = _tvShows[TRBTVShowModeList][indexPath.row];
				[self searchLastEpisodeOfSeries:series];
				break;
			} case TRBTVShowModeSearch: {
				TRBXMLElement * series = _tvShows[TRBTVShowModeSearch][indexPath.row];
				[self trackSeries:series];
			} default:
				break;
		}
	}
}

#pragma mark - IBActions

- (IBAction)showCalendar:(UIBarButtonItem *)sender {
	[self.tmTabBarController toggleRightController];
}

- (IBAction)settingsButtonPressed:(UIBarButtonItem *)sender {
	[self.tmTabBarController showSettingsFromBarButtonItem:sender];
}

#pragma mark - Segues

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
	if ([segue.identifier isEqualToString:@"TRBShowTVShow"]) {
		TRBTVShow * tvShow = nil;
		if ([sender isKindOfClass:[UITableViewCell class]]) {
			NSIndexPath * indexPath = [self.tableView indexPathForCell:sender];
			tvShow = _tvShows[TRBTVShowModeList][indexPath.row];
		} else if ([sender isKindOfClass:[TRBTVShow class]])
			tvShow = sender;
		TRBTVShowDetailsViewController * controller = segue.destinationViewController;
		[controller showTVShow:tvShow];
	}
}

- (IBAction)returnToTVShowList:(UIStoryboardSegue *)segue {
	if (isIdiomPad)
		[self dismissViewControllerAnimated:YES completion:NULL];
}

#pragma mark - Private Methods

- (void)fetchList {
	_mode = TRBTVShowModeList;
	[_tvShows[_mode] removeAllObjects];
	[[TRBTVShowsStorage sharedInstance] fetchAllTVShowsWithHandler:^(NSArray * results) {
		if (results)
			[_tvShows[TRBTVShowModeList] addObjectsFromArray:results];
		[self.tableView reloadData];
	}];
}

- (void)startSearch {
	_mode = TRBTVShowModeSearch;
	_searchBar.showsSearchResultsButton = NO;
	[[TRBTvDBClient sharedInstance] searchSeriesWithTitle:_currentQuery completion:^(TRBXMLElement * xml, NSError * error) {
		LogCE(error, [error localizedDescription]);
		if (xml) {
			NSArray * results = [xml elementsAtPath:@"Data.Series"];
			[_tvShows[TRBTVShowModeSearch] addObjectsFromArray:results];
		} else if (error)
			[[TKAlertCenter defaultCenter] postAlertWithMessage:[error localizedDescription]];
		[self.searchDisplayController.searchResultsTableView reloadData];
	}];
}

- (void)showSearchLastEpisodeActionSheetForIndexPath:(NSIndexPath *)indexPath {
	TRBTVShow * series = _tvShows[TRBTVShowModeList][indexPath.row];
	UIActionSheet * actionSheet = [[UIActionSheet alloc] initWithTitle:series.title
															  delegate:self
													 cancelButtonTitle:(isIdiomPhone ? @"Cancel": nil)
												destructiveButtonTitle:nil
													 otherButtonTitles:@"Find last episode torrent", nil];
	actionSheet.tag = TRBTVShowModeList;
	UITableViewCell * cell = [self.tableView cellForRowAtIndexPath:indexPath];
	CGRect slice, remainder;
	CGRectDivide(cell.bounds, &slice, &remainder, 50.0, CGRectMaxXEdge);
	[actionSheet showFromRect:slice inView:cell animated:YES];
}

- (void)showTrackTVShowActionSheetForIndexPath:(NSIndexPath *)indexPath {
	TRBXMLElement * series = _tvShows[TRBTVShowModeSearch][indexPath.row];
	UIActionSheet * actionSheet = [[UIActionSheet alloc] initWithTitle:series.title
															  delegate:self
													 cancelButtonTitle:(isIdiomPhone ? @"Cancel": nil)
												destructiveButtonTitle:nil
													 otherButtonTitles:@"Track TV Show", nil];
	actionSheet.delegate = self;
	actionSheet.tag = TRBTVShowModeSearch;
	UITableViewCell * cell = [self.searchDisplayController.searchResultsTableView cellForRowAtIndexPath:indexPath];
	[actionSheet showFromRect:cell.bounds inView:cell animated:YES];
}

- (void)trackSeries:(TRBXMLElement *)series {
	[[TRBTvDBClient sharedInstance] downloadAndSaveFullSeriesRecordWithID:series[@"Series.id"] overwrite:NO completion:^(TRBTVShow *tvShow, NSError *error) {
		LogCE(error, [error localizedDescription]);
		if (tvShow) {
			[_tvShows[TRBTVShowModeList] addObject:tvShow];
			if (_mode == TRBTVShowModeList)
				[self.tableView reloadData];
			[[TRBTvDBClient sharedInstance] scheduleEpisodeNotifications];
		} else if (error)
			[[TKAlertCenter defaultCenter] postAlertWithMessage:[error localizedDescription]];
	}];
}

- (void)searchLastEpisodeOfSeries:(TRBTVShow *)series {
	[[TRBTVShowsStorage sharedInstance] fetchPreviousEpisodeForTVShow:series andHandler:^(TRBTVShowEpisode * episode) {
		if (episode)
			[self searchOnTorrentz:[episode niceSearchString]];
		else
			[[TKAlertCenter defaultCenter] postAlertWithMessage:@"No previous episode"];
	}];
}

- (void)searchOnTorrentz:(NSString *)query {
	[self.presentingViewController dismissViewControllerAnimated:YES completion:NULL];
	[[NSNotificationCenter defaultCenter] postNotificationName:TRBTorrentzSearchNotification
														object:nil
													  userInfo:@{TRBSearchQueryKey : query}];
}

@end

@implementation TRBTVShowCell

- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
    if (self) {
		UILabel * label = [[UILabel alloc] init];
		[self.contentView addSubview:label];
		_titleLabel = label;
		_titleLabel.backgroundColor = [UIColor whiteColor];
		_titleLabel.opaque = YES;
		_titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
		_titleLabel.numberOfLines = 0;
		[_titleLabel setTranslatesAutoresizingMaskIntoConstraints:NO];
		label = [[UILabel alloc] init];
		[self.contentView addSubview:label];
		_overviewLabel = label;
		_overviewLabel.backgroundColor = [UIColor whiteColor];
		_overviewLabel.opaque = YES;
		_overviewLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
		_overviewLabel.numberOfLines = 0;
		_overviewLabel.lineBreakMode = NSLineBreakByWordWrapping;
		[_overviewLabel setTranslatesAutoresizingMaskIntoConstraints:NO];
		NSMutableArray * contraints = [NSMutableArray array];
		[contraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"|-5-[title]-5-|"
																				options:kNilOptions
																				metrics:nil
																				  views:@{@"title": _titleLabel}]];
		[contraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"|-5-[overview]-5-|"
																				options:kNilOptions
																				metrics:nil
																				  views:@{@"overview": _overviewLabel}]];
		[contraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-5-[title(24)]-8-[overview]-5-|"
																				options:kNilOptions
																				metrics:nil
																				  views:@{@"title": _titleLabel, @"overview": _overviewLabel}]];
		[self addConstraints:contraints];
    }
    return self;
}

@end
