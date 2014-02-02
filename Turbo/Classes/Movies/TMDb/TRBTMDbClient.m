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

#import "TRBTMDbClient.h"
#import "TRBMovie.h"
#import "TRBHTTPSession.h"
#import "NSString+Levenshtein.h"
#import "NSDictionary+TRBAdditions.h"
#import "API_KEYS.h"

static NSString * const TRBTMDbListEndpoints[TRBTMDbListTypeCount] = {
	@"movie/popular",
	@"movie/upcoming",
	@"movie/now_playing",
	@"movie/top_rated"
};

@implementation TRBTMDbClient {
	NSDictionary * _config;
	TRBHTTPSession * _session;
	TRBHTTPRequestBuilder * _requestBuilder;
	TRBHTTPJSONResponseParser * _responseParser;
	NSString * _apiKey;
	NSURL * _baseURL;
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
		_requestBuilder = [TRBHTTPRequestBuilder new];
		_responseParser = [TRBHTTPJSONResponseParser new];
		_baseURL = [NSURL URLWithString:@"http://api.themoviedb.org/3/"];
		_apiKey = TMDbAPIKey;
	}
	return self;
}

#pragma mark - Public Methods

- (void)fetchMovieList:(TRBTMDbListType)listType withPage:(NSUInteger)page completion:(TRBJSONResultBlock)completion {
	NSURL * URL = [NSURL URLWithString:TRBTMDbListEndpoints[listType] relativeToURL:_baseURL];
	NSURLRequest * request = [NSURLRequest requestWithURL:URL];
	NSDictionary * parameters = @{@"page": [NSString stringWithFormat:@"%lu", (unsigned long)page]};
	[self submitTMDbRequest:request withParameters:parameters completion:completion];
}

- (void)fetchMovieInfoWithID:(NSNumber *)movieID completion:(TRBJSONResultBlock)completion {
	NSString * URLString = [NSString stringWithFormat:@"movie/%@", movieID];
	NSURL * URL = [NSURL URLWithString:URLString relativeToURL:_baseURL];
	NSURLRequest * request = [NSURLRequest requestWithURL:URL];
	[self submitTMDbRequest:request withParameters:nil completion:completion];
}

- (void)fetchMovieTrailersWithID:(NSNumber *)movieID completion:(TRBJSONResultBlock)completion {
	NSString * URLString = [NSString stringWithFormat:@"movie/%@/trailers", movieID];
	NSURL * URL = [NSURL URLWithString:URLString relativeToURL:_baseURL];
	NSURLRequest * request = [NSURLRequest requestWithURL:URL];
	[self submitTMDbRequest:request withParameters:nil completion:completion];
}

- (void)fetchMovieImagesWithID:(NSNumber *)movieID completion:(TRBJSONResultBlock)completion {
	NSString * URLString = [NSString stringWithFormat:@"movie/%@/images", movieID];
	NSURL * URL = [NSURL URLWithString:URLString relativeToURL:_baseURL];
	NSURLRequest * request = [NSURLRequest requestWithURL:URL];
	[self submitTMDbRequest:request withParameters:nil completion:completion];
}

- (void)fetchMovieCastsWithID:(NSNumber *)movieID completion:(TRBJSONResultBlock)completion {
	NSString * URLString = [NSString stringWithFormat:@"movie/%@/casts", movieID];
	NSURL * URL = [NSURL URLWithString:URLString relativeToURL:_baseURL];
	NSURLRequest * request = [NSURLRequest requestWithURL:URL];
	[self submitTMDbRequest:request withParameters:nil completion:completion];
}

- (void)fetchPoster:(NSString *)poster withSize:(TRBTMDbPosterSize)size completion:(TRBImageResultBlock)completion {
	NSString * sizeString = _config[@"images"][@"poster_sizes"][size];
	[self fetchImageAtPath:poster withSize:sizeString completion:completion];
}

- (void)fetchBackdrop:(NSString *)backdrop withSize:(TRBTMDbBackdropSize)size completion:(TRBImageResultBlock)completion {
	NSString * sizeString = _config[@"images"][@"backdrop_sizes"][size];
	[self fetchImageAtPath:backdrop withSize:sizeString completion:completion];
}

- (void)fetchProfileImage:(NSString *)profile withSize:(TRBTMDbProfileSize)size completion:(TRBImageResultBlock)completion {
	NSString * sizeString = _config[@"images"][@"profile_sizes"][size];
	[self fetchImageAtPath:profile withSize:sizeString completion:completion];
}

- (void)searchMoviesWithQuery:(NSString *)query page:(NSUInteger)page completion:(TRBJSONResultBlock)completion {
	NSURL * URL = [NSURL URLWithString:@"search/movie" relativeToURL:_baseURL];
	NSURLRequest * request = [NSURLRequest requestWithURL:URL];
	NSDictionary * parameters = @{@"query": query, @"page": [NSString stringWithFormat:@"%lu", (unsigned long)page]};
	[self submitTMDbRequest:request withParameters:parameters completion:completion];
}

