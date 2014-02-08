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

#import "TRBTVShowDetailsViewController.h"
#import "TRBTVShow.h"
#import "TRBTVShow+TRBAdditions.h"
#import "TRBTVShowSeason.h"
#import "TRBTVShowSeason+TRBAdditions.h"
#import "TRBTVShowEpisode.h"
#import "TRBTVShowEpisode+TRBAddtions.h"
#import "TRBTVShowBanner.h"
#import "TRBTVShowBanner+TRBAdditions.h"
#import "TRBTvDBClient.h"
#import "TRBTVShowsStorage.h"
#import "TRBTabBarController.h"
#import "TRBTVShowSeasonViewController.h"
#import "TRBFlipView.h"
#import "NSString+TRBUnits.h"

typedef NS_ENUM(NSUInteger, TRBTVShowDetailsSection) {
	TRBTVShowDetailsSectionNextEpisode = 0,
	TRBTVShowDetailsSectionPreviousEpisode,
	TRBTVShowDetailsSectionSeasons,

	TRBTVShowDetailsSectionCount
};

@interface TRBTVShowDetailsViewController ()<UIActionSheetDelegate>
@property (weak, nonatomic) IBOutlet UIImageView * fanartImageView;
@property (weak, nonatomic) IBOutlet UILabel * airDayLabel;
@property (weak, nonatomic) IBOutlet UILabel * airTimeLabel;
@property (weak, nonatomic) IBOutlet UILabel * networkLabel;
@property (weak, nonatomic) IBOutlet UILabel * genreLabel;
@property (weak, nonatomic) IBOutlet UILabel * statusLabel;
@property (weak, nonatomic) IBOutlet UITableView * tableView;
@property (weak, nonatomic) IBOutlet UITextView * overviewTextView;
@property (weak, nonatomic) IBOutlet TRBFlipView *flipView;
@end

@implementation TRBTVShowDetailsViewController {
	TRBTVShow * _tvShow;
	TRBTVShowBanner * _banner;
	NSArray * _seasons;
	TRBTVShowEpisode * _next;
	TRBTVShowEpisode * _previous;
}

//- (id)initWithCoder:(NSCoder *)aDecoder {
//    self = [super initWithCoder:aDecoder];
//    if (self) {
//    }
//    return self;
//}

- (void)viewDidLoad {
    [super viewDidLoad];
	if (!_fanartImageView.image) {
		_airDayLabel.text = _tvShow.airsDayOfWeek;
		_airTimeLabel.text = _tvShow.airsTime;
		_networkLabel.text = _tvShow.network;
		_genreLabel.text = _tvShow.genre;
		_statusLabel.text = _tvShow.status;
	}
	_overviewTextView.text = _tvShow.overview;
	[_tableView setContentInset:UIEdgeInsetsMake(0.0, 0.0, 44.0, 0.0)];
}

#pragma mark - Public Methods

