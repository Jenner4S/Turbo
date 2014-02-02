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

#import "TRBRottenTomatoesClient.h"
#import "TRBHTTPSession.h"
#import "API_KEYS.h"

static NSString * const TRListEndpoints[TRBRTListTypeCount] = {
	@"lists/movies/box_office.json",
	@"lists/movies/in_theaters.json",
	@"lists/movies/opening.json",
	@"lists/movies/upcoming.json",
	@"lists/dvds/top_rentals.json",
	@"lists/dvds/current_releases.json",
	@"lists/dvds/new_releases.json",
	@"lists/dvds/upcoming.json",
};

@implementation TRBRottenTomatoesClient {
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
		_baseURL = [NSURL URLWithString:@"http://api.rottentomatoes.com/api/public/v1.0/"];
		_apiKey = RTAPIKey;
	}
	return self;
}

#pragma mark - Public Methods

- (void)fetchMovieList:(TRBRTListType)listType withHandler:(TRBJSONResultBlock)handler {
	NSURL * URL = [NSURL URLWithString:TRListEndpoints[listType] relativeToURL:_baseURL];
	NSURLRequest * request = [NSURLRequest requestWithURL:URL];
	NSDictionary * parameters = @{@"country": @"us", @"limit": @"50"};
	[self sendRTRequest:request withParameters:parameters andHandler:handler];
}

- (void)fetchImageAtURL:(NSString *)url withHandler:(TRBImageResultBlock)handler {
	[_session GET:url parameters:nil builder:nil parser:nil completion:^(id data, NSURLResponse *response, NSError *error) {
		if (!error && handler) {
			NSData * imageData = data;
			UIImage * downloadedImage = [UIImage imageWithData:imageData scale:[UIScreen mainScreen].scale];
			handler(downloadedImage, nil);
		} else if (handler) {
			if (!error) {
				error = [NSError errorWithDomain:NSURLErrorDomain
											code:NSURLErrorBadServerResponse
										userInfo:@{NSLocalizedDescriptionKey: @"Unsupported Status Code"}];
			}
			handler(nil, error);
		}
	}];
}

- (void)fetchMovieInfoForID:(NSString *)movieID withHandler:(TRBJSONResultBlock)handler {
	NSString * URLString = [NSString stringWithFormat:@"movies/%@.json", movieID];
	NSURL * URL = [NSURL URLWithString:URLString relativeToURL:_baseURL];
	NSURLRequest * request = [NSURLRequest requestWithURL:URL];
	[self sendRTRequest:request withParameters:nil andHandler:handler];
}

- (void)fetchCastsInfoForID:(NSString *)movieID withHandler:(TRBJSONResultBlock)handler {
	NSString * URLString = [NSString stringWithFormat:@"movies/%@/cast.json", movieID];
	NSURL * URL = [NSURL URLWithString:URLString relativeToURL:_baseURL];
	NSURLRequest * request = [NSURLRequest requestWithURL:URL];
	[self sendRTRequest:request withParameters:nil andHandler:handler];
}

- (void)fetchMovieReviewsForID:(NSString *)movieID page:(NSUInteger)page withHandler:(TRBJSONResultBlock)handler {
	NSString * URLString = [NSString stringWithFormat:@"movies/%@/reviews.json", movieID];
	NSURL * URL = [NSURL URLWithString:URLString relativeToURL:_baseURL];
	NSURLRequest * request = [NSURLRequest requestWithURL:URL];
	NSDictionary * parameters = @{@"page": [@(MAX(page, 1)) description], @"page_limit": @"50", @"review_type": @"top_critic"};
	[self sendRTRequest:request withParameters:parameters andHandler:handler];
}

- (void)searchWithQuery:(NSString *)query page:(NSUInteger)page andHandler:(TRBJSONResultBlock)handler {
	NSURL * URL = [NSURL URLWithString:@"movies.json" relativeToURL:_baseURL];
	NSURLRequest * request = [NSURLRequest requestWithURL:URL];
	NSDictionary * parameters = @{@"q" : query, @"page": [@(MAX(page, 1)) description], @"page_limit": @"50"};
	[self sendRTRequest:request withParameters:parameters andHandler:handler];
}

#pragma mark - Private Methods

- (void)sendRTRequest:(NSURLRequest *)request withParameters:(NSDictionary *)parameters andHandler:(TRBJSONResultBlock)handler {
	if (parameters) {
		NSMutableDictionary * mParameters = [parameters mutableCopy];
		mParameters[@"apikey"] = _apiKey;
		parameters = [mParameters copy];
	} else
		parameters = @{@"apikey": _apiKey};
	[_session startRequest:request
				parameters:parameters
				   builder:_requestBuilder
					parser:_responseParser
				completion:^(id data, NSURLResponse *response, NSError *error) {
					if (!error && handler) {
						handler(data, nil);
					} else if (handler) {
						if (!error) {
							error = [NSError errorWithDomain:NSURLErrorDomain
														code:NSURLErrorBadServerResponse
													userInfo:@{NSLocalizedDescriptionKey: @"Unsupported Status Code"}];
						}
						handler(nil, error);
					}
				}];
}

@end
