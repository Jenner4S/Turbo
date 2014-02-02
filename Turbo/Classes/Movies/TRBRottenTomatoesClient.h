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

typedef NS_ENUM(NSUInteger, TRBRTListType) {
	TRBRTListTypeBoxOffice = 0,
	TRBRTListTypeInTheaters,
	TRBRTListTypeOpening,
	TRBRTListTypeUpcomingMovies,
	TRBRTListTypeTopRentals,
	TRBRTListTypeCurrentReleases,
	TRBRTListTypeNewReleases,
	TRBRTListTypeUpcomingDVDs,

	TRBRTListTypeCount
};

@interface TRBRottenTomatoesClient : NSObject

+ (instancetype)sharedInstance;

- (void)fetchMovieList:(TRBRTListType)listType withHandler:(TRBJSONResultBlock)handler;
- (void)fetchImageAtURL:(NSString *)url withHandler:(TRBImageResultBlock)handler;
- (void)fetchMovieInfoForID:(NSString *)movieID withHandler:(TRBJSONResultBlock)handler;
- (void)fetchMovieReviewsForID:(NSString *)movieID page:(NSUInteger)page withHandler:(TRBJSONResultBlock)handler;
- (void)fetchCastsInfoForID:(NSString *)movieID withHandler:(TRBJSONResultBlock)handler;
- (void)searchWithQuery:(NSString *)query page:(NSUInteger)page andHandler:(TRBJSONResultBlock)handler;

@end
