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

#import "TRBMovieTrailersViewController.h"
#import "TRBTMDbClient.h"
#import "TRBWebNavigationController.h"
#import "TRBMovie.h"
#import "TRBTabBarController.h"
#import "TRBHTTPSession.h"

typedef NS_ENUM(NSUInteger, TRBTrailerSection) {
	TRBTrailerSectionYT = 0,
	TRBTrailerSectionQT,

	TRBTrailerSectionCount
};

@interface TRBMovieTrailersViewController ()

@end

@implementation TRBMovieTrailersViewController {
	NSMutableArray * _trailers;
	NSMutableDictionary * _images;
	TRBHTTPSession * _session;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
	self = [super initWithCoder:aDecoder];
	if (self) {
		_trailers = [[NSMutableArray alloc] initWithCapacity:TRBTrailerSectionCount];
		_images = [NSMutableDictionary new];
		_session = [[TRBHTTPSession alloc] initWithConfiguration:nil];
		_session.acceptedHTTPStatusCodes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(200, 100)];
	}
	return self;
}

- (void)dealloc {
    [_session invalidateAndCancel];
}

//- (void)viewDidLoad {
//    [super viewDidLoad];
//}

- (BOOL)shouldAutorotate {
	return YES;
}

- (NSUInteger)supportedInterfaceOrientations {
	NSUInteger result = UIInterfaceOrientationMaskPortrait;
	if (isIdiomPad)
		result |= UIInterfaceOrientationMaskLandscape;
	return result;
}

#pragma mark - Public Methods

- (void)showTrailersForMovie:(TRBMovie *)movie {
	[[TRBTMDbClient sharedInstance] fetchMovieTrailersWithID:movie.tmdbID completion:^(NSDictionary *json, NSError *error) {
		_trailers[TRBTrailerSectionYT] = json[@"youtube"];
		_trailers[TRBTrailerSectionQT] = json[@"quicktime"];
		[self.tableView reloadData];
	}];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [_trailers count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_trailers[section] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString * YTCellIdentifier = @"TRBYTTrailerCell";
	static NSString * QTCellIdentifier = @"TRBQTTrailerCell";

    TRBMovieTrailerCell * cell = [tableView dequeueReusableCellWithIdentifier:(indexPath.section == TRBTrailerSectionYT ? YTCellIdentifier : QTCellIdentifier) forIndexPath:indexPath];

    NSDictionary * trailer = _trailers[indexPath.section][indexPath.row];
	cell.title.text = trailer[@"name"];

	UIImage * thumbnail = nil;

	switch (indexPath.section) {
		case TRBTrailerSectionYT: {
			cell.quality.text = trailer[@"size"];
			thumbnail = _images[trailer[@"source"]];
			if (!thumbnail)
				[self fetchYoutubeThumbnailForTrailer:trailer atIndexPath:indexPath];
			break;
		} case TRBTrailerSectionQT: {
			cell.quality.text = [trailer[@"sources"] lastObject][@"size"];
			thumbnail = [UIImage imageNamed:@"quicktime"];
			break;
		}
		default:
			break;
	}

	cell.thumbnail.image = thumbnail;

    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	NSString * result = nil;
	if ([_trailers[section] count]) {
		switch (section) {
			case TRBTrailerSectionYT:
				result = @"YouTube";
				break;
			case TRBTrailerSectionQT:
				result = @"QuickTime";
				break;
			default:
				break;
		}
	}
	return result;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	NSDictionary * trailer = _trailers[indexPath.section][indexPath.row];

	NSURLRequest * request = nil;
	switch (indexPath.section) {
		case TRBTrailerSectionYT:
			request = [NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://www.youtube.com/embed/%@", trailer[@"source"]]]];
			break;
		case TRBTrailerSectionQT:
			request = [NSURLRequest requestWithURL:[NSURL URLWithString:[trailer[@"sources"] lastObject][@"source"]]];
			break;
		default:
			break;
	}

	UIViewController * controller = [self.tmTabBarController newWebViewController];
	controller.title = trailer[@"name"];
	UIWebView * webView = (UIWebView *)controller.view;
	[webView setScalesPageToFit:NO];
	webView.mediaPlaybackRequiresUserAction = NO;
	[webView loadRequest:request];
	[self.navigationController pushViewController:controller animated:YES];
}

#pragma mark - Segues

- (IBAction)exitWebView:(UIStoryboardSegue *)segue {
	if (isIdiomPad)
		[self dismissViewControllerAnimated:YES completion:NULL];
}

#pragma mark - Private Methods

- (void)fetchYoutubeThumbnailForTrailer:(NSDictionary *)trailer atIndexPath:(NSIndexPath *)indexPath {
	NSString * quality = [UIScreen mainScreen].scale > 1.0 ? @"mqdefault.jpg" : @"default.jpg";
	NSString * url = [NSString stringWithFormat:@"http://img.youtube.com/vi/%@/%@", trailer[@"source"], quality];
	[_session GET:url parameters:nil builder:nil parser:nil completion:^(id data, NSURLResponse *response, NSError *error) {
		if (!error) {
			UIImage * image = [UIImage imageWithData:data scale:[UIScreen mainScreen].scale];
			_images[trailer[@"source"]] = image;
			[self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
		}
		LogCE(error, [error localizedDescription]);
	}];
}

@end

@implementation TRBMovieTrailerCell

- (void)prepareForReuse {
	_thumbnail.image = nil;
	_thumbnail.highlightedImage = nil;
}

@end
