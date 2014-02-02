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

#import "TRBHTTPSession.h"
#import "TRBXMLElement.h"
#import "NSString+TRBAdditions.h"
#import "NSDictionary+TRBAdditions.h"

@interface TRBTaskInfo : NSObject
@property (nonatomic, strong) NSMutableData * data;
@property (nonatomic, strong) TRBHTTPResponseParser * parser;
@property (nonatomic, strong) void (^progress)(uint64_t bytesWrittenOrRead, uint64_t totalBytesWrittenOrRead, uint64_t totalBytesExpectedToWriteOrRead);
@property (nonatomic, strong) void(^completion)(id data, NSURLResponse * response, NSError * error);
@end

@interface TRBHTTPSession ()<NSURLSessionDelegate, NSURLSessionTaskDelegate, NSURLSessionDataDelegate, NSURLSessionDownloadDelegate>

@property (nonatomic, readonly, strong) NSURLSession * session;
@property (nonatomic, readonly, strong) NSMutableDictionary * taskInfoMap;

@end

@implementation TRBHTTPSession {
	TRBHTTPSessionAuthenticationChallengeBlock _sessionAuthenticationChallengeBlock;
	TRBHTTPSessionTaskAuthenticationChallengeBlock _sessionTaskAuthenticationChallengeBlock;
}

- (instancetype)initWithConfiguration:(NSURLSessionConfiguration *)configuration {
    self = [super init];
    if (self) {
		configuration = !configuration ? [NSURLSessionConfiguration defaultSessionConfiguration] : configuration;
		_session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
		_taskInfoMap = [NSMutableDictionary new];
    }
    return self;
}

#pragma mark - Public Methods

- (void)onSessionAuthenticationChallenge:(TRBHTTPSessionAuthenticationChallengeBlock)sessionAuthenticationChallengeBlock {
	_sessionAuthenticationChallengeBlock = [sessionAuthenticationChallengeBlock copy];
}

- (void)onSessionTaskAuthenticationChallenge:(TRBHTTPSessionTaskAuthenticationChallengeBlock)sessionTaskAuthenticationChallengeBlock {
	_sessionTaskAuthenticationChallengeBlock = [sessionTaskAuthenticationChallengeBlock copy];
}

- (void)startRequest:(NSURLRequest *)request parser:(TRBHTTPResponseParser *)parser completion:(void(^)(id, NSURLResponse *, NSError *))completion {
	NSParameterAssert(completion);
	NSParameterAssert(request);
	__weak TRBHTTPSession * selfWeak = self;
	TRBDumpRequestToConsole(request);
	__block NSURLSessionDataTask * task = [_session dataTaskWithRequest:request completionHandler:^(NSData * data, NSURLResponse * response, NSError * error) {
		[selfWeak processResponse:response data:data error:error parser:parser completion:completion];
	}];
	[task resume];
}

- (void)startRequest:(NSURLRequest *)request parameters:(NSDictionary *)parameters builder:(TRBHTTPRequestBuilder *)builder parser:(TRBHTTPResponseParser *)parser completion:(void(^)(id, NSURLResponse *, NSError *))completion {
	NSParameterAssert([parameters count] == 0 || builder != nil);
	NSError * buildError = nil;
	NSURLRequest * builtRequest = builder ? [builder buildRequest:request parameters:parameters error:&buildError] : request;
	if (builtRequest && !buildError)
		[self startRequest:builtRequest parser:parser completion:completion];
	else {
		dispatch_async(dispatch_get_main_queue(), ^{
			completion(nil, nil, buildError);
		});
	}
}

- (void)GET:(NSString *)URL parameters:(NSDictionary *)parameters builder:(TRBHTTPRequestBuilder *)builder parser:(TRBHTTPResponseParser *)parser completion:(void(^)(id, NSURLResponse *, NSError *))completion {
	NSMutableURLRequest * request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:URL]];
	[request setHTTPMethod:@"GET"];
	[self startRequest:request parameters:parameters builder:builder parser:parser completion:completion];
}

