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

#import "TRBTVShowSeasonViewController.h"
#import "TRBTVShowSeason.h"
#import "TRBTVShowSeason+TRBAdditions.h"
#import "TRBTVShowEpisode.h"
#import "TRBTVShowEpisode+TRBAddtions.h"
#import "TRBTvDBClient.h"
#import "TRBTabBarController.h"
#import "TRBTVShowEpisodeViewController.h"
#import "NSString+TRBUnits.h"

@interface TRBTVShowSeasonViewController ()<UIActionSheetDelegate>

@end

@implementation TRBTVShowSeasonViewController {
	TRBTVShowSeason * _season;
	NSArray * _episodes;
	NSNumberFormatter * _nf;
	UIPopoverController * _popover;
	NSIndexPath * _tappedIndexPath;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
		_nf = [NSNumberFormatter new];
		[_nf setMinimumIntegerDigits:2];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
	// Do any additional setup after loading the view.
}

- (void)showSeason:(TRBTVShowSeason *)season {
	_season = season;
	_episodes = [season orderedEpisodes];
	self.title = [season niceTitle];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_episodes count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString * CellIdentifier = @"TRBTVShowEpisodeCell";
    UITableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier
															forIndexPath:indexPath];
	TRBTVShowEpisode * episode = _episodes[indexPath.row];
	NSString * title = nil;
	if (![episode.seasonNumber integerValue])
		title = episode.episodeTitle;
	else
		title = [NSString stringWithFormat:@"%@ - %@", [_nf stringFromNumber:episode.episodeNumber], (episode.episodeTitle ? episode.episodeTitle : @"TBA")];
	cell.textLabel.text = title;
	cell.detailTextLabel.text = [NSString stringWithDate:[episode localizedAirDate]	dateOutputStyle:NSDateFormatterFullStyle andTimeOutputStyle:NSDateFormatterShortStyle];

	if (![episode.overview length])
		cell.accessoryType = UITableViewCellAccessoryNone;

    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
	TRBTVShowEpisode * episode = _episodes[indexPath.row];
	UIActionSheet * actionSheet = [[UIActionSheet alloc] initWithTitle:[episode niceTitle]
															  delegate:self
													 cancelButtonTitle:(isIdiomPhone ? @"Cancel": nil)
												destructiveButtonTitle:nil
													 otherButtonTitles:@"Search torrent", nil];
	_tappedIndexPath = indexPath;
	UITableViewCell * cell = [tableView cellForRowAtIndexPath:indexPath];
	[actionSheet showFromRect:cell.bounds inView:cell animated:YES];
}

#pragma mark - UIActionSheetDelegate Implementation

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
	if (buttonIndex == 0) {
		TRBTVShowEpisode * episode = _episodes[_tappedIndexPath.row];
		[self searchOnTorrentz:[episode niceSearchString]];
	}
}

#pragma mark - Segues

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
	if ([segue.identifier isEqualToString:@"TRBShowEpisode"]) {
		NSIndexPath * indexPath = [self.tableView indexPathForCell:sender];
		TRBTVShowEpisode * episode = _episodes[indexPath.row];
		TRBTVShowEpisodeViewController * controller = segue.destinationViewController;
		[controller showEpisode:episode];
	}
}

#pragma mark - Private Methods

- (void)searchOnTorrentz:(NSString *)query {
	[[NSNotificationCenter defaultCenter] postNotificationName:TRBTorrentzSearchNotification
														object:nil
													  userInfo:@{TRBSearchQueryKey : query}];
}

@end
