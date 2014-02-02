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

#import "TRBLibraryListViewController.h"
#import "TRBLibraryManager.h"
#import "TRBMovie.h"
#import "TRBLibraryMovieDetailsViewController.h"
#import "TRBLibraryFilterViewController.h"

#define MOVIES_LIMIT 50

typedef NS_ENUM(NSUInteger, TRBLibraryAppendPosition) {
	TRBLibraryAppendPositionTop = 0,
	TRBLibraryAppendPositionBottom
};

@interface TRBLibraryListViewController ()<UISearchBarDelegate>

@end

@implementation TRBLibraryListViewController {
	TRBLibraryManager * _libraryManager;
	NSMutableArray * _movies;
	NSInteger * _offsetTop;
	NSInteger * _offsetBottom;
	NSUInteger * _total;

	NSMutableArray * _list;
	NSInteger _listOffsetTop;
	NSInteger _listOffsetBottom;
	NSUInteger _listTotal;

	NSMutableArray * _searched;
	NSInteger _searchOffsetTop;
	NSInteger _searchOffsetBottom;
	NSUInteger _searchTotal;

	BOOL _fetching;
	CGFloat _previousContentPosition;
	UISearchBar * _searchBar;

	NSArray * _defaultRightBarButtonItems;

	TRBLibraryFilterName _currentFilter;
	NSDictionary * _filters;
	NSString * _filterDescription;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
		NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
		_libraryManager = [TRBLibraryManager sharedManager];
		_libraryManager.host = [defaults objectForKey:TRBSynologyHostKey];
		_libraryManager.port = [[defaults objectForKey:TRBSynologyPortKey] integerValue];
		_list = [NSMutableArray arrayWithCapacity:MOVIES_LIMIT];
		_searched = [NSMutableArray arrayWithCapacity:MOVIES_LIMIT];
		_movies = _list;
		_listOffsetTop = _searchOffsetTop = -MOVIES_LIMIT;
		_listOffsetBottom = _searchOffsetBottom = 0;
		_listTotal = _searchTotal = 0;
		_offsetTop = &_listOffsetTop;
		_offsetBottom = &_listOffsetBottom;
		_total = &_listTotal;
		_previousContentPosition = -64.0;
		_filterDescription = nil;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
	self.title = @"Movie Library";
	_searchBar = [[UISearchBar alloc] init];
	_searchBar.barStyle = UIBarStyleDefault;
	_searchBar.delegate = self;
	_searchBar.placeholder = @"Search Movie Library";
	self.navigationItem.titleView = _searchBar;
	void(^fetchMoviesBlock)(NSError * error) = ^(NSError * error) {
		if (!error)
			[self fetchMoviesWithAppendPosition:TRBLibraryAppendPositionBottom];
	};
	if (!_libraryManager.isAuthenticated)
		[_libraryManager startAuthenticationCompletion:fetchMoviesBlock];
	else
		fetchMoviesBlock(nil);
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	self.navigationItem.prompt = _filterDescription;
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	self.revealingViewController.rightViewController = nil;
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	self.navigationItem.prompt = nil;
}

#pragma mark - UISearchBarDelegate Implementation

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
	[searchBar resignFirstResponder];
	[_searched removeAllObjects];
	_searchOffsetTop = -MOVIES_LIMIT;
	_searchOffsetBottom = 0;
	_searchTotal = 0;
	[self searchMovieWithAppendPosition:TRBLibraryAppendPositionBottom];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
	[searchBar resignFirstResponder];
}


#pragma mark - UICollectionViewDataSource Implementation

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
	return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
	return [_movies count];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
	TRBMovieCollectionCell * cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"TRBMovieCollectionCell" forIndexPath:indexPath];
	TRBMovie * movie = _movies[indexPath.row];
	cell.titleLabel.text = movie.title;
	cell.taglineLabel.text = movie.tagline;
	cell.genresLabel.text = movie.genres;
	cell.dateLabel.text = movie.releaseDate;
	UIImage * poster = movie.posterImage;
	cell.posterImageView.image = poster;
	if (!poster) {
		[[TRBLibraryManager sharedManager] fetchPosterForMovieID:movie.vsID completion:^(UIImage *image, NSError *error) {
			movie.posterImage = image;
			TRBMovieCollectionCell * cell = (TRBMovieCollectionCell *)[collectionView cellForItemAtIndexPath:indexPath];
			cell.posterImageView.image = image;
		}];
	}
	return cell;
}

#pragma mark - UICollectionViewDelegateFlowLayout Implementation

//- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
//	[collectionView deselectItemAtIndexPath:indexPath animated:YES];
//}

