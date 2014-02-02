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

#import "TRBTVShowEpisode+TRBAddtions.h"
#import "NSString+TRBUnits.h"
#import "TRBXMLElement+TRBTVShow.h"
#import "TRBTVShow.h"
#import "TRBTVShowSeason.h"

static NSNumberFormatter * TRBTVShowNumberFormatter;

@implementation TRBTVShowEpisode (TRBAddtions)

+ (void)initialize {
	TRBTVShowNumberFormatter = [NSNumberFormatter new];
	[TRBTVShowNumberFormatter setMinimumIntegerDigits:2];
}

- (void)setupWithXML:(TRBXMLElement *)xml {
	self.episodeID = xml.episodeID;
	self.episodeTitle = xml.episodeTitle;
	self.episodeNumber = xml.episodeNumber;
	if (self.notificationScheduled && ![self.airDate isEqualToDate:xml.airDate]) {
		UILocalNotification * toCancel = nil;
		for (UILocalNotification * note in [UIApplication sharedApplication].scheduledLocalNotifications) {
			NSNumber * episodeID = note.userInfo[@"episodeID"];
			NSNumber * seriesID = note.userInfo[@"seriesID"];
			NSNumber * episodeNumber = note.userInfo[@"episodeNumber"];
			NSNumber * seasonNumber = note.userInfo[@"seasonNumber"];
			NSString * seriesTitle = note.userInfo[@"seriesTitle"];
			if (([episodeID isEqualToNumber:self.episodeID] && [seriesID isEqualToNumber:self.seriesID]) ||
				([episodeNumber isEqualToNumber:self.episodeNumber] && [seasonNumber isEqualToNumber:self.seasonNumber] && [seriesTitle isEqualToString:self.season.series.title])) {
				toCancel = note;
				break;
			}
		}
		if (toCancel)
			[[UIApplication sharedApplication] cancelLocalNotification:toCancel];
		BOOL notificationsDisabled = [[NSUserDefaults standardUserDefaults] boolForKey:TRBTVShowNotificationsKey];
		if (!notificationsDisabled)
			[self scheduleLocalNotification];
	}
	self.airDate = xml.airDate;
	self.language = xml.language;
	self.overview = xml.overview;
	self.rating = xml.rating;
	self.ratingCount = xml.ratingCount;
	self.seasonNumber = xml.seasonNumber;
	self.imagePath = xml.imagePath;
	self.seasonID = xml.seasonID;
	self.seriesID = xml.seriesID;
	self.lastUpdated = xml.lastUpdated;
}

- (NSString *)niceTitle {
	NSString * result = @"";
	if (![self.seasonNumber integerValue])
		result = [NSString stringWithFormat:@"Special - %@", self.episodeTitle];
	else
		result = [NSString stringWithFormat:@"S%@E%@ - %@",
				  [TRBTVShowNumberFormatter stringFromNumber:self.seasonNumber], [TRBTVShowNumberFormatter stringFromNumber:self.episodeNumber], self.episodeTitle];
	return result;
}

- (NSString *)niceSearchString {
	NSString * result = @"";
	if (![self.seasonNumber integerValue])
		result = [NSString stringWithFormat:@"%@ %@", self.season.series.title, self.episodeTitle];
	else
		result = [NSString stringWithFormat:@"%@ S%@E%@",
				  self.season.series.title, [TRBTVShowNumberFormatter stringFromNumber:self.seasonNumber], [TRBTVShowNumberFormatter stringFromNumber:self.episodeNumber]];
	return result;
}

- (NSDate *)localizedAirDate {
	NSDate * result = nil;
	if (self.airDate) {
		NSCalendar * calendar = [NSCalendar currentCalendar];
		NSDate * airTime = [self.season.series.airsTime dateFromInputFormat:@"hh:mm a"];
		if (airTime) {
			NSDateComponents * timeComps = [calendar components:NSHourCalendarUnit|NSMinuteCalendarUnit fromDate:airTime];
			result = [calendar dateByAddingComponents:timeComps toDate:self.airDate options:0];
		}
	}
	return result;
}

- (void)scheduleLocalNotification {
	NSDate * airDate = [self localizedAirDate];
	NSDate * now = [NSDate date];
	if ([now timeIntervalSinceReferenceDate] < [airDate timeIntervalSinceReferenceDate]) {
		UILocalNotification * notification = [UILocalNotification new];
		notification.fireDate = airDate;
		notification.timeZone = [NSTimeZone localTimeZone];
		notification.alertBody = [NSString stringWithFormat:@"%@ - %@", self.season.series.title, [self niceTitle]];
		notification.userInfo = @{@"episodeID": self.episodeID,
								  @"seriesID": self.season.series.seriesID,
								  @"episodeNumber": self.episodeNumber,
								  @"seasonNumber": self.seasonNumber,
								  @"seriesTitle": self.season.series.title};
		self.notificationScheduled = @YES;
		[[UIApplication sharedApplication] scheduleLocalNotification:notification];
	}
}

@end
