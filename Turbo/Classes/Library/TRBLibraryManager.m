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

#import "TRBLibraryManager.h"
#import "TRBHTTPSession.h"
#import "TRBDataCache.h"
#import "KeychainItemWrapper.h"

static NSDictionary * VSPosterDomainMapper = nil;

@interface TRBLibraryManager ()<UIAlertViewDelegate>
@property (nonatomic, readonly) NSString * baseURL;
@end

@implementation TRBLibraryManager {
	NSString * _baseURL;
	TRBHTTPSession * _session;
	void(^_authCompletion)(NSError * error);
	TRBHTTPRequestBuilder * _requestBuilder;
	TRBHTTPJSONResponseParser * _jsonParser;
}

+ (void)initialize {
	VSPosterDomainMapper = @{@"movie": @"VS",
							 @"tvshow": @"VS-TVShow",
							 @"tvshow_episode": @"VS-TVShowEpisode"};
}

+ (instancetype)sharedManager {
	static TRBLibraryManager * sharedInstance = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedInstance = [[self alloc] init];
	});
	return sharedInstance;
}

- (id)init {
    self = [super init];
    if (self) {
		_session = [[TRBHTTPSession alloc] initWithConfiguration:nil];
		_session.acceptedHTTPStatusCodes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(200, 100)];
		_port = 80;
		_requestBuilder = [TRBHTTPRequestBuilder new];
		_jsonParser = [TRBHTTPJSONResponseParser new];
		[_jsonParser.acceptedMIMETypes addObject:@"text/plain"];
    }
    return self;
}

- (NSString *)baseURL {
	if (!_baseURL) {
		NSString * host = _host;
		if ([host hasSuffix:@"."])
			host = [host substringToIndex:[host length] - 1];
		_baseURL = [NSString stringWithFormat:@"http://%@:%ld", host, (long)_port];
	}
	return _baseURL;
}

- (void)setHost:(NSString *)host {
	_baseURL = nil;
	_host = host;
}

- (void)setPort:(NSInteger)port {
	_baseURL = nil;
	_port = port;
}

#pragma mark - Authentication

- (void)startAuthenticationCompletion:(void(^)(NSError * error))completion {
	KeychainItemWrapper * kw = [KeychainItemWrapper keychainItemForIdentifier:self.baseURL accessGroup:nil];
	NSString * username = kw[(__bridge id)kSecAttrAccount];
	NSString * password = kw[(__bridge id)kSecValueData];
	if (![username length] || ![password length]) {
		UIAlertView * alert = [[UIAlertView alloc] initWithTitle:@"Login"
														 message:@"Provide credential"
														delegate:self
											   cancelButtonTitle:@"cancel"
											   otherButtonTitles:@"Login", nil];
		alert.alertViewStyle = UIAlertViewStyleLoginAndPasswordInput;
		[alert show];
		_authCompletion = [completion copy];
	} else
		[self loginWithUsername:username password:password completion:completion];
}

#pragma mark - Movies

- (void)fetchMovieListWithOffest:(NSUInteger)offset
						   limit:(NSUInteger)limit
						  sortBy:(NSString *)sort
						   order:(NSString *)order
						 filters:(NSDictionary *)filters
					  completion:(void(^)(NSDictionary * json, NSError * error))completion {
	NSParameterAssert(completion);
	NSMutableDictionary * parameters = [@{@"offset": [@(offset) description],
										  @"limit": [@(limit) description],
										  @"sort_by": sort,
										  @"sort_direction": order,
										  @"additional": @"poster_mtime,tagline,genre",
										  @"library_id": @"0",
										  @"method": @"list",
										  @"recently_added": @"0",
										  @"api": @"SYNO.VideoStation.Movie",
										  @"version": @"1"} mutableCopy];
	[parameters addEntriesFromDictionary:filters];
	[_session POST:[NSString stringWithFormat:@"%@/webapi/VideoStation/movie.cgi", self.baseURL]
		parameters:parameters
		   builder:_requestBuilder
			parser:_jsonParser
		completion:^(NSDictionary * data, NSURLResponse * response, NSError * error) {
			if (!error && ![data[@"success"] boolValue])
				error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorUnknown userInfo:@{NSLocalizedDescriptionKey: @"Unknown Error"}];
			completion(data, error);
		}];
}