#pragma mark - UIScrollViewDelegate Implementation

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
	[_searchBar resignFirstResponder];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
	if (!_fetching) {
		UICollectionViewFlowLayout * layout = (UICollectionViewFlowLayout *)self.collectionView.collectionViewLayout;
		CGFloat currentPosition = scrollView.contentOffset.y;
		CGFloat refreshMargin = layout.itemSize.height * 6.0;
		if (currentPosition > _previousContentPosition &&  (*_offsetBottom) < (*_total)) {
			if (currentPosition >= scrollView.contentSize.height - refreshMargin)
				[self updateCurrentListWithAppendPosition:TRBLibraryAppendPositionBottom];
		} else if ((currentPosition < _previousContentPosition) && ((*_offsetTop) >= 0) && (currentPosition <= refreshMargin))
			[self updateCurrentListWithAppendPosition:TRBLibraryAppendPositionTop];
		_previousContentPosition = currentPosition;
	}
}

#pragma mark - Segues

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
	if ([segue.identifier isEqualToString:@"TRBShowMovieDetails"]) {
		TRBMovieCollectionCell * cell = sender;
		NSIndexPath * indexPath = [self.collectionView indexPathForCell:cell];
		TRBMovie * movie = _movies[indexPath.row];
		TRBLibraryMovieDetailsViewController * destination = segue.destinationViewController;
		[destination showMovie:movie];
	} else if ([segue.identifier isEqualToString:@"TRBShowLibraryFilters"]) {
		TRBLibraryFilterViewController * filterViewController = [[((UINavigationController *)segue.destinationViewController) viewControllers] firstObject];
		filterViewController.selectedFilter = _currentFilter;
	}
}

- (IBAction)unwindToLibraryListViewController:(UIStoryboardSegue *)segue {
	TRBLibraryFilterViewController * filterViewController = segue.sourceViewController;
	TRBLibraryFilterName selectedFilter = filterViewController.selectedFilter;
	NSDictionary * filters = [filterViewController filter];
	if (selectedFilter != _currentFilter || ![_filters isEqualToDictionary:filters]) {
		_currentFilter = selectedFilter;
		_filters = filters;
		_filterDescription = filterViewController.filterDescription;
		[self resetAndSwithToList];
		[self fetchMoviesWithAppendPosition:TRBLibraryAppendPositionBottom];
	}
}

#pragma mark - Actions

- (IBAction)cancelButtonPressed:(id)sender {
	[_searchBar resignFirstResponder];
	if (_movies == _searched) {
		_movies = _list;
		_offsetBottom = &_listOffsetBottom;
		_offsetTop = &_listOffsetTop;
		_total = &_listTotal;
		self.navigationItem.rightBarButtonItems = _defaultRightBarButtonItems;
		[self.collectionView reloadData];
		self.navigationItem.prompt = _filterDescription;
	}
}

#pragma mark - Private Methods

- (void)updateCurrentListWithAppendPosition:(TRBLibraryAppendPosition)appendPosition {
	if (_movies == _list)
		[self fetchMoviesWithAppendPosition:appendPosition];
	else
		[self searchMovieWithAppendPosition:appendPosition];
}

- (void)resetAndSwithToList {
	_movies = _list;
	[_list removeAllObjects];
	_listOffsetTop = -MOVIES_LIMIT;
	_listOffsetBottom = 0;
	_listTotal = 0;
	_offsetTop = &_listOffsetTop;
	_offsetBottom = &_listOffsetBottom;
	_total = &_listTotal;
	[self.collectionView reloadData];
}

