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

#import "TRBAsyncOperation.h"

@interface TRBAsyncOperation ()
@property (nonatomic, assign, getter = isExecuting) BOOL executing;
@property (nonatomic, assign, getter = isFinished) BOOL finished;
@end

@implementation TRBAsyncOperation {
	void(^_block)(TRBAsyncOperation * op);
}

+ (instancetype)operationWithBlock:(void(^)(TRBAsyncOperation * op))block {
	return [[self alloc] initWithBlock:block];
}

- (instancetype)initWithBlock:(void(^)(TRBAsyncOperation * op))block {
	self = [super init];
	if (self) {
		_block = [block copy];
		_executing = NO;
		_finished = NO;
	}
	return self;
}

- (void)stop {
	self.finished = YES;
	self.executing = NO;
}

- (BOOL)isConcurrent {
	return YES;
}

- (void)setExecuting:(BOOL)executing {
	@synchronized(self) {
		[self willChangeValueForKey:@"isExecuting"];
		_executing = executing;
		[self didChangeValueForKey:@"isExecuting"];
	}
}

- (void)setFinished:(BOOL)finished {
	@synchronized(self) {
		[self willChangeValueForKey:@"isFinished"];
		_finished = finished;
		[self didChangeValueForKey:@"isFinished"];
	}
}

- (void)start {
	if (!self.isCancelled && _block) {
		self.executing = YES;
		dispatch_async(dispatch_get_main_queue(), ^{
			_block(self);
		});
	} else {
		self.finished = YES;
		self.executing = NO;
	}
}

@end