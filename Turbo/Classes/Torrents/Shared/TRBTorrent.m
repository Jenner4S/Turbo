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

#import "TRBTorrent.h"

@interface TRBTorrent ()
@end

@implementation TRBTorrent

- (instancetype)initWithTransmissionJSON:(NSDictionary *)json {
	self = [super init];
	if (self) {
		_identifier = json[@"id"];
		_name = json[@"name"];
		_status = [json[@"status"] integerValue];
		_percentDone = json[@"percentDone"];
		_peersConnected = json[@"peersConnected"];
		_peersSendingToUs = json[@"peersSendingToUs"];
		_eta = json[@"eta"];
		_errorString = json[@"errorString"];
		_rateDownload = json[@"rateDownload"];
		_rateUpload = json[@"rateUpload"];
		_haveValid = json[@"haveValid"];
		_sizeWhenDone = json[@"sizeWhenDone"];
		_isFinished = json[@"isFinished"];
		_isPrivate = json[@"isPrivate"];
		_isStalled = json[@"isStalled"];
	}
	return self;
}

#pragma mark - Public Methods

- (BOOL)isEqualToTorrent:(TRBTorrent *)torrent {
	return [self.identifier isEqualToNumber:torrent.identifier];
}

#pragma mark - NSObject Overrides

- (BOOL)isEqual:(id)object {
	BOOL result = NO;
	if ([object isKindOfClass:[self class]])
		result = [self isEqualToTorrent:object];
	return result;
}

- (NSUInteger)hash {
	return [self.identifier hash];
}

@end
