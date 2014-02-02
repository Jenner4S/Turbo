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

#import "TRBMovieReviewsViewController.h"
#import "TRBRottenTomatoesClient.h"
#import "TRBMovie.h"
#import "TRBTabBarController.h"
#import "TKAlertCenter.h"

#define kPageLimit 50

@interface TRBMovieReviewsViewController ()

@end

@implementation TRBMovieReviewsViewController {
	NSMutableArray * _reviews;
	NSUInteger _page;
	TRBMovie * _movie;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        _reviews = [NSMutableArray new];
		_page = 1;
    }
    return self;
}

#pragma mark - Public Methods

- (void)showReviewsForMovie:(TRBMovie *)movie {
	_movie = movie;
	_page = 1;
	[_reviews removeAllObjects];
	[self fetchReviews];
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
	UITableView * tableView = (UITableView *)scrollView;
	NSInteger count = [_reviews count];
	if (count && ((count % kPageLimit) == 0)) {
		CGFloat actualPosition = scrollView.contentOffset.y;
		CGFloat contentHeight = scrollView.contentSize.height - (tableView.rowHeight * 6.0);
		if (actualPosition >= contentHeight) {
			_page++;
			[self fetchReviews];
		}
	}
}


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	NSInteger result = [_reviews count];
	if (result && ((result % kPageLimit) == 0))
		result++;
    return result;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString * CellIdentifier = @"TRBReviewCell";

	UITableViewCell * cell = nil;

	if (indexPath.row < [_reviews count]) {
		NSDictionary * review = _reviews[indexPath.row];
		TRBMovieReviewCell * reviewCell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
		reviewCell.critic.text = review[@"critic"];
		reviewCell.publication.text = review[@"publication"];
		reviewCell.quote.text = review[@"quote"];
		NSString * freshness = review[@"freshness"];
		UIImage * freshnessImage = [UIImage imageNamed:freshness];
		reviewCell.freshness.image = freshnessImage;
		cell = reviewCell;
	}

    return cell;
}


#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row < [_reviews count]) {
		NSDictionary * review = _reviews[indexPath.row];
		UIViewController * controller = [self.tmTabBarController newWebViewController];
		controller.title = @"Review";
		UIWebView * webView = (UIWebView *)controller.view;
		NSURL * url = [NSURL URLWithString:review[@"links"][@"review"]];
		NSURLRequest * request = [NSURLRequest requestWithURL:url];
		[webView loadRequest:request];
		[self.navigationController pushViewController:controller animated:YES];
	}
}

#pragma mark - Segues

- (IBAction)exitWebView:(UIStoryboardSegue *)segue {
	if (isIdiomPad)
		[self dismissViewControllerAnimated:YES completion:NULL];
}

#pragma mark - Private Methods

- (void)fetchReviews {
	[[TRBRottenTomatoesClient sharedInstance] fetchMovieReviewsForID:_movie.rtID page:_page withHandler:^(NSDictionary *json, NSError *error) {
		LogCE(error, [error localizedDescription]);
		if (json) {
			[_reviews addObjectsFromArray:json[@"reviews"]];
			[self.tableView reloadData];
		} else if (error)
			[[TKAlertCenter defaultCenter] postAlertWithMessage:[error localizedDescription]];
	}];
}

@end

@implementation TRBMovieReviewCell

- (void)prepareForReuse {
	_critic.text = nil;
	_publication.text = nil;
	_quote.text = nil;
	_freshness.image = nil;
	_freshness.highlightedImage = nil;
}

@end
