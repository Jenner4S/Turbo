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

@class TRBTVShowSeason;

@interface TRBTVShowEpisode : NSManagedObject

@property (nonatomic, strong) NSDate * airDate;
@property (nonatomic, strong) NSNumber * episodeID;
@property (nonatomic, strong) NSNumber * episodeNumber;
@property (nonatomic, strong) NSString * episodeTitle;
@property (nonatomic, strong) NSString * imagePath;
@property (nonatomic, strong) NSString * language;
@property (nonatomic, strong) NSDate * lastUpdated;
@property (nonatomic, strong) NSString * overview;
@property (nonatomic, strong) NSNumber * rating;
@property (nonatomic, strong) NSNumber * ratingCount;
@property (nonatomic, strong) NSNumber * seasonID;
@property (nonatomic, strong) NSNumber * seasonNumber;
@property (nonatomic, strong) NSNumber * seriesID;
@property (nonatomic, strong) NSNumber * notificationScheduled;
@property (nonatomic, strong) NSNumber * watched;
@property (nonatomic, strong) TRBTVShowSeason *season;

@end
