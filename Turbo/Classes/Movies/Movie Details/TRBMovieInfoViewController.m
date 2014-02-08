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

#import "TRBMovieInfoViewController.h"
#import "TRBRottenTomatoesClient.h"
#import "TRBTMDbClient.h"
#import "TRBMovieCastViewController.h"
#import "TRBMovieTrailersViewController.h"
#import "TRBMovieImagesViewController.h"
#import "TRBMovieReviewsViewController.h"
#import "TRBMovie.h"
#import "TRBTabBarController.h"
#import "TKAlertCenter.h"

@interface TRBMovieInfoViewController ()
@property (weak, nonatomic) IBOutlet UILabel *criticsRatingLabel;
@property (weak, nonatomic) IBOutlet UILabel *audienceRatingLabel;
@property (weak, nonatomic) IBOutlet UILabel *genresLabel;
@property (weak, nonatomic) IBOutlet UILabel *runtimeLabel;
@property (weak, nonatomic) IBOutlet UITextView *synopsisTextView;
@property (weak, nonatomic) IBOutlet UILabel *studioLabel;
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UIImageView *criticsIcon;
@property (weak, nonatomic) IBOutlet UIImageView *audienceIcon;
@property (weak, nonatomic) IBOutlet UILabel *releaseDateLabel;
@property (weak, nonatomic) IBOutlet UIImageView *backdrop;
@end

@implementation TRBMovieInfoViewController {
	TRBMovie * _movieInfo;
	__weak IBOutlet UIBarButtonItem *_actionButton;
}

- (void)viewDidLoad {
    [super viewDidLoad];
	self.navigationController.navigationBar.translucent = YES;
	[self displayMovie];
}

#pragma mark - Public Methods

- (void)showMovie:(TRBMovie *)movie {
	_movieInfo = movie;
	if (self.isViewLoaded)
		[self displayMovie];
	[self fetchRTMovieInfo];
	[self fetchTMDbMovieInfo];
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - UIActionSheetDelegate Implementation

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
	NSIndexPath * selected = [self.tableView indexPathForSelectedRow];
	[self.tableView deselectRowAtIndexPath:selected animated:YES];
	switch (buttonIndex) {
		case 0: {
			// fetch trailers
			TRBMovieTrailersViewController * controller = [self.storyboard instantiateViewControllerWithIdentifier:@"TRBMovieTrailersViewController"];
			[controller showTrailersForMovie:_movieInfo];
			[self.navigationController pushViewController:controller animated:YES];
			break;
		} case 1: {
			// fetch images
			TRBMovieImagesViewController * controller = [self.storyboard instantiateViewControllerWithIdentifier:@"TRBMovieImagesViewController"];
			[controller showImagesForMovie:_movieInfo];
			[self.navigationController pushViewController:controller animated:YES];
			break;
		} case 2: {
			// show imdb page
			NSString * title = _movieInfo.imdbID;
			BOOL webOnly = [[NSUserDefaults standardUserDefaults] boolForKey:TRBIMDbSearchWebOnlyKey];
			if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"imdb:///"]] && !webOnly) {
				[[UIApplication sharedApplication] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"imdb:///title/%@", title]]];
			} else {
				UIViewController * controller = [self.tmTabBarController newWebViewController];
				controller.title = @"IMDb";
				UIWebView * webView = (UIWebView *)controller.view;
				NSURL * url = [NSURL URLWithString:[NSString stringWithFormat:@"http://www.imdb.com/title/%@", title]];
				NSURLRequest * request = [NSURLRequest requestWithURL:url];
				[webView loadRequest:request];
				[self.navigationController pushViewController:controller animated:YES];
			}
			break;
		} default:
			break;
	}
}

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex {
	[_actionButton setEnabled:YES];
}

#pragma mark - IBActions

- (IBAction)actionButtonPressed:(UIBarButtonItem *)sender {
	if ([sender isEnabled]) {
		UIActionSheet * actionSheet = [[UIActionSheet alloc] initWithTitle:_movieInfo.title
																  delegate:self
														 cancelButtonTitle:(isIdiomPhone ? @"Cancel": nil)
													destructiveButtonTitle:nil
														 otherButtonTitles:@"Trailers", @"Images", @"IMDb Page", nil];
		actionSheet.delegate = self;
		[actionSheet showFromBarButtonItem:sender animated:YES];
	}
	[sender setEnabled:![sender isEnabled]];
}

