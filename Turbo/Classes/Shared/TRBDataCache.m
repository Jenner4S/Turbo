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

#import "TRBDataCache.h"

@implementation TRBDataCache {
	dispatch_queue_t _queue;
	NSString * _cacheDirectory;
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
		_queue = dispatch_queue_create("com.caffeineapps.TRBDataCacheQueue", DISPATCH_QUEUE_SERIAL);

		_cacheDirectory = [TRBLibraryDir() stringByAppendingPathComponent:@"Caches/TRBDataCache"];
		BOOL isDir = NO;
		if (![[NSFileManager defaultManager] fileExistsAtPath:_cacheDirectory isDirectory:&isDir] || !isDir) {
			[[NSFileManager defaultManager] createDirectoryAtPath:_cacheDirectory
									  withIntermediateDirectories:YES
													   attributes:@{NSFilePosixPermissions: @0777}
															error:NULL];
		}
	}
	return self;
}

#pragma mark - Public Methods

- (void)storeData:(NSData *)data withDomain:(NSString *)domain andPath:(NSString *)path {
	NSString * filePath = [[_cacheDirectory stringByAppendingPathComponent:domain] stringByAppendingPathComponent:path];
	NSString * dir = nil;
	NSRange range = [filePath rangeOfString:@"/" options:NSBackwardsSearch];
	if (range.location != NSNotFound)
		dir = [filePath substringToIndex:range.location];
	BOOL isDir = NO;
	if (![[NSFileManager defaultManager] fileExistsAtPath:dir isDirectory:&isDir] || !isDir) {
		[[NSFileManager defaultManager] createDirectoryAtPath:dir
								  withIntermediateDirectories:YES
												   attributes:@{NSFilePosixPermissions: @0777}
														error:NULL];
	}
	dispatch_async(_queue, ^{
		[data writeToFile:filePath atomically:YES];
	});
}

- (void)lookupDataWithDomain:(NSString *)domain path:(NSString *)path andHandler:(void(^)(NSData * data, NSError * error))handler {
	BOOL isDir = NO;
	NSString * filePath = [[_cacheDirectory stringByAppendingPathComponent:domain] stringByAppendingPathComponent:path];
	if ([[NSFileManager defaultManager] fileExistsAtPath:filePath isDirectory:&isDir] && !isDir) {
		dispatch_async(_queue, ^{
			NSError * error = nil;
			NSData * data = [NSData dataWithContentsOfFile:filePath options:NSDataReadingMappedIfSafe error:&error];
			if (error)
				data = nil;
			if (handler) {
				dispatch_async(dispatch_get_main_queue(), ^{
					handler(data, error);
				});
			}
		});
	} else if (handler) {
		NSError * error = [NSError errorWithDomain:NSStringFromClass([self class])
											  code:-666
										  userInfo:@{NSLocalizedDescriptionKey: @"Cached data does not exist"}];
		handler(nil, error);
	}
}

- (void)clearCache {
	BOOL isDir = NO;
	if ([[NSFileManager defaultManager] fileExistsAtPath:_cacheDirectory isDirectory:&isDir] && isDir) {
		dispatch_async(_queue, ^{
			NSError * error = nil;
			[[NSFileManager defaultManager] removeItemAtPath:_cacheDirectory error:&error];
			if (!error) {
				[[NSFileManager defaultManager] createDirectoryAtPath:_cacheDirectory
										  withIntermediateDirectories:YES
														   attributes:@{NSFilePosixPermissions: @0777}
																error:NULL];
			}
		});
	}
}

@end
