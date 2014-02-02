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

#import "TRBXMLElement+TRBTVShow.h"
#import "NSString+TRBUnits.h"

@implementation TRBXMLElement (TRBTVShow)

#pragma mark - TRBTVShowCommon Implementation

- (NSNumber *)seriesID {
	NSNumber * result = nil;
	if ([self.name isEqualToString:@"Series"])
		result = @([self[@"Series.id"] integerValue]);
	else if ([self.name isEqualToString:@"Episode"])
		result = @([self[@"Episode.seriesid"] integerValue]);
	return result;
}

- (NSString *)language {
	NSString * result = self[@".Language"];
	if (!result)
		result = self[@".language"];
	return result;
}

- (NSString *)overview {
	return self[@".Overview"];
}

- (NSNumber *)rating {
	return @([self[@".Rating"] floatValue]);
}

- (NSNumber *)ratingCount {
	return @([self[@".RatingCount"] integerValue]);
}

- (NSDate *)lastUpdated {
	double timestamp = [self[@".lastupdated"] doubleValue];
	return [NSDate dateWithTimeIntervalSince1970:timestamp];
}

#pragma mark - TRBTVShow Implementation

- (NSString *)actors {
	return self[@"Series.Actors"];
}

- (NSString *)airsDayOfWeek {
	return self[@"Series.Airs_DayOfWeek"];
}

- (NSString *)airsTime {
	return self[@"Series.Airs_Time"];
}

- (NSString *)banner {
	return self[@"Series.banner"];
}

- (NSString *)contentRating {
	return self[@"Series.ContentRating"];
}

- (NSString *)fanart {
	return self[@"Series.fanart"];
}

- (NSDate *)firstAired {
	return [self[@"Series.FirstAired"]  dateFromInputFormat:@"yyyy-MM-dd"];
}

- (NSString *)genre {
	return self[@"Series.Genre"];
}

- (NSString *)imdbID {
	return self[@"Series.IMDB_ID"];
}

- (NSString *)network {
	return self[@"Series.Network"];
}

- (NSString *)poster {
	return self[@"Series.poster"];
}

- (NSNumber *)runtime {
	return @([self[@"Series.Runtime"] integerValue]);
}

- (NSString *)status {
	return self[@"Series.Status"];
}

- (NSString *)title {
	return self[@"Series.SeriesName"];
}

#pragma mark - TRBTVShowEpisode Implementation

- (NSNumber *)episodeID {
	return @([self[@"Episode.id"] integerValue]);
}

- (NSString *)episodeTitle {
	return self[@"Episode.EpisodeName"];
}

- (NSNumber *)episodeNumber {
	return @([self[@"Episode.EpisodeNumber"] integerValue]);
}

- (NSDate *)airDate {
	NSLocale * locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
	NSTimeZone * timezone = [NSTimeZone timeZoneWithName:@"America/Los_Angeles"];
	return [self[@"Episode.FirstAired"] dateFromInputFormat:@"yyyy-MM-dd" withLocale:locale andTimezone:timezone];
}

- (NSNumber *)seasonNumber {
	return @([self[@"Episode.SeasonNumber"] integerValue]);
}

- (NSString *)imagePath {
	return self[@"Episode.filename"];
}

- (NSNumber *)seasonID {
	return @([self[@"Episode.seasonid"] integerValue]);
}

@end
