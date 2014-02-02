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

typedef NS_ENUM(NSUInteger, TRBTMDbPosterSize) {
	TRBTMDbPosterSizeW92 = 0,
	TRBTMDbPosterSizeW154,
	TRBTMDbPosterSizeW185,
	TRBTMDbPosterSizeW342,
	TRBTMDbPosterSizeW500,
	TRBTMDbPosterSizeOriginal,
};

typedef NS_ENUM(NSUInteger, TRBTMDbBackdropSize) {
	TRBTMDbBackdropSizeW300 = 0,
	TRBTMDbBackdropSizeW780,
	TRBTMDbBackdropSize1280,
	TRBTMDbBackdropSizeOriginal,
};

typedef NS_ENUM(NSUInteger, TRBTMDbListType) {
	TRBTMDbListTypePopular = 0,
	TRBTMDbListTypeUpcoming,
	TRBTMDbListTypeNowPlaying,
	TRBTMDbListTypeTopRated,

	TRBTMDbListTypeCount
};

typedef NS_ENUM(NSUInteger, TRBTMDbProfileSize) {
	TRBTMDbProfileSizeW45 = 0,
	TRBTMDbProfileSizeW185,
	TRBTMDbProfileSizeH632,
	TRBTMDbProfileSizeOriginal,
};

typedef NS_ENUM(NSUInteger, TRBTMDbImageType) {
	TRBTMDbImageTypeBackdrop = 0,
	TRBTMDbImageTypePoster,

	TRBTMDbImageTypeCount
};

@interface TRBTMDbClient : NSObject

+ (instancetype)sharedInstance;

- (void)fetchMovieList:(TRBTMDbListType)listType withPage:(NSUInteger)page completion:(TRBJSONResultBlock)completion;
- (void)fetchMovieInfoWithID:(NSNumber *)movieID completion:(TRBJSONResultBlock)completion;
- (void)fetchMovieTrailersWithID:(NSNumber *)movieID completion:(TRBJSONResultBlock)completion;
- (void)fetchMovieImagesWithID:(NSNumber *)movieID completion:(TRBJSONResultBlock)completion;
- (void)fetchMovieCastsWithID:(NSNumber *)movieID completion:(TRBJSONResultBlock)completion;
- (void)searchMoviesWithQuery:(NSString *)query page:(NSUInteger)page completion:(TRBJSONResultBlock)completion;
- (void)fetchPoster:(NSString *)poster withSize:(TRBTMDbPosterSize)size completion:(TRBImageResultBlock)completion;
- (void)fetchBackdrop:(NSString *)backdrop withSize:(TRBTMDbBackdropSize)size completion:(TRBImageResultBlock)completion;
- (void)fetchProfileImage:(NSString *)profile withSize:(TRBTMDbProfileSize)size completion:(TRBImageResultBlock)completion;
- (void)findMovieWithRTMovie:(TRBMovie *)rtMovie completion:(TRBJSONResultBlock)completion;

@end