- (void)searchMovietWithKeyword:(NSString *)keyword
						 offest:(NSUInteger)offset
						  limit:(NSUInteger)limit
						 sortBy:(NSString *)sort
						  order:(NSString *)order
					 completion:(void(^)(NSDictionary * json, NSError * error))completion {
	NSParameterAssert(completion);
	NSDictionary * keywords = @{@"title": keyword, @"actor": keyword, @"director": keyword, @"writer": keyword, @"gnere": keyword};
	NSString * keywordString = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:keywords options:kNilOptions error:NULL] encoding:NSUTF8StringEncoding];
	keywordString = [keywordString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	NSDictionary * parameters = @{@"keywords": keywordString,
								  @"offset": [@(offset) description],
								  @"limit": [@(limit) description],
								  @"sort_by": sort,
								  @"sort_direction": order,
								  @"additional": @"poster_mtime,tagline,genre",
								  @"library_id": @"0",
								  @"method": @"search",
								  @"api": @"SYNO.VideoStation.Movie",
								  @"version": @"1"};
	[_session POST:[NSString stringWithFormat:@"%@/webapi/VideoStation/movie.cgi", self.baseURL]
		parameters:parameters
		   builder:_requestBuilder
			parser:_jsonParser
		completion:^(NSDictionary * data, NSURLResponse * response, NSError * error) {
			if (!error && ![data[@"success"] boolValue])
				error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorUnknown userInfo:@{NSLocalizedDescriptionKey: @"Unknown Error"}];
			completion(data, error);
		}];
}

- (void)fetchMovieDetailsForID:(NSString *)movieID completion:(void (^)(NSDictionary *, NSError *))completion {
	NSParameterAssert(completion);
	NSDictionary * parameters = @{@"api": @"SYNO.VideoStation.Movie",
								  @"version": @"1",
								  @"method": @"getinfo",
								  @"id": movieID,
								  @"additional": @"summary,files,actor,writer,director,extra,collection"};
	[_session POST:[NSString stringWithFormat:@"%@/webapi/VideoStation/movie.cgi", self.baseURL]
		parameters:parameters
		   builder:_requestBuilder
			parser:_jsonParser
		completion:^(NSDictionary * data, NSURLResponse * response, NSError * error) {
			if (!error && ![data[@"success"] boolValue])
				error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorUnknown userInfo:@{NSLocalizedDescriptionKey: @"Unknown Error"}];
			completion(data, error);
		}];
}

#pragma mark - TVShows

- (void)fetchTVShowListWithOffest:(NSUInteger)offset
							limit:(NSUInteger)limit
						   sortBy:(NSString *)sort
							order:(NSString *)order
					   completion:(void(^)(NSDictionary * json, NSError * error))completion {
	NSParameterAssert(completion);
	NSDictionary * parameters = @{@"offset": [@(offset) description],
								  @"limit": [@(limit) description],
								  @"sort_by": sort,
								  @"sort_direction": order,
								  @"additional": @"poster_mtime,summary",
								  @"library_id": @"0",
								  @"method": @"list",
								  @"recently_added": @"0",
								  @"api": @"SYNO.VideoStation.TVShow",
								  @"version": @"1"};
	[_session POST:[NSString stringWithFormat:@"%@/webapi/VideoStation/tvshow.cgi", self.baseURL]
		parameters:parameters
		   builder:_requestBuilder
			parser:_jsonParser
		completion:^(NSDictionary * data, NSURLResponse * response, NSError * error) {
			if (!error && ![data[@"success"] boolValue])
				error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorUnknown userInfo:@{NSLocalizedDescriptionKey: @"Unknown Error"}];
			completion(data, error);
		}];
}

- (void)fetchTVShowEpisodeListForID:(NSString *)tvShowID completion:(void(^)(NSDictionary * json, NSError * error))completion {
	NSParameterAssert(completion);
	NSDictionary * parameters = @{@"api": @"SYNO.VideoStation.TVShowEpisode",
								  @"version": @"1",
								  @"method": @"list",
								  @"tvshow": tvShowID,
								  @"additional": @"summary,collection,poster_mtime",
								  @"library_id": @"0",
								  @"recently_added": @"0"};
	[_session POST:[NSString stringWithFormat:@"%@/webapi/VideoStation/tvshow_episode.cgi", self.baseURL]
		parameters:parameters
		   builder:_requestBuilder
			parser:_jsonParser
		completion:^(NSDictionary * data, NSURLResponse * response, NSError * error) {
			if (!error && ![data[@"success"] boolValue])
				error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorUnknown userInfo:@{NSLocalizedDescriptionKey: @"Unknown Error"}];
			completion(data, error);
		}];
}

#pragma mark - Posters

- (void)fetchPosterForMovieID:(NSString *)movieID completion:(void(^)(UIImage * image, NSError * error))completion {
	[self fetchPosterForID:movieID type:@"movie" completion:completion];
}

