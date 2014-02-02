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

#import "TRBLibraryMovieDetailsViewController.h"
#import "TRBLibraryManager.h"
#import "TRBMovie.h"
#import "TRBTMDbClient.h"
#import "NSString+TRBUnits.h"

@interface TRBLibraryMovieDetailsViewController ()<UIGestureRecognizerDelegate>

@end

@implementation TRBLibraryMovieDetailsViewController {
	TRBMovie * _movie;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
		self.hidesBottomBarWhenPushed = YES;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
	[self.collectionView registerClass:[TRBLibraryFileDetailsHeaderView class]
			forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
				   withReuseIdentifier:@"TRBLibraryFileDetailsHeaderView"];
}

//- (void)viewWillAppear:(BOOL)animated {
//	[super viewWillAppear:animated];
//	[self.navigationController setNavigationBarHidden:YES animated:YES];
//	self.navigationController.interactivePopGestureRecognizer.delegate = self;
//}
//
//- (void)viewWillDisappear:(BOOL)animated {
//	[super viewWillDisappear:animated];
//	[self.navigationController setNavigationBarHidden:NO animated:YES];
//}

#pragma mark - Public Methods

- (void)showMovie:(TRBMovie *)movie {
	_movie = movie;
	[[TRBLibraryManager sharedManager] fetchMovieDetailsForID:_movie.vsID completion:^(NSDictionary * json, NSError * error) {
		if (!error) {
			[_movie updateWithVSInfo:[json[@"data"][@"movies"] firstObject]];
			[self.collectionView reloadData];
			if (_movie.tmdbID)
				[self fetchAdditionalInfo];
		}
	}];
}

#pragma mark - UICollectionViewDataSource Implementation

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
	return 2;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
	NSInteger result = 0;
	switch (section) {
		case 0:
			result = 1;
			break;
		case 1:
			result = [_movie.files count];
			break;
		default:
			break;
	}
	return result;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
	UICollectionViewCell * cell = nil;
	switch (indexPath.section) {
		case 0: {
			TRBLibraryMovieDetailsCell * movieCell = [collectionView dequeueReusableCellWithReuseIdentifier:@"TRBLibraryMovieDetailsCell" forIndexPath:indexPath];
			movieCell.titleLabel.text = _movie.title;
			movieCell.taglineLabel.text = _movie.tagline;
			movieCell.genresLabel.text = _movie.genres;
			movieCell.actorsLabel.text = _movie.cast;
			cell = movieCell;
			break;
		} case 1: {
			TRBLibraryFileDetailsCell * fileCell = [collectionView dequeueReusableCellWithReuseIdentifier:@"TRBLibraryFileDetailsCell" forIndexPath:indexPath];
			NSDictionary * fileInfo = _movie.files[indexPath.item];
			[fileCell setupWithFileInfo:fileInfo];
			cell = fileCell;
			break;
		}
		default:
			break;
	}
	return cell;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
	UICollectionReusableView * headerView = nil;
	switch (indexPath.section) {
		case 0: {
			TRBLibraryMovieDetailsHeaderView * movieHeaderView = [collectionView dequeueReusableSupplementaryViewOfKind:kind
																								   withReuseIdentifier:@"TRBLibraryMovieDetailsHeaderView"
																										  forIndexPath:indexPath];
			movieHeaderView.backdropImageView.image = _movie.backdropImage;
			movieHeaderView.summaryTextView.text = _movie.synopsis;
			headerView = movieHeaderView;
			break;
		} case 1: {
			headerView = [collectionView dequeueReusableSupplementaryViewOfKind:kind
															withReuseIdentifier:@"TRBLibraryFileDetailsHeaderView"
																   forIndexPath:indexPath];
			break;
		}
		default:
			break;
	}
	return headerView;
}

#pragma mark - UICollectionViewDelegateFlowLayout Implementation

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section {
	CGSize result = CGSizeZero;
	switch (section) {
		case 0:
			result = CGSizeMake(0.0, isIdiomPad ? 395.0 : 180.0);
			break;
		case 1:
			result = CGSizeMake(0.0, 50.0);
			break;
		default:
			break;
	}
	return result;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
	CGSize result = CGSizeZero;
	switch (indexPath.section) {
		case 0:
			result = CGSizeMake(CGRectGetWidth(collectionView.bounds), 180.0);
			break;
		case 1:
			result = CGSizeMake(320.0, 180.0);
			break;
		default:
			break;
	}
	return result;
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout insetForSectionAtIndex:(NSInteger)section {
// 352
	UIEdgeInsets result = UIEdgeInsetsZero;
	if (section == 1) {
		CGFloat files = (CGFloat)[_movie.files count];
		CGFloat width = CGRectGetWidth(collectionView.bounds);
		CGFloat insets = width - ((files * 320.0) + ((files - 1.0) * 10.0)) / 2.0;
		result = UIEdgeInsetsMake(0.0, insets, 0.0, insets);
	}
	return result;
}

//- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
//	[collectionView deselectItemAtIndexPath:indexPath animated:YES];
//}

#pragma mark - Private Methods

- (void)fetchAdditionalInfo {
	[[TRBTMDbClient sharedInstance] fetchMovieInfoWithID:_movie.tmdbID completion:^(NSDictionary *json, NSError *error) {
		if (!error) {
			[_movie updateWithTMDbInfo:json];
			[self.collectionView reloadData];
			if (!_movie.backdropImage && _movie.backdropPath)
				[self fetchBackdropImage];
		}
	}];
}

- (void)fetchBackdropImage {
	TRBTMDbBackdropSize size = [UIScreen mainScreen].scale > 1.0 ? TRBTMDbBackdropSizeW780 : TRBTMDbBackdropSizeW300;
	[[TRBTMDbClient sharedInstance] fetchBackdrop:_movie.backdropPath withSize:size completion:^(UIImage * image, NSError * error) {
		if (!error) {
			_movie.backdropImage = image;
			[self.collectionView reloadData];
		}
	}];
}

@end

@implementation TRBLibraryMovieDetailsCell

@end

@implementation TRBLibraryMovieDetailsHeaderView

@end

@implementation TRBLibraryFileDetailsCell

- (void)setupWithFileInfo:(NSDictionary *)fileInfo {
	long long fileSizeBytes = [fileInfo[@"filesize"] longLongValue];
	_sizeLabel.text = [NSString stringWithByteCount:fileSizeBytes];
	_resolutionLabel.text = [NSString stringWithFormat:@"%@ x %@", fileInfo[@"resolutionx"], fileInfo[@"resolutiony"]];
	_videoCodecLabel.text = fileInfo[@"video_codec"];
	_audioCodecLabel.text = fileInfo[@"audio_codec"];
	_durationLabel.text = fileInfo[@"duration"];
	_pathLabel.text = fileInfo[@"sharepath"];
}

@end

@implementation TRBLibraryFileDetailsHeaderView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
		UILabel * label = [UILabel new];
		label.backgroundColor = [UIColor whiteColor];
		label.opaque = YES;
		label.text = @"Files";
		label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
		label.textAlignment = NSTextAlignmentCenter;
		[label setTranslatesAutoresizingMaskIntoConstraints:NO];
		[self addSubview:label];
		NSDictionary * view = NSDictionaryOfVariableBindings(label);
		NSMutableArray * constraints = [NSMutableArray new];
		[constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"|-20-[label]-20-|"
																				 options:kNilOptions
																				 metrics:nil
																				   views:view]];
		[constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-5-[label]-5-|"
																				 options:kNilOptions
																				 metrics:nil
																				   views:view]];
		[self addConstraints:constraints];

    }
    return self;
}

@end
