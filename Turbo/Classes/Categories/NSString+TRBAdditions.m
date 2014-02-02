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

#import "NSString+TRBAdditions.h"
#import "NSData+Base64.h"

#define kTVShowRegexes 3
#define kMovieRegexes 4

NSRange TRBRangeOfTVShowIdentifier(NSString * string) {
	NSRange result = NSMakeRange(NSNotFound, 0);
	NSRange searchRange = NSMakeRange(0, [string length]);
	NSRegularExpression * regexes[kTVShowRegexes];
	regexes[0] = [NSRegularExpression regularExpressionWithPattern:@" s[0-9]+e[0-9]+"
														   options:NSRegularExpressionCaseInsensitive
															 error:NULL];
	regexes[1] = [NSRegularExpression regularExpressionWithPattern:@" [0-9]+x[0-9]+"
														   options:NSRegularExpressionCaseInsensitive
															 error:NULL];
	regexes[2] = [NSRegularExpression regularExpressionWithPattern:@" season [0-9]+"
														   options:NSRegularExpressionCaseInsensitive
															 error:NULL];
	for (NSUInteger i = 0; i < kTVShowRegexes; i++) {
		result = [regexes[i] rangeOfFirstMatchInString:string options:0 range:searchRange];
		if (result.location != NSNotFound)
			break;
	}

	return result;
}


NSRange TRBRangeOfMovieIdentifier(NSString * string) {
	NSRange result = NSMakeRange(NSNotFound, 0);
	NSRange searchRange = NSMakeRange(0, [string length]);
	NSRegularExpression * regexes[kMovieRegexes];
	regexes[0] = [NSRegularExpression regularExpressionWithPattern:@"[\\W]*[12][90][0-9][0-9]"
														   options:NSRegularExpressionCaseInsensitive
															 error:NULL];
	regexes[1] = [NSRegularExpression regularExpressionWithPattern:@"[\\W]*(bd|br|dvd|hd|hq)rip"
														   options:NSRegularExpressionCaseInsensitive
															 error:NULL];
	regexes[2] = [NSRegularExpression regularExpressionWithPattern:@"[\\W]*bluray"
														   options:NSRegularExpressionCaseInsensitive
															 error:NULL];
	regexes[3] = [NSRegularExpression regularExpressionWithPattern:@"[\\W]*(720|1080)p"
														   options:NSRegularExpressionCaseInsensitive
															 error:NULL];
	for (NSUInteger i = 0; i < kMovieRegexes; i++) {
		NSRange match = [regexes[i] rangeOfFirstMatchInString:string options:0 range:searchRange];
		if (match.location < result.location)
			result = match;
	}

	return result;
}

@implementation NSString (TRBAdditions)

- (NSString *)beautifyTorrentName {
	NSString * result = self;
	result = [[result stringByTrimmingCharactersInSet:[[NSCharacterSet alphanumericCharacterSet] invertedSet]] stringByReplacingOccurrencesOfString:@"." withString:@" "];
	NSRange range = TRBRangeOfTVShowIdentifier(result);
	if (range.location != NSNotFound || (range = TRBRangeOfMovieIdentifier(result)).location != NSNotFound)
		result = [result substringToIndex:range.location];
	return result;
}

- (NSData *)base64Data {
	NSData * selfData = [self dataUsingEncoding:NSUTF8StringEncoding];
	size_t outputLength = 0;
	char * outputBuffer = NewBase64Encode([selfData bytes], [selfData length], true, &outputLength);
	return [NSData dataWithBytesNoCopy:outputBuffer length:outputLength freeWhenDone:YES];
}

- (NSString *)schemeAndHost {
	NSString * result = nil;
	NSURL * url = [NSURL URLWithString:self];
	if (url)
		result = [NSString stringWithFormat:@"%@://%@", [url scheme], [url host]];
	return result;
}

- (NSString *)URLEncodedString {
    return (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(NULL, (__bridge CFStringRef)self, NULL, (__bridge CFStringRef)@"!*'();:@&=+$,/?%#[]", kCFStringEncodingUTF8));
}

@end
