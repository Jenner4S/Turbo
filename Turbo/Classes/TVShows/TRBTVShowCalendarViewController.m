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

#import "TRBTVShowCalendarViewController.h"
#import "TRBTVShowsStorage.h"
#import "TRBTVShow.h"
#import "TRBTVShow+TRBAdditions.h"
#import "TRBTVShowSeason.h"
#import "TRBTVShowSeason+TRBAdditions.h"
#import "TRBTVShowEpisode.h"
#import "TRBTVShowEpisode+TRBAddtions.h"
#import "TRBTabBarController.h"
#import "KalDate.h"
#import "NSDate+TKCategory.h"

@interface TRBTVShowCalendarViewController ()<UIActionSheetDelegate>

@end

@implementation TRBTVShowCalendarViewController {
	NSMutableArray * _episodes;
	NSMutableArray * _dates;
	NSMutableArray * _selected;
}

- (void)viewDidLoad {
    [super viewDidLoad];
	_episodes = [NSMutableArray array];
	_dates = [NSMutableArray array];
	_selected = [NSMutableArray array];
	self.calendarView.tableView.rowHeight = 44.0;
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	self.dataSource = self;
	self.delegate = self;
	[self.calendarView.tableView reloadData];
}

#pragma mark - KalDataSource

- (void)presentingDatesFrom:(NSDate *)fromDate to:(NSDate *)toDate delegate:(id<KalDataSourceCallbacks>)delegate {
	NSDate * fromDate1 = [fromDate dateByAddingDays:-1];
	NSDate * toDate1 = [toDate dateByAddingDays:1];
	[_dates removeAllObjects];
	[_episodes removeAllObjects];
	[[TRBTVShowsStorage sharedInstance] fetchEpisodesAiringFromDate:fromDate1 toDate:toDate1 withHandler:^(NSArray *results) {
		if ([results count]) {
			for (TRBTVShowEpisode * episode in results) {
				NSDate * localDate = [episode localizedAirDate];
				if ([localDate timeIntervalSinceReferenceDate] >= [fromDate timeIntervalSinceReferenceDate] &&
					[localDate timeIntervalSinceReferenceDate] <= [toDate timeIntervalSinceReferenceDate]) {
					[_dates addObject:localDate];
					[_episodes addObject:episode];
				}
			}
		}
		[delegate loadedDataSource:self];
		NSDate * today = [NSDate date];
		if ([fromDate compare:today] == NSOrderedAscending && [toDate compare:today] == NSOrderedDescending)
			[self.calendarView selectDate:[KalDate dateFromNSDate:today]];
	}];
}

- (NSArray *)markedDatesFrom:(NSDate *)fromDate to:(NSDate *)toDate {
	return _dates;
}

- (void)loadItemsFromDate:(NSDate *)fromDate toDate:(NSDate *)toDate {
	[_selected removeAllObjects];
	for (TRBTVShowEpisode * episode in _episodes) {
		NSDate * localDate = [episode localizedAirDate];
		if ([localDate timeIntervalSinceReferenceDate] >= [fromDate timeIntervalSinceReferenceDate] &&
			[localDate timeIntervalSinceReferenceDate] <= [toDate timeIntervalSinceReferenceDate]) {
			[_selected addObject:episode];
		}
	}
}

- (void)removeAllItems {
	[_selected removeAllObjects];
}

#pragma mark - UITableViewDataSource

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *identifier = @"CalCell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];

	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];

	TRBTVShowEpisode * episode = _selected[indexPath.row];
	cell.textLabel.text = episode.season.series.title;
	cell.detailTextLabel.text = [episode niceTitle];

	return cell;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [_selected count];
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	TRBTVShowEpisode * episode = _selected[indexPath.row];
	NSString * title = [episode niceTitle];
	if (title) {
		UIActionSheet * actionSheet = [[UIActionSheet alloc] initWithTitle:title
																  delegate:self
														 cancelButtonTitle:(isIdiomPhone ? @"Cancel": nil)
													destructiveButtonTitle:nil
														 otherButtonTitles:@"Search torrent", nil];
		UITableViewCell * cell = [tableView cellForRowAtIndexPath:indexPath];
		[actionSheet showFromRect:cell.bounds inView:cell animated:YES];
	} else
		[tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - UIActionSheetDelegate Implementation

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
	NSIndexPath * indexPath = [self.calendarView.tableView indexPathForSelectedRow];
	[self.calendarView.tableView deselectRowAtIndexPath:indexPath animated:YES];
	if (buttonIndex == 0) {
		TRBTVShowEpisode * episode = _selected[indexPath.row];
		NSString * query = [episode niceSearchString];
		[self searchOnTorrentz:query];
	}
}

#pragma mark - Private Methods

- (void)searchOnTorrentz:(NSString *)query {
	[[NSNotificationCenter defaultCenter] postNotificationName:TRBTorrentzSearchNotification
														object:nil
													  userInfo:@{TRBSearchQueryKey : query}];
}

@end
