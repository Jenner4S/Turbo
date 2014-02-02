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

@class TRBHTTPSession;
@class TRBHTTPRequestBuilder;
@class TRBHTTPResponseParser;

typedef void(^TRBHTTPSessionAuthenticationChallengeBlock)(NSURLAuthenticationChallenge * challenge,
														  void(^completionHandler)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * credential));
typedef void(^TRBHTTPSessionTaskAuthenticationChallengeBlock)(NSURLSessionTask * task,
															  NSURLAuthenticationChallenge * challenge,
															  void(^completionHandler)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * credential));

@protocol TRBHTTPSessionBackgroundDelegate <NSObject>

- (void)HTTPSessionDidFinishEvents:(TRBHTTPSession *)HTTPSession;
- (void)HTTPSession:(TRBHTTPSession *)HTTPSession task:(NSURLSessionTask *)task didCompleteWithData:(id)data error:(NSError *)error;

@optional

- (void)HTTPSession:(TRBHTTPSession *)HTTPSession downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location;

@end

@interface TRBHTTPSession : NSObject

@property (nonatomic, strong) NSIndexSet * acceptedHTTPStatusCodes;
@property (nonatomic, weak) id<TRBHTTPSessionBackgroundDelegate> backgroundSessionDelegate;

- (instancetype)initWithConfiguration:(NSURLSessionConfiguration *)configuration;

- (void)onSessionAuthenticationChallenge:(TRBHTTPSessionAuthenticationChallengeBlock)sessionAuthenticationChallengeBlock;
- (void)onSessionTaskAuthenticationChallenge:(TRBHTTPSessionTaskAuthenticationChallengeBlock)sessionTaskAuthenticationChallengeBlock;

- (void)startRequest:(NSURLRequest *)request parser:(TRBHTTPResponseParser *)parser completion:(void(^)(id data, NSURLResponse * response, NSError * error))completion;

- (void)startRequest:(NSURLRequest *)request parameters:(NSDictionary *)parameters builder:(TRBHTTPRequestBuilder *)builder parser:(TRBHTTPResponseParser *)parser completion:(void(^)(id data, NSURLResponse * response, NSError * error))completion;

- (void)GET:(NSString *)URL parameters:(NSDictionary *)parameters builder:(TRBHTTPRequestBuilder *)builder parser:(TRBHTTPResponseParser *)parser completion:(void(^)(id data, NSURLResponse * response, NSError * error))completion;

- (void)GETJSON:(NSString *)URL parameters:(NSDictionary *)parameters completion:(void(^)(id data, NSURLResponse * response, NSError * error))completion;

- (void)GETXML:(NSString *)URL parameters:(NSDictionary *)parameters completion:(void(^)(id data, NSURLResponse * response, NSError * error))completion;

- (void)POST:(NSString *)URL parameters:(NSDictionary *)parameters builder:(TRBHTTPRequestBuilder *)builder parser:(TRBHTTPResponseParser *)parser completion:(void(^)(id data, NSURLResponse * response, NSError * error))completion;

- (void)downloadRequest:(NSURLRequest *)request progress:(void (^)(uint64_t bytesWritten, uint64_t totalBytesWritten, uint64_t totalBytesExpectedToWrite))progress completion:(void(^)(NSURL * location, NSURLResponse * response, NSError * error))completion;

- (void)resumeDownloadWithData:(NSData *)data progress:(void (^)(uint64_t bytesWritten, uint64_t totalBytesWritten, uint64_t totalBytesExpectedToWrite))progress completion:(void(^)(NSURL * location, NSURLResponse * response, NSError * error))completion;

- (void)resetWithCompletion:(void(^)(void))completion;
- (void)invalidateAndCancel;

@end

@interface TRBHTTPRequestBuilder : NSObject

@property (nonatomic, assign) BOOL percentEncodeParameters;
@property (nonatomic, assign) NSStringEncoding stringEncoding;

- (NSURLRequest *)buildRequest:(NSURLRequest *)request parameters:(NSDictionary *)parameters error:(NSError **)error;

@end

@interface TRBHTTPJSONRequestBuilder : TRBHTTPRequestBuilder
@end

@interface TRBHTTPResponseParser : NSObject

@property (nonatomic, readonly) NSMutableSet * acceptedMIMETypes;

- (void)parse:(NSData *)data response:(NSURLResponse *)response completion:(void(^)(id, NSError *))completion;
- (BOOL)shouldParseDataForResponse:(NSURLResponse *)response error:(NSError **)error;

@end

@interface TRBHTTPJSONResponseParser : TRBHTTPResponseParser
@end

@interface TRBHTTPXMLResponseParser : TRBHTTPResponseParser
@end
