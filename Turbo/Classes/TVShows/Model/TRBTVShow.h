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

@class TRBTVShowBanner, TRBTVShowSeason;

@interface TRBTVShow : NSManagedObject

@property (nonatomic, strong) NSString * actors;
@property (nonatomic, strong) NSString * airsDayOfWeek;
@property (nonatomic, strong) NSString * airsTime;
@property (nonatomic, strong) NSString * banner;
@property (nonatomic, strong) NSString * contentRating;
@property (nonatomic, strong) NSString * fanart;
@property (nonatomic, strong) NSDate * firstAired;
@property (nonatomic, strong) NSString * genre;
@property (nonatomic, strong) NSString * imdbID;
@property (nonatomic, strong) NSString * language;
@property (nonatomic, strong) NSDate * lastUpdated;
@property (nonatomic, strong) NSString * network;
@property (nonatomic, strong) NSString * overview;
@property (nonatomic, strong) NSString * poster;
@property (nonatomic, strong) NSNumber * rating;
@property (nonatomic, strong) NSNumber * ratingCount;
@property (nonatomic, strong) NSNumber * runtime;
@property (nonatomic, strong) NSNumber * seriesID;
@property (nonatomic, strong) NSString * status;
@property (nonatomic, strong) NSString * title;
@property (nonatomic, strong) NSDate * updated;
@property (nonatomic, strong) NSSet *banners;
@property (nonatomic, strong) NSSet *seasons;
@end

@interface TRBTVShow (CoreDataGeneratedAccessors)

- (void)addBannersObject:(TRBTVShowBanner *)value;
- (void)removeBannersObject:(TRBTVShowBanner *)value;
- (void)addBanners:(NSSet *)values;
- (void)removeBanners:(NSSet *)values;

- (void)addSeasonsObject:(TRBTVShowSeason *)value;
- (void)removeSeasonsObject:(TRBTVShowSeason *)value;
- (void)addSeasons:(NSSet *)values;
- (void)removeSeasons:(NSSet *)values;

@end
