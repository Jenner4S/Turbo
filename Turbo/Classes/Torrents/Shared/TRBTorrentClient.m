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

#import "TRBTorrentClient.h"
#import "TRBTorrent.h"
#import "TRBHTTPSession.h"
#import "TKAlertCenter.h"

@implementation TRBTorrentClient

- (instancetype)initWithURL:(NSURL *)URL {
	self = [super init];
	if (self) {
		_URL = URL;
	}
	return self;
}

- (void)validateRemoteWithCompletion:(void(^)(BOOL valid, NSError * error))completion {
	[NSException raise:@"Method not implemented" format:@"%@ needs to be implemented by a concrete subclass", NSStringFromSelector(_cmd)];
}

- (void)fetchTorrentsWithCompletion:(void(^)(NSArray * torrents, NSError * error))completion {
	[NSException raise:@"Method not implemented" format:@"%@ needs to be implemented by a concrete subclass", NSStringFromSelector(_cmd)];
}

- (void)addTorrentAtURL:(NSString *)URL completion:(void(^)(BOOL valid, NSError * error))completion {
	[NSException raise:@"Method not implemented" format:@"%@ needs to be implemented by a concrete subclass", NSStringFromSelector(_cmd)];
}

- (void)addTorrentWithBase64String:(NSString *)base64Data completion:(void(^)(BOOL valid, NSError * error))completion {
	[NSException raise:@"Method not implemented" format:@"%@ needs to be implemented by a concrete subclass", NSStringFromSelector(_cmd)];
}

- (void)removeTorrent:(TRBTorrent *)identifier completion:(void(^)(BOOL valid, NSError * error))completion {
	[NSException raise:@"Method not implemented" format:@"%@ needs to be implemented by a concrete subclass", NSStringFromSelector(_cmd)];
}

- (void)reset {
	[NSException raise:@"Method not implemented" format:@"%@ needs to be implemented by a concrete subclass", NSStringFromSelector(_cmd)];
}

@end

static NSString * const TokenHeader = @"X-Transmission-Session-Id";

@interface TRBTransmissionClient ()<UIAlertViewDelegate>
@property (nonatomic, copy) void(^authHandler)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * credential);
@end

@implementation TRBTransmissionClient {
	NSString * _token;
	TRBHTTPSession * _session;
	TRBHTTPJSONRequestBuilder * _requestBuilder;
	TRBHTTPJSONResponseParser * _responseParser;
	NSError * _noHostError;
}

- (instancetype)initWithURL:(NSURL *)URL {
	self = [super initWithURL:URL];
	if (self) {
		_requestBuilder = [TRBHTTPJSONRequestBuilder new];
		_responseParser = [TRBHTTPJSONResponseParser new];
		_noHostError = [NSError errorWithDomain:NSStringFromClass([self class]) code:1337 userInfo:@{NSLocalizedDescriptionKey: @"No host selected"}];
		[self reset];
	}
	return self;
}

#pragma mark - UIAlertViewDelegate Implementation

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
	switch (buttonIndex) {
		case 0:
			if (_authHandler) {
				_authHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
				self.authHandler = nil;
			}
			break;
		case 1: {
			NSString * usr = [alertView textFieldAtIndex:0].text;
			NSString * psw = [alertView textFieldAtIndex:1].text;
			if (_authHandler) {
				_authHandler(NSURLSessionAuthChallengeUseCredential, [NSURLCredential credentialWithUser:usr password:psw persistence:NSURLCredentialPersistencePermanent]);
				self.authHandler = nil;
			}
			break;
		} default:
			break;
	}
}

#pragma mark - Public Methods

- (void)validateRemoteWithCompletion:(void(^)(BOOL valid, NSError * error))completion {
	NSMutableURLRequest * request = [self newRequest];
	if (request) {
		[_session startRequest:request
					parameters:@{@"method": @"session-get"}
					   builder:_requestBuilder
						parser:_responseParser
					completion:^(id data, NSURLResponse *response, NSError *error) {
						if (!error && completion)
							completion([self validateResponse:data], nil);
						else {
							NSHTTPURLResponse * httpResponse = ((NSHTTPURLResponse *)response);
							if (httpResponse.statusCode == 409) {
								_token = [httpResponse allHeaderFields][TokenHeader];
								[self validateRemoteWithCompletion:completion];
							} else if (completion) {
								LogE([error localizedDescription]);
								completion(NO, error);
							}
						}
					}];
	} else if (completion)
		completion(NO, _noHostError);
}

- (void)fetchTorrentsWithCompletion:(void(^)(NSArray * torrents, NSError * error))completion {
	NSMutableURLRequest * request = [self newRequest];
	if (request) {
		NSDictionary * jsonBody = @{@"method": @"torrent-get",
									@"arguments": @{@"fields": @[@"id",
																 @"name",
																 @"status",
																 @"percentDone",
																 @"peersConnected",
																 @"peersSendingToUs",
																 @"eta",
																 @"errorString",
																 @"rateDownload",
																 @"rateUpload",
																 @"haveValid",
																 @"sizeWhenDone",
																 @"isFinished",
																 @"isPrivate",
																 @"isStalled"]}};
		[_session startRequest:request
					parameters:jsonBody
					   builder:_requestBuilder
						parser:_responseParser
					completion:^(id data, NSURLResponse *response, NSError *error) {
						NSHTTPURLResponse * httpResponse = ((NSHTTPURLResponse *)response);
						if (!error && completion)
							completion([self processTorrents:data], nil);
						else {
							if (httpResponse.statusCode == 409) {
								_token = [httpResponse allHeaderFields][TokenHeader];
								[self fetchTorrentsWithCompletion:completion];
							} else if (completion) {
								LogE([error localizedDescription]);
								completion(nil, error);
							}
						}
					}];
	} else if (completion)
		completion(nil, _noHostError);
}