- (void)GETJSON:(NSString *)URL parameters:(NSDictionary *)parameters completion:(void(^)(id, NSURLResponse *, NSError *))completion {
	NSMutableURLRequest * request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:URL]];
	[request setHTTPMethod:@"GET"];
	[self startRequest:request parameters:parameters builder:[TRBHTTPRequestBuilder new] parser:[TRBHTTPJSONResponseParser new] completion:completion];
}

- (void)GETXML:(NSString *)URL parameters:(NSDictionary *)parameters completion:(void(^)(id, NSURLResponse *, NSError *))completion {
	NSMutableURLRequest * request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:URL]];
	[request setHTTPMethod:@"GET"];
	[self startRequest:request parameters:parameters builder:[TRBHTTPRequestBuilder new] parser:[TRBHTTPXMLResponseParser new] completion:completion];
}

- (void)POST:(NSString *)URL parameters:(NSDictionary *)parameters builder:(TRBHTTPRequestBuilder *)builder parser:(TRBHTTPResponseParser *)parser completion:(void(^)(id, NSURLResponse *, NSError *))completion {
	NSMutableURLRequest * request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:URL]];
	[request setHTTPMethod:@"POST"];
	[self startRequest:request parameters:parameters builder:builder parser:parser completion:completion];
}

- (void)downloadRequest:(NSURLRequest *)request progress:(void (^)(uint64_t bytesRead, uint64_t totalBytesRead, uint64_t totalBytesExpectedToRead))progress completion:(void(^)(NSURL * location, NSURLResponse * response, NSError * error))completion {
	NSParameterAssert([self isBackgroundSession] || completion);
	NSParameterAssert(request);
	NSURLSessionDownloadTask * task = nil;
	__weak TRBHTTPSession * selfWeak = self;
	void(^completionHandler)(NSURL *, NSURLResponse *, NSError *) = ^(NSURL *location, NSURLResponse *response, NSError *error) {
		TRBDumpResponseToConsole((NSHTTPURLResponse *)response);
		if (!error && ![selfWeak validateResponse:response error:&error])
			location = nil;
		completion(location, response, error);
	};
	TRBTaskInfo * taskInfo = nil;
	if ([self isBackgroundSession] || progress) {
		taskInfo = [TRBTaskInfo new];
		taskInfo.progress = [progress copy];
		taskInfo.completion = [completionHandler copy];
		completionHandler = NULL;
	}
	TRBDumpRequestToConsole(request);
	task = [_session downloadTaskWithRequest:request completionHandler:completionHandler];
	if (taskInfo) {
		[_session.delegateQueue addOperationWithBlock:^{
			selfWeak.taskInfoMap[@(task.taskIdentifier)] = taskInfo;
		}];
	}
	[task resume];
}

- (void)resumeDownloadWithData:(NSData *)data progress:(void (^)(uint64_t bytesRead, uint64_t totalBytesRead, uint64_t totalBytesExpectedToRead))progress completion:(void(^)(NSURL * location, NSURLResponse * response, NSError * error))completion {
	NSParameterAssert([self isBackgroundSession] || completion);
	NSParameterAssert(data);
	__weak TRBHTTPSession * selfWeak = self;
	void(^completionHandler)(NSURL *, NSURLResponse *, NSError *) = ^(NSURL *location, NSURLResponse *response, NSError *error) {
		if (!error && ![selfWeak validateResponse:response error:&error])
			location = nil;
		completion(location, response, error);
	};
	TRBTaskInfo * taskInfo = nil;
	if ([self isBackgroundSession] || progress) {
		taskInfo = [TRBTaskInfo new];
		taskInfo.progress = [progress copy];
		taskInfo.completion = [completionHandler copy];
		completionHandler = NULL;
	}
	NSURLSessionDownloadTask * task = [_session downloadTaskWithResumeData:data completionHandler:completionHandler];
	if (taskInfo) {
		[_session.delegateQueue addOperationWithBlock:^{
			selfWeak.taskInfoMap[@(task.taskIdentifier)] = taskInfo;
		}];
	}
	[task resume];
}

- (void)resetWithCompletion:(void(^)(void))completion {
	[_session resetWithCompletionHandler:completion];
}

- (void)invalidateAndCancel {
	[_session invalidateAndCancel];
}

