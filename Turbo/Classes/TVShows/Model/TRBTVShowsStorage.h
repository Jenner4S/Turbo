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

@import CoreData;

typedef NS_ENUM(NSUInteger, TRBTVShowBannerType) {
	TRBTVShowBannerTypePoster = 0,
	TRBTVShowBannerTypeFanart,
	TRBTVShowBannerTypeSeries,
	TRBTVShowBannerTypeSeason,

	TRBTVShowBannerTypeCount
};

@class TRBTVShow;
@class TRBTVShowEpisode;
@class TRBTVShowBanner;

@interface TRBTVShowsStorage : NSObject

+ (instancetype)sharedInstance;

#pragma mark - TV Shows

- (void)insertNewTVShowWithXML:(TRBXMLElement *)xml overwrite:(BOOL)overwrite andHandler:(void(^)(TRBTVShow * tvShow))handler;
- (void)fetchAllTVShowsWithHandler:(void(^)(NSArray * results))handler;
- (void)fetchTVShowWithID:(NSUInteger)seriesID andHandler:(void(^)(TRBTVShow * tvShow))handler;
- (void)fetchTVShowCountWithHandler:(void(^)(NSUInteger count))handler;
- (void)fetchStaleTVShowsWithHandler:(void(^)(NSArray * results))handler;
- (void)searchTVShowsWithTitle:(NSString *)title andHandler:(void(^)(NSArray * results))handler;
- (void)removeTVShow:(TRBTVShow *)tvShow;
- (void)removeTVShowWithID:(NSUInteger)seriesID;

- (void)updateTVShowWithRecords:(NSArray *)records andHandler:(void(^)(TRBTVShow * result))handler;

#pragma mark - TV Show Episodes

- (void)insertNewTVShowEpisodeWithXML:(TRBXMLElement *)xml forTVShow:(TRBTVShow *)tvShow overwrite:(BOOL)overwrite andHandler:(void(^)(TRBTVShowEpisode * episode))handler;
- (void)fetchTVShowEpisodeWithID:(NSUInteger)episodeID andHandler:(void(^)(TRBTVShowEpisode * episode))handler;
- (void)fetchNextEpisodeForTVShow:(TRBTVShow *)tvShow andHandler:(void(^)(TRBTVShowEpisode * episode))handler;
- (void)fetchPreviousEpisodeForTVShow:(TRBTVShow *)tvShow andHandler:(void(^)(TRBTVShowEpisode * episode))handler;
- (void)fetchAllNextEpisodesWithHandler:(void(^)(NSArray * results))handler;
- (void)fetchAllScheduledEpisodesWithHandler:(void(^)(NSArray * results))handler;
- (void)fetchEpisodesAiringFromDate:(NSDate *)fromDate toDate:(NSDate *)toDate withHandler:(void(^)(NSArray * results))handler;

#pragma mark - TV Show Banners

- (void)insertNewTVShowBannerWithXML:(TRBXMLElement *)xml forTVShow:(TRBTVShow *)tvShow overwrite:(BOOL)overwrite andHandler:(void(^)(TRBTVShowBanner * banner))handler;
- (void)fetchTVShowBannerWithID:(NSUInteger)episodeID andHandler:(void(^)(TRBTVShowBanner * tvShowBanner))handler;
- (void)fetchTVShowBannerWithType:(TRBTVShowBannerType)type forTVShow:(TRBTVShow *)tvShow mustHaveColors:(BOOL)colors andHandler:(void(^)(NSArray * banners))handler;

- (void)updateTVShowBannersWithRecords:(NSArray *)records forTVShow:(NSManagedObjectID *)tvShowID andHandler:(void(^)())handler;

#pragma mark - Shared

- (void)save;

@end
