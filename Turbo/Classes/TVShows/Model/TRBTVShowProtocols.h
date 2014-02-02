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

@protocol TRBTVShowCommon <NSObject>

@property (nonatomic, readonly) NSNumber * seriesID;
@property (nonatomic, readonly) NSString * language;
@property (nonatomic, readonly) NSString * overview;
@property (nonatomic, readonly) NSNumber * rating;
@property (nonatomic, readonly) NSNumber * ratingCount;
@property (nonatomic, readonly) NSDate * lastUpdated;

@end

@protocol TRBTVShow <TRBTVShowCommon>

@property (nonatomic, readonly) NSString * actors;
@property (nonatomic, readonly) NSString * airsDayOfWeek;
@property (nonatomic, readonly) NSString * airsTime;
@property (nonatomic, readonly) NSString * banner;
@property (nonatomic, readonly) NSString * contentRating;
@property (nonatomic, readonly) NSString * fanart;
@property (nonatomic, readonly) NSDate * firstAired;
@property (nonatomic, readonly) NSString * genre;
@property (nonatomic, readonly) NSString * imdbID;
@property (nonatomic, readonly) NSString * network;
@property (nonatomic, readonly) NSString * poster;
@property (nonatomic, readonly) NSNumber * runtime;
@property (nonatomic, readonly) NSString * status;
@property (nonatomic, readonly) NSString * title;

@end

@protocol TRBTVShowEpisode <TRBTVShowCommon>

@property (nonatomic, readonly) NSNumber * episodeID;
@property (nonatomic, readonly) NSString * episodeTitle;
@property (nonatomic, readonly) NSNumber * episodeNumber;
@property (nonatomic, readonly) NSDate * airDate;
@property (nonatomic, readonly) NSNumber * seasonNumber;
@property (nonatomic, readonly) NSString * imagePath;
@property (nonatomic, readonly) NSNumber * seasonID;

@end
