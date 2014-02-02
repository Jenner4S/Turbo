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

typedef NS_ENUM(NSUInteger, TRBLibraryFilterName) {
	TRBLibraryFilterNoFilter = 0,
	TRBLibraryFilterRecentlyAdded,
	TRBLibraryFilterByYear,
	TRBLibraryFilterByGenre,
	TRBLibraryFilterByActor,
	TRBLibraryFilterByDirector,
	TRBLibraryFilterByWriter,
};

@interface TRBLibraryManager : NSObject

@property (nonatomic, strong) NSString * host;
@property (nonatomic, assign) NSInteger port;
@property (nonatomic, readonly, getter = isAuthenticated) BOOL authenticated;

+ (instancetype)sharedManager;
// Authentication
- (void)startAuthenticationCompletion:(void(^)(NSError * error))completion;
// Movies
- (void)fetchMovieListWithOffest:(NSUInteger)offset
						   limit:(NSUInteger)limit
						  sortBy:(NSString *)sort
						   order:(NSString *)order
						 filters:(NSDictionary *)filters
					  completion:(void(^)(NSDictionary * json, NSError * error))completion;
- (void)searchMovietWithKeyword:(NSString *)keyword
						 offest:(NSUInteger)offset
						  limit:(NSUInteger)limit
						 sortBy:(NSString *)sort
						  order:(NSString *)order
					 completion:(void(^)(NSDictionary * json, NSError * error))completion;
- (void)fetchMovieDetailsForID:(NSString *)movieID completion:(void(^)(NSDictionary * json, NSError * error))completion;
// TVShows
- (void)fetchTVShowListWithOffest:(NSUInteger)offset
							limit:(NSUInteger)limit
						   sortBy:(NSString *)sort
							order:(NSString *)order
					   completion:(void(^)(NSDictionary * json, NSError * error))completion;
- (void)fetchTVShowEpisodeListForID:(NSString *)tvShowID completion:(void(^)(NSDictionary * json, NSError * error))completion;
// Posters
- (void)fetchPosterForMovieID:(NSString *)movieID completion:(void(^)(UIImage * image, NSError * error))completion;
- (void)fetchPosterForTVShowID:(NSString *)tvShowID completion:(void(^)(UIImage * image, NSError * error))completion;
- (void)fetchPosterForTVShowEpisodeID:(NSString *)tvShowEpisodeID completion:(void(^)(UIImage * image, NSError * error))completion;
// Metadata
- (void)fetchMetadataForType:(NSString *)type category:(NSString *)category completion:(void(^)(NSDictionary * json, NSError * error))completion;

@end
