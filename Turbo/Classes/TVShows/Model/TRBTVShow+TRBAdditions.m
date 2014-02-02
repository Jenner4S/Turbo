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

#import "TRBTVShow+TRBAdditions.h"
#import "TRBTVShowSeason.h"
#import "NSString+TRBUnits.h"
#import "TRBXMLElement+TRBTVShow.h"

@implementation TRBTVShow (TRBAdditions)

- (void)setupWithXML:(TRBXMLElement *)xml {
	self.seriesID = xml.seriesID;
	self.language = xml.language;
	self.title = xml.title;
	self.banner = xml.banner;
	self.overview = xml.overview;
	self.firstAired = xml.firstAired;
	self.imdbID = xml.imdbID;
	self.actors = xml.actors;
	self.airsDayOfWeek = xml.airsDayOfWeek;
	self.airsTime = xml.airsTime;
	self.contentRating = xml.contentRating;
	self.genre = [[xml.genre stringByReplacingOccurrencesOfString:@"|" withString:@", "] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@", "]];
	self.network = xml.network;
	self.rating = xml.rating;
	self.ratingCount = xml.ratingCount;
	self.runtime = xml.runtime;
	self.status = xml.status;
	self.fanart = xml.fanart;
	self.lastUpdated = xml.lastUpdated;
	self.poster = xml.poster;
	self.updated = [NSDate date];
}

- (NSArray *)orderedSeasons {
	return [[self.seasons allObjects] sortedArrayUsingComparator:^NSComparisonResult(TRBTVShowSeason * obj1, TRBTVShowSeason * obj2) {
		NSNumber * n1 = obj1.number;
		NSNumber * n2 = obj2.number;
		if (![n1 integerValue])
			n1 = @(NSIntegerMax);
		if (![n2 integerValue])
			n2 = @(NSIntegerMax);
		return [n1 compare:n2];
	}];
}

@end
