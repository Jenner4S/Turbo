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

#import "TRBTvDBClient.h"
#import "TRBTVShowsStorage.h"
#import "TRBTVShow.h"
#import "TRBTVShowSeason.h"
#import "TRBTVShowSeason+TRBAdditions.h"
#import "TRBTVShowEpisode.h"
#import "TRBTVShowEpisode+TRBAddtions.h"
#import "TRBXMLElement.h"
#import "TRBHTTPSession.h"
#import "TRBDataCache.h"
#import "NSString+TRBUnits.h"
#import "ZipArchive.h"
#import "API_KEYS.h"

static NSString * const TRBLastDBUpdateKey = @"TRBLastDBUpdate";

@implementation TRBTvDBClient {
	TRBHTTPSession * _session;
	NSURL * _baseURL;
	NSString * _apiKey;
	TRBHTTPRequestBuilder * _requestBuilder;
	TRBHTTPXMLResponseParser * _responseParser;
}

+ (instancetype)sharedInstance {
	static id sharedInstance = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedInstance = [[self alloc] init];
	});
	return sharedInstance;
}

- (instancetype)init {
	self = [super init];
	if (self) {
		_session = [[TRBHTTPSession alloc] initWithConfiguration:nil];
		_session.acceptedHTTPStatusCodes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(200, 100)];
		_baseURL = [NSURL URLWithString:@"http://thetvdb.com"];
		_apiKey = TvDBAPIKey; // to load from a file
		_requestBuilder = [TRBHTTPRequestBuilder new];
		_responseParser = [TRBHTTPXMLResponseParser new];
	}
	return self;
}

#pragma mark - Public Methods

- (void)searchSeriesWithTitle:(NSString *)title completion:(TRBXMLResultBlock)completion {
	NSError * error = nil;
	NSURL * URL = [NSURL URLWithString:@"api/GetSeries.php" relativeToURL:_baseURL];
	NSURLRequest * request = [_requestBuilder buildRequest:[NSMutableURLRequest requestWithURL:URL]
												parameters:@{@"seriesname": title} error:&error];
	if (!error)
		[self sendTvDBRequest:request completion:completion];
	else
		completion(nil, error);
}

- (void)fetchSeriesInfoWithID:(NSString *)seriesID completion:(TRBXMLResultBlock)completion {
	NSString * URLString = [NSString stringWithFormat:@"api/%@/series/%@", _apiKey, seriesID];
	NSURL * URL = [NSURL URLWithString:URLString relativeToURL:_baseURL];
	[self sendTvDBRequest:[NSMutableURLRequest requestWithURL:URL] completion:completion];
}

- (void)downloadAndSaveFullSeriesRecordWithID:(NSString *)seriesID overwrite:(BOOL)overwrite completion:(void(^)(TRBTVShow * tvShow, NSError * error))completion {
	NSString * URLString = [NSString stringWithFormat:@"api/%@/series/%@/all/en.zip", _apiKey, seriesID];
	NSURL * URL = [NSURL URLWithString:URLString relativeToURL:_baseURL];
	NSURLRequest * request = [NSURLRequest requestWithURL:URL];
	[_session downloadRequest:request progress:NULL completion:^(NSURL *location, NSURLResponse *response, NSError *error) {
		LogCE(error != nil, [error localizedDescription]);
		if (location && !error) {
			NSURL * moveLocation = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.zip", seriesID]]];
			if ([[NSFileManager defaultManager] moveItemAtURL:location toURL:moveLocation error:&error]) {
				NSString * filePath = [moveLocation path];
				ZipArchive * archive = [ZipArchive new];
				[archive UnzipOpenFile:filePath];
				NSRange range = [filePath rangeOfString:@".zip" options:NSBackwardsSearch];
				NSString * unzipDir = [filePath stringByReplacingCharactersInRange:range withString:@""];
				BOOL isDir = NO;
				if ([[NSFileManager defaultManager] fileExistsAtPath:unzipDir isDirectory:&isDir])
					[[NSFileManager defaultManager] removeItemAtPath:unzipDir error:&error];
				LogCE(error != nil, [error localizedDescription]);
				[archive UnzipFileTo:unzipDir overWrite:YES];
				[[NSFileManager defaultManager] removeItemAtURL:moveLocation error:&error];
				[self processRecordsInDir:unzipDir overwrite:overwrite completion:completion];
			} else if (completion)
				completion(nil, error);
		} else if (completion)
			completion(nil, error);
	}];
}

- (void)updateSeriesRecordsWithCompletion:(void(^)(void))completion {
	[[TRBTVShowsStorage sharedInstance] fetchStaleTVShowsWithHandler:^(NSArray * results) {
		if ([results count]) {
			__block UIBackgroundTaskIdentifier bkgrdTaskID = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
				[[TRBTVShowsStorage sharedInstance] save];
				[[UIApplication sharedApplication] endBackgroundTask:bkgrdTaskID];
				bkgrdTaskID = UIBackgroundTaskInvalid;
			}];
			NSMutableSet * remaining = [NSMutableSet setWithArray:results];
			for (TRBTVShow * tvShow in results) {
				[self downloadAndSaveFullSeriesRecordWithID:[tvShow.seriesID description] overwrite:YES completion:^(TRBTVShow * updated, NSError *error) {
					[remaining removeObject:tvShow];
					if (![remaining count]) {
						[self scheduleEpisodeNotifications];
						if (completion)
							completion();
						if (bkgrdTaskID != UIBackgroundTaskInvalid) {
							[[UIApplication sharedApplication] endBackgroundTask:bkgrdTaskID];
							bkgrdTaskID = UIBackgroundTaskInvalid;
						}
					}
				}];
			}
		} else if (completion)
			completion();
	}];
}

