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

#import "TRBMovieFullImageViewController.h"
#import "TRBMovieImagesViewController.h"

@interface TRBMovieFullImageViewController ()

@end

@implementation TRBMovieFullImageViewController {
	NSMutableDictionary * _images;
	NSMutableDictionary * _highResImages;
	NSArray * _backdrops;
	NSArray * _posters;
	NSIndexPath * _selectedIndexPath;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
    }
    return self;
}

- (id)initWithCollectionViewLayout:(UICollectionViewLayout *)layout {
	self = [super initWithCollectionViewLayout:layout];
	if (self) {
		[self setHidesBottomBarWhenPushed:YES];
	}
	return self;
}

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
	[_images removeAllObjects];
	[_highResImages removeAllObjects];
}

- (void)viewDidLoad {
    [super viewDidLoad];
	UICollectionViewFlowLayout * layout = (UICollectionViewFlowLayout *)self.collectionViewLayout;
	layout.sectionInset = UIEdgeInsetsZero;
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	self.collectionView.delegate = self;
	self.collectionView.dataSource = self;
	if (_selectedIndexPath) {
		[self.collectionView scrollToItemAtIndexPath:_selectedIndexPath atScrollPosition:UICollectionViewScrollPositionLeft animated:NO];
		_selectedIndexPath = nil;
	}
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	[self setNeedsStatusBarAppearanceUpdate];
	if (isIdiomPhone) {
		UICollectionViewFlowLayout * layout = (UICollectionViewFlowLayout *)self.collectionViewLayout;
		CGSize size = self.collectionView.bounds.size;
		size.height -= (layout.sectionInset.top + layout.sectionInset.bottom);
		layout.itemSize = size;
		[layout invalidateLayout];
	}
}

- (BOOL)shouldAutorotate {
	return YES;
}

- (NSUInteger)supportedInterfaceOrientations {
	return UIInterfaceOrientationMaskPortrait|UIInterfaceOrientationMaskLandscape|UIInterfaceOrientationMaskPortraitUpsideDown;
}

- (BOOL)prefersStatusBarHidden {
	return YES;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
	if (isIdiomPhone) {
		[self.navigationController setNavigationBarHidden:UIInterfaceOrientationIsLandscape(toInterfaceOrientation) animated:NO];
		if ((UIInterfaceOrientationIsPortrait(self.interfaceOrientation) && UIInterfaceOrientationIsLandscape(toInterfaceOrientation)) ||
			(UIInterfaceOrientationIsPortrait(toInterfaceOrientation) && UIInterfaceOrientationIsLandscape(self.interfaceOrientation))) {
			UICollectionViewFlowLayout * layout = (UICollectionViewFlowLayout *)self.collectionViewLayout;
			CGSize size = CGSizeMake(CGRectGetHeight(self.collectionView.bounds), CGRectGetWidth(self.collectionView.bounds) - (layout.sectionInset.top + layout.sectionInset.bottom));
			layout.itemSize = size;
		}
	}
	[super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
	if (isIdiomPhone) {
		UICollectionViewFlowLayout * layout = (UICollectionViewFlowLayout *)self.collectionViewLayout;
		CGSize size = CGSizeMake(CGRectGetWidth(self.collectionView.bounds), CGRectGetHeight(self.collectionView.bounds) - (layout.sectionInset.top + layout.sectionInset.bottom));
		layout.itemSize = size;
	}
	[super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
}

//- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
//	[super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
//}

#pragma mark - Public Methods

- (void)showImages:(NSDictionary *)images backdrops:(NSArray *)backdrops posters:(NSArray *)posters selectedIndexPath:(NSIndexPath *)indexPath {
	_images = [images mutableCopy];
	_highResImages = [NSMutableDictionary dictionaryWithCapacity:[_images count]];
	_backdrops = [backdrops mutableCopy];
	_posters = [posters mutableCopy];
	if (self.isViewLoaded)
		[self.collectionView selectItemAtIndexPath:indexPath animated:YES scrollPosition:UICollectionViewScrollPositionLeft];
	else
		_selectedIndexPath = indexPath;
}

#pragma mark - UICollectionViewDataSource Implementation

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
	NSInteger result = 0;
	if (section)
		result = [_posters count];
	else
		result = [_backdrops count];
	return result;
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
	return 2;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
	static NSString * const CellIdentifier = @"TRBMovieImageCell";
	TRBMovieImageCell * cell = [collectionView dequeueReusableCellWithReuseIdentifier:CellIdentifier forIndexPath:indexPath];
//	CGFloat hue = ( arc4random() % 256 / 256.0 );  //  0.0 to 1.0
//	CGFloat saturation = ( arc4random() % 128 / 256.0 ) + 0.5;  //  0.5 to 1.0, away from white
//	CGFloat brightness = ( arc4random() % 128 / 256.0 ) + 0.5;  //  0.5 to 1.0, away from black
//	cell.backgroundColor = [UIColor colorWithHue:hue saturation:saturation brightness:brightness alpha:1];
	NSDictionary * imageInfo = [self imageInfoForIndexPath:indexPath];
	NSString * filePath = imageInfo[@"file_path"];
	UIImage * image = _highResImages[filePath];
	if (!image) {
		image = _images[filePath];
		[self fetchHighResImageWithPath:filePath type:(indexPath.section ? TRBTMDbImageTypePoster : TRBTMDbImageTypeBackdrop) completion:^(UIImage * fetchedImage, NSError *error) {
			LogCE(error != nil, [error localizedDescription]);
			if (!fetchedImage)
				fetchedImage = [UIImage imageNamed:@"profile"];
			_highResImages[filePath] = fetchedImage;
			TRBMovieImageCell * cellToUpdate = (TRBMovieImageCell *)[self.collectionView cellForItemAtIndexPath:indexPath];
			cellToUpdate.imageView.image = fetchedImage;
		}];
	}
	cell.imageView.image = image;
	return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didEndDisplayingCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath {
	TRBMovieImageCell * imageCell = (TRBMovieImageCell *)cell;
	imageCell.imageView.image = nil;
}

#pragma mark - Private Methods

- (NSDictionary *)imageInfoForIndexPath:(NSIndexPath *)indexPath {
	NSDictionary * imageInfo = nil;
	if (indexPath.section)
		imageInfo = _posters[indexPath.item];
	else
		imageInfo = _backdrops[indexPath.item];
	return imageInfo;
}

- (void)fetchHighResImageWithPath:(NSString *)path type:(TRBTMDbImageType)type completion:(TRBImageResultBlock)completion {
	CGFloat scale = [UIScreen mainScreen].scale;
	switch (type) {
		case TRBTMDbImageTypeBackdrop: {
			TRBTMDbBackdropSize size = scale > 1.0 ? TRBTMDbBackdropSize1280 : TRBTMDbBackdropSizeW780;
			[[TRBTMDbClient sharedInstance] fetchBackdrop:path withSize:size completion:completion];
			break;
		} case TRBTMDbImageTypePoster: {
			TRBTMDbPosterSize size = scale > 1.0 ? TRBTMDbPosterSizeOriginal : TRBTMDbPosterSizeW500;
			[[TRBTMDbClient sharedInstance] fetchPoster:path withSize:size completion:completion];
			break;
		}
		default:
			break;
	}
}

@end
