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

#import "NSString+TRBUnits.h"

@implementation NSString (TRBUnits)

+ (NSString *)stringWithByteCount:(long long)count {
	return [NSByteCountFormatter stringFromByteCount:count countStyle:NSByteCountFormatterCountStyleFile];
}

+ (NSString *)stringWithTransferRate:(long long)rate {
	return [NSString stringWithFormat:@"%@/s", [NSByteCountFormatter stringFromByteCount:rate countStyle:NSByteCountFormatterCountStyleFile]];
}

+ (NSString *)stringWithDate:(NSDate *)date andOutputStyle:(NSDateFormatterStyle)style {
	return [self stringWithDate:date dateOutputStyle:style andTimeOutputStyle:NSDateFormatterNoStyle];
}

+ (NSString *)stringWithDate:(NSDate *)date dateOutputStyle:(NSDateFormatterStyle)style1 andTimeOutputStyle:(NSDateFormatterStyle)style2 {
	NSDateFormatter * formatter = [NSDateFormatter new];
	[formatter setLocale:[NSLocale currentLocale]];
	[formatter setDateStyle:style1];
	[formatter setTimeStyle:style2];
	[formatter setTimeZone:[NSTimeZone localTimeZone]];
	return [formatter stringFromDate:date];
}

- (NSDate *)dateFromInputFormat:(NSString *)format {
	return [self dateFromInputFormat:format withLocale:nil andTimezone:nil];
}

- (NSDate *)dateFromInputFormat:(NSString *)format withLocale:(NSLocale *)locale {
	return [self dateFromInputFormat:format withLocale:locale andTimezone:nil];
}

- (NSDate *)dateFromInputFormat:(NSString *)format withLocale:(NSLocale *)locale andTimezone:(NSTimeZone *)timezone {
	NSDateFormatter * formatter = [NSDateFormatter new];
	if (!locale)
		locale = [NSLocale currentLocale];
	if (!timezone)
		timezone = [NSTimeZone localTimeZone];
	[formatter setDateFormat:format];
	[formatter setLocale:locale];
	[formatter setTimeZone:timezone];
	return [formatter dateFromString:self];
}

// Thu, 01 Dec 2005 19:35:18 GMT
- (NSString *)shortDateFromInputFormat:(NSString *)format {
	return [self dateStringFromInputFormat:format
							   outputStyle:NSDateFormatterShortStyle
								  inLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"]
							  andOutLocale:[NSLocale currentLocale]];
}

- (NSString *)dateStringFromInputFormat:(NSString *)format andOutputStyle:(NSDateFormatterStyle)style {
	return [self dateStringFromInputFormat:format outputStyle:style inLocale:nil andOutLocale:nil];
}

- (NSString *)dateStringFromInputFormat:(NSString *)format outputStyle:(NSDateFormatterStyle)style inLocale:(NSLocale *)inLocale andOutLocale:(NSLocale *)outLocale {
	NSDateFormatter * formatter = [NSDateFormatter new];
	if (!inLocale)
		inLocale = [NSLocale currentLocale];
	if (!outLocale)
		outLocale = [NSLocale currentLocale];
	[formatter setDateFormat:format];
	[formatter setLocale:inLocale];
	NSDate * date = [formatter dateFromString:self];
	[formatter setLocale:outLocale];
	[formatter setDateStyle:style];
	[formatter setTimeZone:[NSTimeZone localTimeZone]];
	return [formatter stringFromDate:date];
}

@end