- (void)findMovieWithRTMovie:(TRBMovie *)rtMovie completion:(TRBJSONResultBlock)handler {
	NSString * movieToFind = rtMovie.title;
	if (handler) {
		[self searchMoviesWithQuery:movieToFind page:1 completion:^(NSDictionary *json, NSError * error) {
			NSArray * results = json[@"results"];
			NSMutableArray * possibleMatches = [[NSMutableArray alloc] initWithCapacity:[results count]];
			for (NSDictionary * result in results) {
				NSString * original_title = result[@"original_title"];
				NSString * title = result[@"title"];
				if ([original_title compareWithString:movieToFind] <= 10.0 || [title compareWithString:movieToFind] < 10.0)
					[possibleMatches addObject:result];
			}
			if ([possibleMatches count])
				[self fetchMovieInfoWithRTMovie:rtMovie forPossibleMatches:possibleMatches completion:handler];
			else {
				handler(nil, [NSError errorWithDomain:NSStringFromClass([self class])
												 code:1337
											 userInfo:@{NSLocalizedDescriptionKey: @"No match found"}]);
			}
		}];
	}
}

#pragma mark - Private Methods

- (void)fetchMovieInfoWithRTMovie:(TRBMovie *)rtMovie forPossibleMatches:(NSMutableArray *)possibleMatches completion:(TRBJSONResultBlock)completion {
	NSDictionary * possibleMatch = possibleMatches[0];
	[possibleMatches removeObjectAtIndex:0];
	[self fetchMovieInfoWithID:possibleMatch[@"id"] completion:^(NSDictionary * match, NSError *error) {
		NSString * imdbID = [match valueForKey:@"imdb_id" andIsKindOfClass:[NSString class]];
		NSString * releaseDate = [match valueForKey:@"release_date" andIsKindOfClass:[NSString class]];
		if ([imdbID isEqualToString:rtMovie.imdbID] || [releaseDate isEqualToString:rtMovie.releaseDate])
			completion(match, nil);
		else if ([possibleMatches count])
			[self fetchMovieInfoWithRTMovie:rtMovie forPossibleMatches:possibleMatches completion:completion];
		else {
			completion(nil, [NSError errorWithDomain:NSStringFromClass([self class])
												code:1337
											userInfo:@{NSLocalizedDescriptionKey: @"No match found"}]);
		}
	}];
}

- (void)fetchImageAtPath:(NSString *)imagePath withSize:(NSString *)size completion:(TRBImageResultBlock)completion {
	if (_config) {
		NSString * baseUrl = _config[@"images"][@"base_url"];
		NSString * urlString = [NSString stringWithFormat:@"%@%@%@", baseUrl, size, imagePath];
		[_session GET:urlString parameters:nil builder:nil parser:nil completion:^(id data, NSURLResponse *response, NSError *error) {
			if (!error && completion) {
				NSData * imageData = data;
				UIImage * downloadedImage = [UIImage imageWithData:imageData scale:[UIScreen mainScreen].scale];
				completion(downloadedImage, nil);
			} else if (completion) {
				if (!error) {
					error = [NSError errorWithDomain:NSURLErrorDomain
												code:NSURLErrorBadServerResponse
											userInfo:@{NSLocalizedDescriptionKey: @"Unsupported Status Code"}];
				}
				if (completion)
					completion(nil, error);
			}
		}];
	} else {
		[self fetchConfigWithCompletion:^(BOOL success, NSError *error) {
			if (success)
				[self fetchImageAtPath:imagePath withSize:size completion:completion];
			else {
				if (!error) {
					error = [NSError errorWithDomain:NSURLErrorDomain
												code:NSURLErrorUnknown
											userInfo:@{NSLocalizedDescriptionKey: @"Cannot retrieve configuration"}];
				}
				completion(nil, error);
			}
		}];
	}
}

- (void)fetchConfigWithCompletion:(void (^)(BOOL success, NSError * error))completion {
	NSURL * URL = [NSURL URLWithString:@"configuration" relativeToURL:_baseURL];
	NSURLRequest * request = [NSURLRequest requestWithURL:URL];
	[_session startRequest:request
				parameters:@{@"api_key": _apiKey}
				   builder:_requestBuilder
					parser:_responseParser
				completion:^(id data, NSURLResponse *response, NSError *error) {
					if (!error)
						_config = data;
					if (completion)
						completion(_config != nil, error);
				}];
}

- (void)submitTMDbRequest:(NSURLRequest *)request withParameters:(NSDictionary *)parameters completion:(TRBJSONResultBlock)completion {
	if (_config) {
		if (parameters) {
			NSMutableDictionary * mParameters = [parameters mutableCopy];
			mParameters[@"api_key"] = _apiKey;
			parameters = [mParameters copy];
		} else
			parameters = @{@"api_key": _apiKey};
		[_session startRequest:request
					parameters:parameters
					   builder:_requestBuilder
						parser:_responseParser
					completion:^(id data, NSURLResponse *response, NSError *error) {
						if (!error && completion)
							completion(data, nil);
						else if (completion) {
							if (!error) {
								error = [NSError errorWithDomain:NSURLErrorDomain
															code:NSURLErrorBadServerResponse
														userInfo:@{NSLocalizedDescriptionKey: @"Unsupported Status Code"}];
							}
							if (completion)
								completion(nil, error);
						}
					}];
	} else {
		[self fetchConfigWithCompletion:^(BOOL success, NSError *error) {
			if (success)
				[self submitTMDbRequest:request withParameters:parameters completion:completion];
			else {
				if (!error) {
					error = [NSError errorWithDomain:NSStringFromClass([self class])
												code:-1093
											userInfo:@{NSLocalizedDescriptionKey: @"Cannot retrieve configuration"}];
				}
				completion(nil, error);
			}
		}];
	}
}

@end