- (void)fetchMoviesWithAppendPosition:(TRBLibraryAppendPosition)appendPosition {
	if (!_fetching) {
		_fetching = YES;
		NSUInteger offset = appendPosition == TRBLibraryAppendPositionBottom ? _listOffsetBottom : _listOffsetTop;
		[_libraryManager fetchMovieListWithOffest:offset limit:MOVIES_LIMIT sortBy:@"title" order:@"asc" filters:_filters completion:^(NSDictionary * json, NSError * error) {
			if (!error) {
				_movies = _list;
				_offsetBottom = &_listOffsetBottom;
				_offsetTop = &_listOffsetTop;
				_total = &_listTotal;
				NSDictionary * data = json[@"data"];
				NSArray * movies = data[@"movies"];
				NSMutableArray * toAdd = [NSMutableArray arrayWithCapacity:[movies count]];
				for (NSDictionary * movieDict in movies) {
					TRBMovie * movie = [[TRBMovie alloc] initWithVSJSON:movieDict];
					[toAdd addObject:movie];
				}
				if (appendPosition == TRBLibraryAppendPositionBottom)
					[_list addObjectsFromArray:toAdd];
				else
					[_list insertObjects:toAdd atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [toAdd count])]];
				if (appendPosition == TRBLibraryAppendPositionBottom)
					_listOffsetBottom += [toAdd count];
				else
					_listOffsetTop -= [toAdd count];
				_listTotal = [data[@"total"] unsignedIntegerValue];
				BOOL updateContentOffset = [_list count] > MOVIES_LIMIT * 2;
				if (updateContentOffset) {
					NSUInteger location = 0;
					if (appendPosition == TRBLibraryAppendPositionBottom) {
						location = 0;
						_listOffsetTop += MOVIES_LIMIT;
					} else {
						location = [_list count] - MOVIES_LIMIT;
						_listOffsetBottom -= MOVIES_LIMIT;
					}
					NSUInteger toRemoveCount = [_list count] - (MOVIES_LIMIT * 2);
					[_list removeObjectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(location, toRemoveCount)]];
				}
				[self.collectionView reloadData];
				if (updateContentOffset) {
					UICollectionViewFlowLayout * layout = (UICollectionViewFlowLayout *)self.collectionView.collectionViewLayout;
					CGFloat itemHeight = layout.itemSize.height;
					CGPoint offset = self.collectionView.contentOffset;
					offset.y += ((itemHeight * MOVIES_LIMIT) * (appendPosition == TRBLibraryAppendPositionBottom ? -1.0 : 1.0));
					self.collectionView.contentOffset = offset;
				}
			}
			_fetching = NO;
		}];
	}
}

- (void)searchMovieWithAppendPosition:(TRBLibraryAppendPosition)appendPosition {
	if (!_fetching) {
		_fetching = YES;
		NSUInteger offset = appendPosition == TRBLibraryAppendPositionBottom ? _searchOffsetBottom : _searchOffsetTop;
		[_libraryManager searchMovietWithKeyword:_searchBar.text
										  offest:offset
										   limit:MOVIES_LIMIT
										  sortBy:@"title"
										   order:@"asc"
									  completion:^(NSDictionary *json, NSError *error) {
										  if (!error) {
											  _movies = _searched;
											  _offsetBottom = &_searchOffsetBottom;
											  _offsetTop = &_searchOffsetTop;
											  _total = &_searchTotal;
											  _defaultRightBarButtonItems = self.navigationItem.rightBarButtonItems;
											  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
																																	 target:self
																																	 action:@selector(cancelButtonPressed:)];
											  NSDictionary * data = json[@"data"];
											  NSArray * movies = data[@"movies"];
											  NSMutableArray * toAdd = [NSMutableArray arrayWithCapacity:[movies count]];
											  for (NSDictionary * movieDict in movies) {
												  TRBMovie * movie = [[TRBMovie alloc] initWithVSJSON:movieDict];
												  [toAdd addObject:movie];
											  }
											  if (appendPosition == TRBLibraryAppendPositionBottom)
												  [_searched addObjectsFromArray:toAdd];
											  else
												  [_searched insertObjects:toAdd atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [toAdd count])]];
											  if (appendPosition == TRBLibraryAppendPositionBottom)
												  _searchOffsetBottom += [toAdd count];
											  else
												  _searchOffsetTop -= [toAdd count];
											  _searchTotal = [data[@"total"] unsignedIntegerValue];
											  BOOL updateContentOffset = [_searched count] > MOVIES_LIMIT * 2;
											  if (updateContentOffset) {
												  NSUInteger location = 0;
												  if (appendPosition == TRBLibraryAppendPositionBottom) {
													  location = 0;
													  _searchOffsetTop += MOVIES_LIMIT;
												  } else {
													  location = [_searched count] - MOVIES_LIMIT;
													  _searchOffsetBottom -= MOVIES_LIMIT;
												  }
												  NSUInteger toRemoveCount = [_searched count] - (MOVIES_LIMIT * 2);
												  [_searched removeObjectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(location, toRemoveCount)]];
											  }
											  [self.collectionView reloadData];
											  self.navigationItem.prompt = nil;
											  if (updateContentOffset) {
												  UICollectionViewFlowLayout * layout = (UICollectionViewFlowLayout *)self.collectionView.collectionViewLayout;
												  CGFloat itemHeight = layout.itemSize.height;
												  CGPoint offset = self.collectionView.contentOffset;
												  offset.y += ((itemHeight * MOVIES_LIMIT) * (appendPosition == TRBLibraryAppendPositionBottom ? -1.0 : 1.0));
												  self.collectionView.contentOffset = offset;
											  }
										  }
										  _fetching = NO;
									  }];
	}
}

@end

@implementation TRBMovieCollectionCell

@end