- (void)fetchSeriesBannersWithID:(NSString *)seriesID completion:(TRBXMLResultBlock)completion {
	NSString * URLString = [NSString stringWithFormat:@"api/%@/series/%@/banners.xml", _apiKey, seriesID];
	NSURL * URL = [NSURL URLWithString:URLString relativeToURL:_baseURL];
	[self sendTvDBRequest:[NSMutableURLRequest requestWithURL:URL] completion:completion];
}

- (void)fetchSeriesActorsWithID:(NSString *)seriesID completion:(TRBXMLResultBlock)completion {
	NSString * URLString = [NSString stringWithFormat:@"api/%@/series/%@/actors.xml", _apiKey, seriesID];
	NSURL * URL = [NSURL URLWithString:URLString relativeToURL:_baseURL];
	[self sendTvDBRequest:[NSMutableURLRequest requestWithURL:URL] completion:completion];
}

- (void)fetchSeriesBannerAtPath:(NSString *)path completion:(TRBImageResultBlock)completion {
	[[TRBDataCache sharedInstance] lookupDataWithDomain:@"TvDB" path:path andHandler:^(NSData *data, NSError *error) {
		if (data && completion) {
			completion([UIImage imageWithData:data scale:[UIScreen mainScreen].scale], nil);
		} else {
			NSString * URLString = [@"banners" stringByAppendingPathComponent:path];
			NSURL * URL = [NSURL URLWithString:URLString relativeToURL:_baseURL];
			NSURLRequest * request = [NSURLRequest requestWithURL:URL];
			[_session startRequest:request parser:nil completion:^(id data, NSURLResponse *response, NSError *error) {
				if (!error && completion) {
					NSData * imageData = data;
					[[TRBDataCache sharedInstance] storeData:imageData withDomain:@"TvDB" andPath:path];
					UIImage * downloadedImage = [UIImage imageWithData:imageData scale:[UIScreen mainScreen].scale];
					completion(downloadedImage, nil);
				} else if (completion) {
					if (!error) {
						error = [NSError errorWithDomain:NSURLErrorDomain
													code:NSURLErrorBadServerResponse
												userInfo:@{NSLocalizedDescriptionKey: @"Unsupported Status Code"}];
					}
					completion(nil, error);
				}
			}];
		}
	}];
}

#pragma mark - Private Methods

- (void)sendTvDBRequest:(NSURLRequest *)request completion:(void(^)(id result, NSError * error))completion {
	[_session startRequest:request
					parser:_responseParser
				completion:^(id data, NSURLResponse *response, NSError *error) {
					if (!error && completion) {
						completion(data, nil);
					} else if (completion) {
						if (!error) {
							error = [NSError errorWithDomain:NSURLErrorDomain
														code:NSURLErrorBadServerResponse
													userInfo:@{NSLocalizedDescriptionKey: @"Unsupported Status Code"}];
						}
						completion(nil, error);
					}
				}];
}

- (void)processRecordsInDir:(NSString *)unzipDir overwrite:(BOOL)overwrite completion:(void (^)(TRBTVShow * tvShow, NSError * error))completion {
    TRBXMLElement * fullRecord = [TRBXMLElement XMLElementWithContentsOfFile:[unzipDir stringByAppendingPathComponent:@"en.xml"]];
	NSArray * records = [fullRecord children];
    if ([records count]) {
		[[TRBTVShowsStorage sharedInstance] updateTVShowWithRecords:records andHandler:^(TRBTVShow * result){
			TRBXMLElement * bannerRecord = [TRBXMLElement XMLElementWithContentsOfFile:[unzipDir stringByAppendingPathComponent:@"banners.xml"]];
			NSArray * banners = [bannerRecord children];
			[[TRBTVShowsStorage sharedInstance] updateTVShowBannersWithRecords:banners forTVShow:result.objectID andHandler:^{
				if (completion)
					completion(result, nil);
				[[NSFileManager defaultManager] removeItemAtPath:unzipDir error:NULL];
			}];
		}];
    } else if (completion) {
        [[NSFileManager defaultManager] removeItemAtPath:unzipDir error:NULL];
        NSError * error = [NSError errorWithDomain:NSStringFromClass([self class])
                                              code:-1337
                                          userInfo:@{NSLocalizedDescriptionKey: @"Bad data"}];
        completion(nil, error);
    }
}

- (void)scheduleEpisodeNotifications {
	BOOL notificationsDisabled = [[NSUserDefaults standardUserDefaults] boolForKey:TRBTVShowNotificationsKey];
	if (!notificationsDisabled) {
		[[TRBTVShowsStorage sharedInstance] fetchAllNextEpisodesWithHandler:^(NSArray *results) {
			for (TRBTVShowEpisode * episode in results)
				[episode scheduleLocalNotification];
			[[TRBTVShowsStorage sharedInstance] save];
		}];
	}
}

- (void)removeEpisodeNotifications {
	[[TRBTVShowsStorage sharedInstance] fetchAllScheduledEpisodesWithHandler:^(NSArray *results) {
		for (TRBTVShowEpisode * episode in results)
			episode.notificationScheduled = @NO;
		[[TRBTVShowsStorage sharedInstance] save];
	}];
	[[UIApplication sharedApplication] cancelAllLocalNotifications];
}

@end
