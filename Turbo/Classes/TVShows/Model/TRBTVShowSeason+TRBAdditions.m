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

#import "TRBTVShowSeason+TRBAdditions.h"
#import "TRBTVShowEpisode.h"
#import "TRBTVShow.h"

static NSNumberFormatter * TRBTVShowNumberFormatter;

@implementation TRBTVShowSeason (TRBAdditions)

+ (void)initialize {
	TRBTVShowNumberFormatter = [NSNumberFormatter new];
	[TRBTVShowNumberFormatter setMinimumIntegerDigits:2];
}

- (NSArray *)orderedEpisodes {
	return [[self.episodes allObjects] sortedArrayUsingComparator:^NSComparisonResult(TRBTVShowEpisode * obj1, TRBTVShowEpisode * obj2) {
		return [obj1.episodeNumber compare:obj2.episodeNumber];
	}];
}

- (NSString *)niceTitle {
	NSString * result = @"";
	if ([self.number integerValue])
		result = [NSString stringWithFormat:@"Season %@", [TRBTVShowNumberFormatter stringFromNumber:self.number]];
	else
		result = @"Specials";
	return result;
}

- (NSString *)niceSearchString {
	NSString * result = @"";
	if ([self.number integerValue])
		result = [NSString stringWithFormat:@"%@ Season %@", self.series.title, [TRBTVShowNumberFormatter stringFromNumber:self.number]];
	return result;
}

@end