- (void)addTorrentAtURL:(NSString *)URL completion:(void(^)(BOOL valid, NSError * error))completion {
	NSMutableURLRequest * request = [self newRequest];
	if (request) {
		[self addTorrentWithRequest:request torrentInfo:@{@"filename": URL} completion:completion];
	} else
		completion(NO, _noHostError);
}

- (void)addTorrentWithBase64String:(NSString *)base64Data completion:(void(^)(BOOL valid, NSError * error))completion {
	NSMutableURLRequest * request = [self newRequest];
	if (request) {
		[self addTorrentWithRequest:request torrentInfo:@{@"metainfo": base64Data} completion:completion];
	} else
		completion(NO, _noHostError);
}

- (void)removeTorrent:(TRBTorrent *)torrent completion:(void(^)(BOOL valid, NSError * error))completion {
	NSMutableURLRequest * request = [self newRequest];
	if (request) {
		[_session startRequest:request
					parameters:@{@"method": @"torrent-remove", @"arguments": @{@"ids": @[torrent.identifier], @"delete-local-data": @YES}}
					   builder:_requestBuilder
						parser:_responseParser
					completion:^(id data, NSURLResponse *response, NSError * error) {
						if (!error && completion)
							completion([self validateResponse:data], nil);
						else {
							NSHTTPURLResponse * httpResponse = ((NSHTTPURLResponse *)response);
							if (httpResponse.statusCode == 409) {
								_token = [httpResponse allHeaderFields][TokenHeader];
								[self removeTorrent:torrent completion:completion];
							} else if (completion) {
								LogE([error localizedDescription]);
								completion(NO, error);
							}
						}
					}];
	} else if (completion)
		completion(NO, _noHostError);
}

- (void)reset {
	[_session invalidateAndCancel];
	_session = [[TRBHTTPSession alloc] initWithConfiguration:nil];
	_session.acceptedHTTPStatusCodes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(200, 100)];
	typeof(self) __weak selfWeak = self;
	[_session onSessionTaskAuthenticationChallenge:^(NSURLSessionTask *task, NSURLAuthenticationChallenge *challenge, void(^completionHandler)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * credential)) {
		if ([challenge proposedCredential] && [[challenge proposedCredential] hasPassword]) {
			completionHandler(NSURLSessionAuthChallengeUseCredential, [challenge proposedCredential]);
		} else {
			selfWeak.authHandler = [completionHandler copy];
			dispatch_async(dispatch_get_main_queue(), ^{
				UIAlertView * alertView = [[UIAlertView alloc] initWithTitle:@"Login"
																	 message:@"Provide credential"
																	delegate:selfWeak
														   cancelButtonTitle:@"Cancel"
														   otherButtonTitles:@"Login", nil];
				alertView.alertViewStyle = UIAlertViewStyleLoginAndPasswordInput;
				if ([challenge proposedCredential])
					[alertView textFieldAtIndex:0].text = [[challenge proposedCredential] user];
				[alertView show];
			});
		}
	}];
}

#pragma mark - Private Methods

- (NSMutableURLRequest *)newRequest {
	NSMutableURLRequest * request = nil;
	if (self.URL) {
		request = [NSMutableURLRequest requestWithURL:self.URL];
		[request setHTTPMethod:@"POST"];
		if (_token)
			[request setValue:_token forHTTPHeaderField:TokenHeader];
	}
	return request;
}

- (void)addTorrentWithRequest:(NSMutableURLRequest *)request torrentInfo:(NSDictionary *)info completion:(void(^)(BOOL valid, NSError * error))completion {
	[_session startRequest:request
				parameters:@{@"method": @"torrent-add", @"arguments": info}
				   builder:_requestBuilder
					parser:_responseParser
				completion:^(id data, NSURLResponse *response, NSError *error) {
					if (!error && completion)
						completion([self validateResponse:data], nil);
					else {
						NSHTTPURLResponse * httpResponse = ((NSHTTPURLResponse *)response);
						if (httpResponse.statusCode == 409) {
							_token = [httpResponse allHeaderFields][TokenHeader];
							[request setValue:_token forHTTPHeaderField:TokenHeader];
							[self addTorrentWithRequest:request torrentInfo:info completion:completion];
						} else if (completion) {
							LogE([error localizedDescription]);
							completion(NO, error);
						}
					}
				}];
}

- (NSArray *)processTorrents:(NSDictionary *)json {
	NSMutableArray * result = nil;
	if ([self validateResponse:json]) {
		NSArray * torrents = json[@"arguments"][@"torrents"];
		result = [[NSMutableArray alloc] initWithCapacity:[torrents count]];
		for (NSDictionary * torrent in torrents) {
			TRBTorrent * t = [[TRBTorrent alloc] initWithTransmissionJSON:torrent];
			[result addObject:t];
		}
	}
	return result;
}

- (BOOL)validateResponse:(NSDictionary *)json {
	return [json[@"result"] isEqualToString:@"success"];
}

@end