#pragma mark - NSURLSessionDelegate

- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(NSError *)error {
	_sessionAuthenticationChallengeBlock = nil;
	_sessionTaskAuthenticationChallengeBlock = nil;
}

- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * credential))completionHandler {
	if (_sessionAuthenticationChallengeBlock)
		_sessionAuthenticationChallengeBlock(challenge, completionHandler);
	else
		completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
}

- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session {
	[_backgroundSessionDelegate HTTPSessionDidFinishEvents:self];
}

#pragma mark - NSURLSessionTaskDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler {
	if (_sessionTaskAuthenticationChallengeBlock)
		_sessionTaskAuthenticationChallengeBlock(task, challenge, completionHandler);
	else
		completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task needNewBodyStream:(void (^)(NSInputStream *bodyStream))completionHandler {
	if (task.originalRequest.HTTPBodyStream && [task.originalRequest.HTTPBodyStream conformsToProtocol:@protocol(NSCopying)])
		completionHandler([task.originalRequest.HTTPBodyStream copy]);
	else
		completionHandler(nil);
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend {
	TRBTaskInfo * taskInfo = _taskInfoMap[@(task.taskIdentifier)];
	if (taskInfo.progress) {
		dispatch_async(dispatch_get_main_queue(), ^{
			taskInfo.progress(bytesSent, totalBytesSent, totalBytesExpectedToSend);
		});
	}
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
	TRBTaskInfo * taskInfo = _taskInfoMap[@(task.taskIdentifier)];
	if (taskInfo) {
		if ([taskInfo.data length] == 0)
			taskInfo.data = nil;
		if (![self isBackgroundSession] && taskInfo.completion) {
			taskInfo.completion(taskInfo.data, task.response, error);
		} else if ([self isBackgroundSession]) {
			if (taskInfo.data) {
				[self processResponse:task.response data:taskInfo.data error:error parser:taskInfo.parser completion:^(id data, NSURLResponse * response, NSError * completionError) {
					[_backgroundSessionDelegate HTTPSession:self task:task didCompleteWithData:data error:completionError];
				}];
			} else
				[_backgroundSessionDelegate HTTPSession:self task:task didCompleteWithData:nil error:error];
		}
		[_taskInfoMap removeObjectForKey:@(task.taskIdentifier)];
	}
}

#pragma mark - NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
	completionHandler([self validateResponse:response error:NULL] ? NSURLSessionResponseAllow : NSURLSessionResponseCancel);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
	TRBTaskInfo * taskInfo = _taskInfoMap[@(dataTask.taskIdentifier)];
	if (!taskInfo) {
		taskInfo = [TRBTaskInfo new];
		_taskInfoMap[@(dataTask.taskIdentifier)] = taskInfo;
	}
	[taskInfo.data appendData:data];
}

