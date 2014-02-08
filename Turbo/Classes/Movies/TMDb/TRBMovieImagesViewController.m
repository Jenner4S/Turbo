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

#import "TRBMovieImagesViewController.h"
#import "TRBMovieFullImageViewController.h"
#import "TRBTMDbClient.h"
#import "TRBMovie.h"
#import "NSDictionary+TRBAdditions.h"

@interface TRBMovieImagesViewController ()

@end

@implementation TRBMovieImagesViewController {
	NSArray * _backdrops;
	NSArray * _posters;
	NSMutableDictionary * _images;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
		_images = [NSMutableDictionary new];
    }
    return self;
}

- (id)initWithCollectionViewLayout:(UICollectionViewLayout *)layout {
	self = [super initWithCollectionViewLayout:layout];
	if (self) {
		_images = [NSMutableDictionary new];
	}
	return self;
}

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
	[_images removeAllObjects];
}

//- (void)viewDidLoad {
//    [super viewDidLoad];
//}

//- (void)viewWillAppear:(BOOL)animated {
//	[super viewWillAppear:animated];
//}

//- (void)viewWillDisappear:(BOOL)animated {
//	[super viewWillDisappear:animated];
//}

#pragma mark - Public Methods

- (void)showImagesForMovie:(TRBMovie *)movie {
	self.title = movie.title;
	[[TRBTMDbClient sharedInstance] fetchMovieImagesWithID:movie.tmdbID completion:^(NSDictionary *json, NSError *error) {
		LogCE(error != nil, [error localizedDescription]);
		_backdrops = json[@"backdrops"];
		_posters = json[@"posters"];
		[self.collectionView reloadData];
	}];
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
	NSDictionary * imageInfo = [self imageInfoForIndexPath:indexPath];
	NSString * filePath = [imageInfo valueForKey:@"file_path" andIsKindOfClass:[NSString class]];
	UIImage * image = _images[filePath];
	if (!image) {
		TRBImageResultBlock imageHandler = ^(UIImage * fetchedImage, NSError *error) {
			LogCE(error != nil, [error localizedDescription]);
			if (!fetchedImage)
				fetchedImage = [UIImage imageNamed:@"profile"];
			_images[filePath] = fetchedImage;
			TRBMovieImageCell * cellToUpdate = (TRBMovieImageCell *)[self.collectionView cellForItemAtIndexPath:indexPath];
			cellToUpdate.imageView.image = fetchedImage;
		};
		if (indexPath.section) {
			TRBTMDbPosterSize size = [UIScreen mainScreen].scale > 1.0 ? TRBTMDbPosterSizeW185 : TRBTMDbPosterSizeW92;
			[[TRBTMDbClient sharedInstance] fetchPoster:filePath withSize:size completion:imageHandler];
		} else
			[[TRBTMDbClient sharedInstance] fetchBackdrop:filePath withSize:TRBTMDbBackdropSizeW300 completion:imageHandler];
	}
	cell.imageView.image = image;
	return cell;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
	static NSString * const HeaderIdentifier = @"TRBMovieImageHeaderView";
	UICollectionReusableView * result = nil;
	if ([kind isEqualToString:UICollectionElementKindSectionHeader]) {
		TRBMovieImageHeaderView * header = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:HeaderIdentifier forIndexPath:indexPath];
		if (indexPath.section)
			header.title.text =  @"Posters";
		else
			header.title.text =  @"Backdrops";
		result = header;
	}
	return result;
}

#pragma mark - UICollectionViewDelegate Implementations

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
	CGSize result = CGSizeMake(100.0, 100.0);
	NSDictionary * imageInfo = [self imageInfoForIndexPath:indexPath];
	UIImage * image = _images[imageInfo[@"file_path"]];
	if (image)
		result = CGSizeMake(MIN(result.width, image.size.width), MIN(result.height, image.size.height));
	return result;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section {
	CGSize result = CGSizeZero;
	if ((section && [_posters count]) || (!section && [_backdrops count]))
		result = CGSizeMake(CGRectGetWidth(self.view.frame), 21.0);
	return result;
}

#pragma mark - Segues

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
	if ([segue.identifier isEqualToString:@"TRBMovieShowFullImages"]) {
		TRBMovieImageCell * cell = sender;
		NSIndexPath * indexPath = [self.collectionView indexPathForCell:cell];
		TRBMovieFullImageViewController * imageViewController = segue.destinationViewController;
		[imageViewController showImages:_images backdrops:_backdrops posters:_posters selectedIndexPath:indexPath];
	}
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

@end

@implementation TRBMovieImageCell

- (id)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (self) {
		UIImageView * imageView = [UIImageView new];
		[imageView setTranslatesAutoresizingMaskIntoConstraints:NO];
		imageView.contentMode = UIViewContentModeScaleAspectFit;
		[self addSubview:imageView];
		_imageView = imageView;
		NSMutableArray * constraints = [NSMutableArray new];
		NSDictionary * views = NSDictionaryOfVariableBindings(imageView);
		[constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"|-0-[imageView]-0-|"
																				 options:kNilOptions
																				 metrics:nil
																				   views:views]];
		[constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-0-[imageView]-0-|"
																				 options:kNilOptions
																				 metrics:nil
																				   views:views]];
		[self addConstraints:constraints];
	}
	return self;
}

- (void)prepareForReuse {
	[super prepareForReuse];
	_imageView.image = nil;
}

@end

@implementation TRBMovieImageHeaderView

@end