- (void)fetchPosterForTVShowID:(NSString *)tvShowID completion:(void(^)(UIImage * image, NSError * error))completion {
	[self fetchPosterForID:tvShowID type:@"tvshow" completion:completion];
}

- (void)fetchPosterForTVShowEpisodeID:(NSString *)tvShowEpisodeID completion:(void(^)(UIImage * image, NSError * error))completion {
	[self fetchPosterForID:tvShowEpisodeID type:@"tvshow_episode" completion:completion];
}

#pragma mark - Metadata

- (void)fetchMetadataForType:(NSString *)type category:(NSString *)category completion:(void(^)(NSDictionary * json, NSError * error))completion {
	NSDictionary * parameters = @{@"api": @"SYNO.VideoStation.Metadata",
								  @"version": @"1",
								  @"method": @"list",
								  @"type": type,
								  @"category": category,
								  @"library_id": @"0",
								  @"sort_by": category,
								  @"sort_direction": [category isEqualToString:@"year"] ? @"desc" : @"asc"};
	[_session POST:[NSString stringWithFormat:@"%@/webapi/VideoStation/metadata.cgi", self.baseURL]
		parameters:parameters
		   builder:_requestBuilder
			parser:_jsonParser
		completion:^(NSDictionary * data, NSURLResponse *response, NSError *error) {
			if (!error && ![data[@"success"] boolValue])
				error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorUnknown userInfo:@{NSLocalizedDescriptionKey: @"Unknown Error"}];
			completion(data, error);
		}];
}

#pragma mark - UIAlertViewDelegate Implementation

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
	switch (buttonIndex) {
		case 0:
			// cancel
			break;
		case 1: {
			NSString * usr = [alertView textFieldAtIndex:0].text;
			NSString * pwd = [alertView textFieldAtIndex:1].text;
			[self loginWithUsername:usr password:pwd completion:_authCompletion];
			_authCompletion = nil;
			break;
		} default:
			break;
	}
}

#pragma mark - Private Methods

- (void)loginWithUsername:(NSString *)usr password:(NSString *)pwd completion:(void(^)(NSError * error))completion {
	NSString * URL = [NSString stringWithFormat:@"%@/webapi/auth.cgi", self.baseURL];
	[_session GET:URL
	   parameters:@{@"api": @"SYNO.API.Auth", @"version": @"2", @"method": @"login", @"account": usr, @"passwd": pwd, @"session": @"VideoStation", @"format": @"cookie"}
		  builder:_requestBuilder
		   parser:_jsonParser
	   completion:^(NSDictionary * json, NSURLResponse *response, NSError *error) {
		   KeychainItemWrapper * kw = [KeychainItemWrapper keychainItemForIdentifier:self.baseURL accessGroup:nil];
		   if (!error) {
			   _authenticated = [json[@"success"] boolValue];
			   if (_authenticated) {
				   kw[(__bridge id)kSecAttrAccount] = usr;
				   kw[(__bridge id)kSecValueData] = pwd;
			   } else
				   error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorUnknown userInfo:@{NSLocalizedDescriptionKey: @"Unknown Error"}];
		   }
		   if (error) {
			   kw[(__bridge id)kSecAttrAccount] = @"";
			   kw[(__bridge id)kSecValueData] = @"";
		   }
		   if (completion)
			   completion(error);
	   }];
}

- (void)fetchPosterForID:(NSString *)pid type:(NSString *)type completion:(void(^)(UIImage * image, NSError * error))completion {
	NSParameterAssert(completion);
	[[TRBDataCache sharedInstance] lookupDataWithDomain:VSPosterDomainMapper[type] path:pid andHandler:^(NSData * data, NSError *error) {
		if (data) {
			UIImage * image = [UIImage imageWithData:data scale:[UIScreen mainScreen].scale];
			completion(image, nil);
		} else {
			NSDictionary * parameters = @{@"api": @"SYNO.VideoStation.Poster",
										  @"version": @"1",
										  @"method": @"getimage",
										  @"id": pid,
										  @"type": type};
			[_session GET:[NSString stringWithFormat:@"%@/webapi/VideoStation/poster.cgi", self.baseURL]
			   parameters:parameters
				  builder:_requestBuilder
				   parser:nil
			   completion:^(NSData * data, NSURLResponse *response, NSError *error) {
				   UIImage * image = nil;
				   if (!error) {
					   image = [UIImage imageWithData:data scale:[UIScreen mainScreen].scale];
					   if (image)
						   [[TRBDataCache sharedInstance] storeData:data withDomain:@"VS" andPath:pid];
					   else
						   error = [NSError errorWithDomain:@"TRBLibraryManager" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Failed to create UIImage object"}];
				   }
				   completion(image, error);
			   }];
		}
	}];
}

@end