#pragma mark - NSURLSessionDownloadDelegate

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location {
	if ([self isBackgroundSession]) {
		if ([_backgroundSessionDelegate respondsToSelector:@selector(HTTPSession:downloadTask:didFinishDownloadingToURL:)])
			[_backgroundSessionDelegate HTTPSession:self downloadTask:downloadTask didFinishDownloadingToURL:location];
	} else {
		TRBTaskInfo * taskInfo = _taskInfoMap[@(downloadTask.taskIdentifier)];
		if (taskInfo.completion) {
			taskInfo.completion(location, downloadTask.response, nil);
			taskInfo.completion = nil;
		}
	}
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
	TRBTaskInfo * taskInfo = _taskInfoMap[@(downloadTask.taskIdentifier)];
	if (taskInfo.progress) {
		dispatch_async(dispatch_get_main_queue(), ^{
			taskInfo.progress(bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
		});
	}
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didResumeAtOffset:(int64_t)fileOffset expectedTotalBytes:(int64_t)expectedTotalBytes {

}

#pragma mark - Private Methods

- (void)processResponse:(NSURLResponse *)response data:(NSData *)data error:(NSError *)error parser:(TRBHTTPResponseParser *)parser completion:(void (^)(id, NSURLResponse *, NSError *))completion {
	TRBDumpResponseToConsole((NSHTTPURLResponse *)response);
	TRBDumpResponseDataToConsole(data);
	id result = data;
	if (!error && [self validateResponse:response error:&error] && [data length] && [parser shouldParseDataForResponse:response error:&error]) {
		[parser parse:data response:response completion:^(id parsedData, NSError * dataParserError) {
			dispatch_async(dispatch_get_main_queue(), ^{
				completion(!dataParserError ? parsedData : data, response, dataParserError);
			});
		}];
	} else {
		dispatch_async(dispatch_get_main_queue(), ^{
			completion(result, response, error);
		});
	}
}

- (BOOL)validateResponse:(NSURLResponse *)response error:(NSError *__autoreleasing *)error {
	BOOL result = NO;
	if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
		NSHTTPURLResponse * httpResponse = (NSHTTPURLResponse *)response;
		result = (_acceptedHTTPStatusCodes == nil || [_acceptedHTTPStatusCodes containsIndex:[httpResponse statusCode]]);
	}
	if (!result && error)
		*error = [NSError errorWithDomain:@"Turbo" code:-21384 userInfo:@{NSLocalizedDescriptionKey: @"Invalid Response"}];
	return result;
}

- (BOOL)isBackgroundSession {
	return [_session.configuration.identifier length] > 0;
}

@end

@implementation TRBTaskInfo

- (id)init {
    self = [super init];
    if (self) {
		_data = [NSMutableData new];
    }
    return self;
}

@end

NSString * TRBFormURLEncodedParameters(NSDictionary * parameters, BOOL encode);

@interface TRBHTTPRequestBuilder ()
@property (nonatomic, strong) NSSet * methodsWithParameterizedURL;
@end

@implementation TRBHTTPRequestBuilder

- (id)init {
    self = [super init];
    if (self) {
		_methodsWithParameterizedURL = [NSSet setWithArray:@[@"GET", @"HEAD", @"DELETE"]];
		_stringEncoding = NSUTF8StringEncoding;
		_percentEncodeParameters = YES;
    }
    return self;
}

- (NSURLRequest *)buildRequest:(NSURLRequest *)request parameters:(NSDictionary *)parameters error:(NSError **)error {
	if ([parameters count]) {
		NSString * parameterString = TRBFormURLEncodedParameters(parameters, NO);
		if ([parameterString length]) {
			NSMutableURLRequest * mRequest = [request mutableCopy];
			if ([_methodsWithParameterizedURL containsObject:[[mRequest HTTPMethod] uppercaseString]]) {
				NSURL * url = [mRequest URL];
				NSURLComponents * urlComponents = [NSURLComponents componentsWithString:[url absoluteString]];
				if (_percentEncodeParameters)
					urlComponents.query = parameterString;
				else
					urlComponents.percentEncodedQuery = parameterString;
				[mRequest setURL:[urlComponents URL]];
			} else {
				NSData * data = [parameterString dataUsingEncoding:_stringEncoding];
				[mRequest setHTTPBody:data];
				NSString * charset = (__bridge NSString *)CFStringConvertEncodingToIANACharSetName(CFStringConvertNSStringEncodingToEncoding(_stringEncoding));
				NSString * contentType = [NSString stringWithFormat:@"application/x-www-form-urlencoded; charset=%@", charset];
				[mRequest setValue:contentType forHTTPHeaderField:@"Content-Type"];
			}
			request = mRequest;
		}
	}
	return request;
}

@end

@implementation TRBHTTPJSONRequestBuilder

- (NSURLRequest *)buildRequest:(NSURLRequest *)request parameters:(NSDictionary *)parameters error:(NSError **)error {
	if ([parameters count]) {
		if (![self.methodsWithParameterizedURL containsObject:[[request HTTPMethod] uppercaseString]]) {
			NSData * jsonData = [NSJSONSerialization dataWithJSONObject:parameters options:kNilOptions error:error];
			if ([jsonData length]) {
				NSMutableURLRequest * mRequest = [request mutableCopy];
				[mRequest setHTTPBody:jsonData];
				NSString * charset = (__bridge NSString *)CFStringConvertEncodingToIANACharSetName(CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding));
				NSString * contentType = [NSString stringWithFormat:@"application/json; charset=%@", charset];
				[mRequest setValue:contentType forHTTPHeaderField:@"Content-Type"];
				request = mRequest;
			} else
				request = nil;
		} else
			request = [super buildRequest:request parameters:parameters error:error];
	}
	return request;
}

