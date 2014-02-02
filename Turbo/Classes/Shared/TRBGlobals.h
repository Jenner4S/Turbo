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

@import Foundation;

@class TRBXMLElement;

#define isIdiomPhone ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
#define isIdiomPad ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)

// Searches

static NSString * const TRBTorrentzSearchNotification = @"TRBTorrentzSearch";
static NSString * const TRBMovieSearchNotification = @"TRBMovieSearch";
static NSString * const TRBTVShowSearchNotification = @"TRBTVShowSearch";
static NSString * const TRBTVShowNotification = @"TRBTVShow";
static NSString * const TRBTVShowEpisodeKey = @"TRBTVShowEpisode";
static NSString * const TRBSearchQueryKey = @"TRBSearchQuery";

// Settings

static NSString * const TRBSettingsUpdatedNotification = @"TRBSettingsUpdated";
static NSString * const TRBWiFiRefreshRateKey = @"TRBWiFiRefreshRate";
static NSString * const TRBCellularRefreshRateKey = @"TRBCellularRefreshRate";
static NSString * const TRBIMDbSearchWebOnlyKey = @"TRBIMDbSearchWebOnlyApp";
static NSString * const TRBTVShowInfoRefreshRateKey = @"TRBTVShowInfoRefreshRate";
static NSString * const TRBTVShowNotificationsKey = @"TRBTVShowNotifications";
static NSString * const TRBSynologyHostKey = @"TRBSynologyHost";
static NSString * const TRBSynologyPortKey = @"TRBSynologyPort";

// Common Blocks

typedef void(^TRBJSONResultBlock)(NSDictionary * json, NSError * error);
typedef void(^TRBXMLResultBlock)(TRBXMLElement * xml, NSError * error);
typedef void(^TRBImageResultBlock)(UIImage * image, NSError * error);

__attribute__((always_inline)) static inline void _Log(const char * function, int line, id fmt, ...);
__attribute__((always_inline)) static inline void _LogC(const char * function, int line, BOOL condition, id fmt, ...);

#define _WarningFmt @"\n[WARNING]\n"
#define _ErrorFmt @"\n[ERROR]\n"
#define _InfoFmt @"\n[INFO]\n"

#ifndef TRBDebug
#	define LogV(fmt, ...)
#	define LogCV(condition, fmt, ...)
#	define LogI(fmt, ...)
#	define LogCI(condition, fmt, ...)
#	define LogW(fmt, ...)
#	define LogCW(condition, fmt, ...)
#	define LogE(fmt, ...)
#	define LogCE(condition, fmt, ...)
#else
#	define LogV(fmt, ...)				_Log(__PRETTY_FUNCTION__, __LINE__, fmt, ##__VA_ARGS__)
#	define LogCV(condition, fmt, ...)	_LogC(__PRETTY_FUNCTION__, __LINE__, condition, fmt, ##__VA_ARGS__)
#	define LogI(fmt, ...)				_Log(__PRETTY_FUNCTION__, __LINE__, [_InfoFmt stringByAppendingString:(fmt)], ##__VA_ARGS__)
#	define LogCI(condition, fmt, ...)	_LogC(__PRETTY_FUNCTION__, __LINE__, condition, [_InfoFmt stringByAppendingString:((fmt) ? [fmt description] : @"")], ##__VA_ARGS__)
#	define LogW(fmt, ...)				_Log(__PRETTY_FUNCTION__, __LINE__, [_WarningFmt stringByAppendingString:(fmt)], ##__VA_ARGS__)
#	define LogCW(condition, fmt, ...)	_LogC(__PRETTY_FUNCTION__, __LINE__, condition, [_WarningFmt stringByAppendingString:((fmt) ? [fmt description] : @"")], ##__VA_ARGS__)
#	define LogE(fmt, ...)				_Log(__PRETTY_FUNCTION__, __LINE__, [_ErrorFmt stringByAppendingString:((fmt) ? [fmt description] : @"")], ##__VA_ARGS__)
#	define LogCE(condition, fmt, ...)	_LogC(__PRETTY_FUNCTION__, __LINE__, condition, [_ErrorFmt stringByAppendingString:((fmt) ? [fmt description] : @"")], ##__VA_ARGS__)
#endif

__attribute__((always_inline)) static inline void  _Log(const char * function, int line, id fmt, ...) {
	va_list args;
	va_start(args, fmt);
	fmt = [NSString stringWithFormat:@"[%s][line %d] %@", function, line, ((fmt) ? [(fmt) description] : @"")];
	NSLogv(fmt, args);
	va_end(args);
}

__attribute__((always_inline)) static inline void _LogC(const char * function, int line, BOOL condition, id fmt, ...) {
	if (condition) {
		va_list args;
		va_start(args, fmt);
		fmt = [NSString stringWithFormat:@"[%s][line %d] %@", function, line, ((fmt) ? [(fmt) description] : @"")];
		NSLogv(fmt, args);
		va_end(args);
	}
}

__attribute__((always_inline)) static inline NSString * TRBLibraryDir() {
	NSString * libraryDirectory = nil;
	NSArray * paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
	if ([paths count])
		libraryDirectory = paths[0];
	return libraryDirectory;
}

__attribute__((always_inline)) static inline void TRBDumpRequestToConsole(NSURLRequest * request) {
	NSMutableString * message = [[NSMutableString alloc] initWithString:@"*** REQUEST ***"];
	[message appendString:[NSString stringWithFormat:@"\nHTTP Method: %@", [request HTTPMethod]]];
	[message appendString:[NSString stringWithFormat:@"\nURL: %@", [[request URL] absoluteString]]];
	[message appendString:[NSString stringWithFormat:@"\nHeaders: %@",[request allHTTPHeaderFields]]];
	NSData * body = [request HTTPBody];
	if ([body length]) {
		NSString * bodyString = [[NSString alloc] initWithData:body encoding:NSASCIIStringEncoding];
		[message appendString:[NSString stringWithFormat:@"\nBody:\n%@", bodyString]];
	}
	LogI(@"%@", message);
}

__attribute__((always_inline)) static inline void TRBDumpResponseToConsole(NSHTTPURLResponse * response) {
	if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
		NSMutableString * message = [[NSMutableString alloc] initWithString:@"*** RESPONSE ***"];
		[message appendString:[NSString stringWithFormat:@"\nHTTP Status Code: %ld %@", (long)[response statusCode],
								  [NSHTTPURLResponse localizedStringForStatusCode:[response statusCode]]]];
		[message appendString:[NSString stringWithFormat:@"\nURL: %@", [[response URL] absoluteString]]];
		[message appendString:[NSString stringWithFormat:@"\nHeaders: %@", [response allHeaderFields]]];
		LogI(@"%@", message);
	}
}

__attribute__((always_inline)) static inline void TRBDumpResponseDataToConsole(NSData * data) {
	NSString * responseString = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
	LogCI([responseString length], @"Response string:\n%@", responseString);
}
