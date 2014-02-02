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

@class TRBMovie;

@interface TRBLibraryMovieDetailsViewController : UICollectionViewController

- (void)showMovie:(TRBMovie *)movie;

@end

@interface TRBLibraryMovieDetailsCell : UICollectionViewCell
@property (weak, nonatomic) IBOutlet UILabel * titleLabel;
@property (weak, nonatomic) IBOutlet UILabel * taglineLabel;
@property (weak, nonatomic) IBOutlet UILabel * genresLabel;
@property (weak, nonatomic) IBOutlet UILabel * actorsLabel;
@end

@interface TRBLibraryMovieDetailsHeaderView : UICollectionReusableView
@property (weak, nonatomic) IBOutlet UIImageView * backdropImageView;
@property (weak, nonatomic) IBOutlet UITextView * summaryTextView;
@end

@interface TRBLibraryFileDetailsCell : UICollectionViewCell
@property (weak, nonatomic) IBOutlet UILabel *sizeLabel;
@property (weak, nonatomic) IBOutlet UILabel *resolutionLabel;
@property (weak, nonatomic) IBOutlet UILabel *videoCodecLabel;
@property (weak, nonatomic) IBOutlet UILabel *audioCodecLabel;
@property (weak, nonatomic) IBOutlet UILabel *durationLabel;
@property (weak, nonatomic) IBOutlet UILabel *pathLabel;

- (void)setupWithFileInfo:(NSDictionary *)fileInfo;

@end

@interface TRBLibraryFileDetailsHeaderView : UICollectionReusableView
@end