#pragma mark - Segues

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
	if ([segue.identifier isEqualToString:@"TRBShowCast"]) {
		TRBCastSource source = TRBCastSourceTMDb;
		TRBMovieCastViewController * controller = (TRBMovieCastViewController *)segue.destinationViewController;
		if (!_movieInfo.tmdbID)
			source = TRBCastSourceRT;
		[controller showCastForMovie:_movieInfo andSource:source];
	} else if ([segue.identifier isEqualToString:@"TRBShowReviews"]) {
		TRBMovieReviewsViewController * controller = (TRBMovieReviewsViewController *)segue.destinationViewController;
		[controller showReviewsForMovie:_movieInfo];
	}
}

- (IBAction)exitWebView:(UIStoryboardSegue *)segue {
	if (isIdiomPad)
		[self dismissViewControllerAnimated:YES completion:NULL];
}

#pragma mark - Private Methods

- (void)displayMovie {
	self.title = _movieInfo.title;
	_titleLabel.text = _movieInfo.title;

	if ([_movieInfo.criticsRating length]) {
		_criticsRatingLabel.text = [NSString stringWithFormat:@"%@%%", _movieInfo.criticsScore];
		_criticsIcon.image = [UIImage imageNamed:_movieInfo.criticsRating];
	} else
		_criticsRatingLabel.text = @"- %";

	if ([_movieInfo.audienceRating length]) {
		_audienceRatingLabel.text = [NSString stringWithFormat:@"%@%%", _movieInfo.audienceScore];
		_audienceIcon.image = [UIImage imageNamed:_movieInfo.audienceRating];
	} else
		_audienceRatingLabel.text = @"- %";

	_genresLabel.text = _movieInfo.genres;

	NSNumber * runtime = _movieInfo.runtime;
	if ([runtime isKindOfClass:[NSNumber class]])
		_runtimeLabel.text = [NSString stringWithFormat:@"%@'", runtime];

	_synopsisTextView.text = _movieInfo.synopsis;

	_studioLabel.text = _movieInfo.studio;
	_releaseDateLabel.text = _movieInfo.releaseDate;

}

- (void)fetchRTMovieInfo {
	[[TRBRottenTomatoesClient sharedInstance] fetchMovieInfoForID:_movieInfo.rtID withHandler:^(NSDictionary *json, NSError *error) {
		LogCE(error != nil, [error localizedDescription]);
		if (json) {
			[_movieInfo updateWithRTInfo:json];
			[self displayMovie];
		} else if (error)
			[[TKAlertCenter defaultCenter] postAlertWithMessage:[error localizedDescription]];
	}];
}

- (void)fetchTMDbMovieInfo {
	[[TRBTMDbClient sharedInstance] findMovieWithRTMovie:_movieInfo completion:^(NSDictionary *json, NSError *error) {
		LogCE(error != nil, [error localizedDescription]);
		if (json) {
			[_movieInfo updateWithTMDbInfo:json];
			[self displayMovie];
			[self fetchBackdrop];
		} else
			_backdrop.image = _movieInfo.posterImage;
	}];
}

- (void)fetchBackdrop {
    NSString * backdropPath = _movieInfo.backdropPath;
	if ([backdropPath isKindOfClass:[NSString class]] && [backdropPath length]) {
		TRBTMDbBackdropSize size = TRBTMDbBackdropSizeW300;
		if ([UIScreen mainScreen].scale > 1.0)
			size = TRBTMDbBackdropSizeW780;
		[[TRBTMDbClient sharedInstance] fetchBackdrop:backdropPath withSize:size completion:^(UIImage *image, NSError * error) {
			LogCE(error != nil, [error localizedDescription]);
			if (!image)
				image =  _movieInfo.posterImage;
			_backdrop.image = image;
		}];
	} else
		_backdrop.image = _movieInfo.posterImage;
}

@end