- (void)showTVShow:(TRBTVShow *)tvShow {
	_tvShow = tvShow;
	_seasons = [_tvShow orderedSeasons];
	self.title = _tvShow.title;
	[[TRBTVShowsStorage sharedInstance] fetchTVShowBannerWithType:TRBTVShowBannerTypeFanart forTVShow:_tvShow mustHaveColors:NO andHandler:^(NSArray *banners) {
		if ([banners count]) {
			NSUInteger randomIndex = arc4random() % [banners count];
			_banner = banners[randomIndex];
			[[TRBTvDBClient sharedInstance] fetchSeriesBannerAtPath:_banner.bannerPath completion:^(UIImage *image, NSError *error) {
				LogCE(error != nil, [error localizedDescription]);
				_fanartImageView.image = image;
				NSDictionary * stringAttr = @{
								  NSForegroundColorAttributeName: [UIColor whiteColor],
									  NSStrokeColorAttributeName: [UIColor blackColor],
									  NSStrokeWidthAttributeName: @(-3.0)
								  };
				if (_tvShow.airsDayOfWeek)
					_airDayLabel.attributedText = [[NSAttributedString alloc] initWithString:_tvShow.airsDayOfWeek attributes:stringAttr];
				if (_tvShow.airsTime)
					_airTimeLabel.attributedText = [[NSAttributedString alloc] initWithString:_tvShow.airsTime attributes:stringAttr];
				if (_tvShow.network)
					_networkLabel.attributedText = [[NSAttributedString alloc] initWithString:_tvShow.network attributes:stringAttr];
				if (_tvShow.genre)
					_genreLabel.attributedText = [[NSAttributedString alloc] initWithString:_tvShow.genre attributes:stringAttr];
				if (_tvShow.status)
					_statusLabel.attributedText = [[NSAttributedString alloc] initWithString:_tvShow.status attributes:stringAttr];
			}];
		}
	}];
	[[TRBTVShowsStorage sharedInstance] fetchNextEpisodeForTVShow:_tvShow andHandler:^(TRBTVShowEpisode *episode) {
		_next = episode;
		if (_next)
			[_tableView reloadSections:[NSIndexSet indexSetWithIndex:TRBTVShowDetailsSectionNextEpisode] withRowAnimation:UITableViewRowAnimationAutomatic];
	}];
	[[TRBTVShowsStorage sharedInstance] fetchPreviousEpisodeForTVShow:_tvShow andHandler:^(TRBTVShowEpisode *episode) {
		_previous = episode;
		if (_previous)
			[_tableView reloadSections:[NSIndexSet indexSetWithIndex:TRBTVShowDetailsSectionPreviousEpisode] withRowAnimation:UITableViewRowAnimationAutomatic];
	}];
	[self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return TRBTVShowDetailsSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	NSInteger result = 0;
	switch (section) {
		case TRBTVShowDetailsSectionNextEpisode:
			result = _next ? 1 : 0;
			break;
		case TRBTVShowDetailsSectionPreviousEpisode:
			result = _previous ? 1 : 0;
			break;
		case TRBTVShowDetailsSectionSeasons:
			result = [_seasons count];
			break;
		default:
			break;
	}
    return result;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString * CellIdentifier[TRBTVShowDetailsSectionCount] = {@"TRBTVShowEpisodeCell", @"TRBTVShowEpisodeCell", @"TRBTVShowSeasonCell"};
    UITableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier[indexPath.section] forIndexPath:indexPath];

	switch (indexPath.section) {
		case TRBTVShowDetailsSectionNextEpisode: {
			cell.textLabel.text = [_next niceTitle];
			cell.detailTextLabel.text = [NSString stringWithDate:[_next localizedAirDate] dateOutputStyle:NSDateFormatterFullStyle andTimeOutputStyle:NSDateFormatterShortStyle];
			break;
		} case TRBTVShowDetailsSectionPreviousEpisode: {
			cell.textLabel.text = [_previous niceTitle];
			cell.detailTextLabel.text = [NSString stringWithDate:[_previous localizedAirDate] dateOutputStyle:NSDateFormatterFullStyle andTimeOutputStyle:NSDateFormatterShortStyle];
			break;
		} case TRBTVShowDetailsSectionSeasons: {
			TRBTVShowSeason * season = _seasons[indexPath.row];
			cell.textLabel.text = [season niceTitle];
			break;
		} default:
			break;
	}

    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	NSString * result = nil;
	switch (section) {
		case TRBTVShowDetailsSectionNextEpisode:
			result = _next ? @"Next Episode" : nil;
			break;
		case TRBTVShowDetailsSectionPreviousEpisode:
			result = _previous ? @"Previous Episode" : nil;
			break;
		case TRBTVShowDetailsSectionSeasons:
			result = @"Seasons";
			break;
		default:
			break;
	}
    return result;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
	NSString * title = nil;
	switch (indexPath.section) {
		case TRBTVShowDetailsSectionNextEpisode:
			title = [_next niceTitle];
			break;
		case TRBTVShowDetailsSectionPreviousEpisode:
			title = [_previous niceTitle];
			break;
		case TRBTVShowDetailsSectionSeasons: {
			TRBTVShowSeason * season = _seasons[indexPath.row];
			title = [season.number integerValue] ? [season niceTitle] : nil;
			break;
		} default:
			break;
	}
	if (title) {
		[tableView selectRowAtIndexPath:indexPath animated:YES scrollPosition:UITableViewScrollPositionNone];
		UIActionSheet * actionSheet = [[UIActionSheet alloc] initWithTitle:title
																  delegate:self
														 cancelButtonTitle:(isIdiomPhone ? @"Cancel": nil)
													destructiveButtonTitle:nil
														 otherButtonTitles:@"Search torrent", nil];
		actionSheet.tag = indexPath.section;
		UITableViewCell * cell = [tableView cellForRowAtIndexPath:indexPath];
		CGRect slice, remainder;
		CGRectDivide(cell.bounds, &slice, &remainder, 50.0, CGRectMaxXEdge);
		[actionSheet showFromRect:slice inView:cell animated:YES];
	} else
		[tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - UIActionSheetDelegate Implementation

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
	NSIndexPath * indexPath = [self.tableView indexPathForSelectedRow];
	[self.tableView deselectRowAtIndexPath:indexPath animated:YES];
	if (buttonIndex == 0) {
		NSString * query = nil;
		switch (indexPath.section) {
			case TRBTVShowDetailsSectionNextEpisode:
				query = [_next niceSearchString];
				break;
			case TRBTVShowDetailsSectionPreviousEpisode:
				query = [_previous niceSearchString];
				break;
			case TRBTVShowDetailsSectionSeasons:
				query = [((TRBTVShowSeason *)_seasons[indexPath.row]) niceSearchString];
				break;
			default:
				query = @"";
				break;
		}
		[self searchOnTorrentz:query];
	}
}

#pragma mark - Segues

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
	if ([segue.identifier isEqualToString:@"TRBShowSeason"]) {
		TRBTVShowSeasonViewController * controller = segue.destinationViewController;
		NSIndexPath * indexPath = [self.tableView indexPathForCell:sender];
		[controller showSeason:_seasons[indexPath.row]];
	}
}

#pragma mark - Private Methods

- (void)searchOnTorrentz:(NSString *)query {
	[self.presentingViewController dismissViewControllerAnimated:YES completion:NULL];
	[[NSNotificationCenter defaultCenter] postNotificationName:TRBTorrentzSearchNotification
														object:nil
													  userInfo:@{TRBSearchQueryKey : query}];
}

@end