@end

NSString * TRBFormURLEncodedParameters(NSDictionary * parameters, BOOL encode) {
	NSArray * keys = [[parameters allKeys] sortedArrayUsingSelector:@selector(compare:)];
	NSUInteger count = [keys count];
	NSMutableString * result = nil;
	if (count) {
		result = [NSMutableString new];
		for (NSUInteger i = 0; i < count; i++) {
			id key = keys[i];
			if (![key isKindOfClass:[NSString class]])
				continue;
			NSString * keyString = encode ? [(NSString *)key URLEncodedString] : (NSString *)key;
			id value = parameters[keyString];
			if (![value isKindOfClass:[NSString class]])
				continue;
			NSString * valueString = encode ? [(NSString *)value URLEncodedString] : (NSString *)value;
			[result appendFormat:@"%@=%@%@", keyString, valueString, (i != ([keys count] - 1) ? @"&" : @"")];
		}
	}
	return result;
}

@implementation TRBHTTPResponseParser

- (id)init {
    self = [super init];
    if (self) {
		_acceptedMIMETypes = [NSMutableSet new];
    }
    return self;
}

- (BOOL)shouldParseDataForResponse:(NSURLResponse *)response error:(NSError *__autoreleasing *)error {
	return YES;
}

- (void)parse:(NSData *)data response:(NSURLResponse *)response completion:(void (^)(id, NSError *))completion {
	NSAssert(NO, @"To implement by concrete subclasses");
}

@end

@implementation TRBHTTPJSONResponseParser

- (id)init {
    self = [super init];
    if (self) {
		[self.acceptedMIMETypes addObjectsFromArray:@[@"application/json", @"text/javascript"]];
    }
    return self;
}

- (BOOL)shouldParseDataForResponse:(NSURLResponse *)response error:(NSError *__autoreleasing *)error {
	BOOL result = NO;
	NSString * contentType = [response MIMEType];
	result = [self.acceptedMIMETypes containsObject:contentType] || [[[[response URL] pathExtension] lowercaseString] isEqualToString:@"json"];
	if (!result && error) {
		NSString * message = [NSString stringWithFormat:@"Unexpected Content-Type, received %@, expected application/json", contentType];
		*error = [NSError errorWithDomain:@"Turbo" code:-128942 userInfo:@{NSLocalizedDescriptionKey: message}];
	}
	return result;
}

- (void)parse:(NSData *)data response:(NSURLResponse *)response completion:(void(^)(id, NSError *))completion {
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		NSError * error = nil;
		id parsedData = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
		completion(parsedData, error);
	});
}

@end

@implementation TRBHTTPXMLResponseParser

- (id)init {
    self = [super init];
    if (self) {
		[self.acceptedMIMETypes addObjectsFromArray:@[@"application/xml", @"text/xml", @"application/rss+xml", @"application/rdf+xml", @"application/atom+xml"]];
    }
    return self;
}

- (BOOL)shouldParseDataForResponse:(NSURLResponse *)response error:(NSError *__autoreleasing *)error {
	NSString * contentType = [response MIMEType];
	BOOL result = [self.acceptedMIMETypes containsObject:contentType] || [[[[response URL] pathExtension] lowercaseString] isEqualToString:@"xml"];
	if (!result && error) {
		NSString * message = [NSString stringWithFormat:@"Unexpected Content-Type, received %@, expected: %@", contentType, self.acceptedMIMETypes];
		*error = [NSError errorWithDomain:@"Turbo" code:-432343 userInfo:@{NSLocalizedDescriptionKey: message}];
	}
	return result;
}

- (void)parse:(NSData *)data response:(NSURLResponse *)response completion:(void(^)(id, NSError *))completion {
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		NSError * error = nil;
		TRBXMLElement * element = [TRBXMLElement XMLElementWithData:data error:&error];
		completion(element, error);
	});
}

@end
