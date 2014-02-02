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

#import "TRBPioneerReceiverManager.h"

static NSString * const InputSources[TRBPRInputSourceUnknown] = {
	@"04",
	@"25",
	@"06",
	@"15",
	@"10",
	@"14",
	@"19",
	@"20",
	@"21",
	@"22",
	@"23",
	@"26",
	@"17",
	@"18",
	@"01",
	@"03",
	@"02",
	@"00",
	@"12",
	@"33",
	@"27",
	@"31",
};

static NSString * const PowerSymbol = @"PWR";
static NSString * const InputSourceSymbol = @"FN";

@interface TRBPioneerReceiverManager ()<NSStreamDelegate>

@end

@implementation TRBPioneerReceiverManager {
	NSInputStream * _inputStream;
	NSOutputStream * _outputStream;

	NSMutableArray * _pending;
	void(^_onOpen)(void);
	void(^_inputHandler)(NSString * response);
	void(^_onPowerOn)(void);
	void(^_onPowerOff)(void);
	void(^_onInputSourceChanged)(void);

	TRBPRInputSource _expectedInputSource;

	BOOL _sending;

	NSData * _endCommand;
	NSDictionary * _powerStateMapping;
	NSDictionary * _inputSourceMapping;
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
        _pending = [NSMutableArray new];
		_endCommand = [NSData dataWithBytes:"\r\n" length:2];
		_powerState = TRBPRPowerStateUnknown;
		_inputSource = TRBPRInputSourceUnknown;
		_expectedInputSource = TRBPRInputSourceUnknown;
		_powerStateMapping = @{@"PWR0": @(TRBPRPowerStateOn),
							   @"PWR1": @(TRBPRPowerStateOff)};
		_inputSourceMapping = @{InputSources[TRBPRInputSourceDVD]: @(TRBPRInputSourceDVD),
								InputSources[TRBPRInputSourceBD]: @(TRBPRInputSourceBD),
								InputSources[TRBPRInputSourceTVSAT]: @(TRBPRInputSourceTVSAT),
								InputSources[TRBPRInputSourceDVRBDR]: @(TRBPRInputSourceDVRBDR),
								InputSources[TRBPRInputSourceVideo1]: @(TRBPRInputSourceVideo1),
								InputSources[TRBPRInputSourceVideo2]: @(TRBPRInputSourceVideo2),
								InputSources[TRBPRInputSourceHDMI1]: @(TRBPRInputSourceHDMI1),
								InputSources[TRBPRInputSourceHDMI2]: @(TRBPRInputSourceHDMI2),
								InputSources[TRBPRInputSourceHDMI3]: @(TRBPRInputSourceHDMI3),
								InputSources[TRBPRInputSourceHDMI4]: @(TRBPRInputSourceHDMI4),
								InputSources[TRBPRInputSourceHDMI5]: @(TRBPRInputSourceHDMI5),
								InputSources[TRBPRInputSourceHomeMedia]: @(TRBPRInputSourceHomeMedia),
								InputSources[TRBPRInputSourceUSBiPod]: @(TRBPRInputSourceUSBiPod),
								InputSources[TRBPRInputSourceXMRadio]: @(TRBPRInputSourceXMRadio),
								InputSources[TRBPRInputSourceCD]: @(TRBPRInputSourceCD),
								InputSources[TRBPRInputSourceCDRTape]: @(TRBPRInputSourceCDRTape),
								InputSources[TRBPRInputSourceTuner]: @(TRBPRInputSourceTuner),
								InputSources[TRBPRInputSourcePhono]: @(TRBPRInputSourcePhono),
								InputSources[TRBPRInputSourceMultiChIn]: @(TRBPRInputSourceMultiChIn),
								InputSources[TRBPRInputSourceAdapterPort]: @(TRBPRInputSourceAdapterPort),
								InputSources[TRBPRInputSourceSirius]: @(TRBPRInputSourceSirius),
								InputSources[TRBPRInputSourceHDMICyclic]: @(TRBPRInputSourceHDMICyclic)};
    }
    return self;
}

#pragma mark - Public Methods

- (void)connectToAddress:(NSString *)address port:(UInt32)port inputHandler:(void(^)(NSString *))inputHandler onOpen:(void(^)(void))onOpen {
	if (_inputStream || _outputStream)
		[self disconnect];
	_onOpen = [onOpen copy];
	_inputHandler = [inputHandler copy];
	CFReadStreamRef readStream;
	CFWriteStreamRef writeStream;
	CFStreamCreatePairWithSocketToHost(NULL, (__bridge CFStringRef)address, port, &readStream, &writeStream);
	_inputStream = (NSInputStream *)CFBridgingRelease(readStream);
	_outputStream = (NSOutputStream *)CFBridgingRelease(writeStream);
	_inputStream.delegate = self;
	_outputStream.delegate = self;
	[_inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
	[_outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
	[_inputStream open];
	[_outputStream open];
}

- (void)disconnect {
	if (_inputStream && _outputStream) {
		_sending = NO;
		_isConnected = NO;
		[_inputStream close];
		[_inputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
		_inputStream = nil;
		[_outputStream close];
		[_outputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
		_outputStream = nil;
		_onOpen = nil;
		_onPowerOff = nil;
		_onPowerOn = nil;
		_onInputSourceChanged = nil;
		_powerState = TRBPRPowerStateUnknown;
		_inputSource = TRBPRInputSourceUnknown;
		_expectedInputSource = TRBPRInputSourceUnknown;
	}
}

- (void)powerOn:(void(^)(void))completion {
	if (_powerState != TRBPRPowerStateOn) {
		_onPowerOn = [completion copy];
		[self sendCommand:@"PO"];
	} else if (completion)
		completion();
}

- (void)powerOff:(void(^)(void))completion {
	if (_powerState != TRBPRPowerStateOff) {
		_onPowerOff = [completion copy];
		[self sendCommand:@"PF"];
	} else if (completion)
		completion();
}

- (void)changeToInput:(TRBPRInputSource)input completion:(void(^)(void))completion {
	if (input != _inputSource && input < TRBPRInputSourceUnknown) {
		_expectedInputSource = input;
		_onInputSourceChanged = [completion copy];
		NSString * inputSource = InputSources[input];
		NSString * command = [inputSource stringByAppendingString:InputSourceSymbol];
		[self sendCommand:command];
	} else if (completion && input == _inputSource)
		completion();
}

- (void)sendCommand:(NSString *)command {
	NSMutableData * data = [NSMutableData new];
	[data appendData:[command dataUsingEncoding:NSUTF8StringEncoding]];
	[data appendData:_endCommand];
	LogW(@"Sending Command: %@", command);
	[self sendData:data];
}

#pragma mark - NSStreamDelegate

- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)streamEvent {
	switch (streamEvent) {
		case NSStreamEventOpenCompleted: {
			LogV(@"Stream opened");
			if (stream == _outputStream) {
				_isConnected = YES;
				if (_powerState == TRBPRPowerStateUnknown)
					[self sendCommand:@"?P"];
			}
			break;
		} case NSStreamEventHasBytesAvailable: {
			LogV(@"Stream has bytes available");
			[self processHasBytesAvailable];
			break;
		} case NSStreamEventHasSpaceAvailable: {
			LogV(@"Stream has space available");
			[self processHasSpaceAvailable];
			break;
		} case NSStreamEventErrorOccurred: {
			LogV(@"Stream error occurred");
			[self disconnect];
			break;
		} case NSStreamEventEndEncountered: {
			LogV(@"Stream end encountered");
			[self disconnect];
			break;
		} default: {
			LogV(@"Unknown event");
			break;
		}
	}
}

#pragma mark - Private Methods

- (void)processHasBytesAvailable {
	static uint8_t buffer[1024];
	NSInteger i = [_inputStream read:buffer maxLength:1024];
	NSString * response = nil;
	if (i > 0)
		response = [[NSString alloc] initWithBytes:buffer length:i encoding:NSUTF8StringEncoding];
	response = [response stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	LogW(@"Read: %@", response);
	if ([response length]) {
		dispatch_async(dispatch_get_main_queue(), ^{
			if ([response hasPrefix:PowerSymbol])
				[self processPowerResponse:response];
			else if ([response hasPrefix:InputSourceSymbol])
				[self processInputSourceResponse:response];
			if (_onOpen && _powerState != TRBPRPowerStateUnknown/* && _inputSource != TRBPRInputSourceUnknown*/) {
				[self sendCommand:@"?F"];
				_onOpen();
				_onOpen = nil;
			}
			if (_inputHandler)
				_inputHandler(response);
			[self sendNext];
		});
	}
}

- (void)processPowerResponse:(NSString *)response {
	TRBPRPowerState oldState = _powerState;
	_powerState = [_powerStateMapping[response] unsignedIntegerValue];
	if (_onPowerOn && oldState != TRBPRPowerStateOn && _powerState == TRBPRPowerStateOn) {
		_onPowerOn();
		_onPowerOn = nil;
	} else if (oldState != TRBPRPowerStateOff && _powerState == TRBPRPowerStateOff) {
		[_pending removeAllObjects];
		_onInputSourceChanged = nil;
		_onPowerOn = nil;
		_inputSource = TRBPRInputSourceUnknown;
		_expectedInputSource = TRBPRInputSourceUnknown;
		if (_onPowerOff) {
			_onPowerOff();
			_onPowerOff = nil;
		}
	}
}

- (void)processInputSourceResponse:(NSString *)response {
	NSString * inputSource = [response stringByReplacingCharactersInRange:NSMakeRange(0, [InputSourceSymbol length]) withString:@""];
	_inputSource = [_inputSourceMapping[inputSource] unsignedIntegerValue];
	if (_onInputSourceChanged && _expectedInputSource == _inputSource) {
		_onInputSourceChanged();
		_onInputSourceChanged = nil;
	}
}

- (void)processHasSpaceAvailable {
	dispatch_async(dispatch_get_main_queue(), ^{
		if ([_pending count] && !_sending) {
			void(^pending)(void) = (void(^)(void))_pending[0];
			pending();
			[_pending removeObjectAtIndex:0];
		}
	});
}

- (void)sendData:(NSData *)data {
	dispatch_async(dispatch_get_main_queue(), ^{
		void(^pending)(void) = ^{
			_sending = YES;
			NSInteger bytesWritten = [_outputStream write:[data bytes] maxLength:[data length]];
			LogCV(bytesWritten != [data length], @"%i / %i bytes written", bytesWritten, [data length]);
		};
		if ([_outputStream hasSpaceAvailable] && !_sending) {
			pending();
		} else
			[_pending addObject:[pending copy]];
	});
}

- (void)sendNext {
    _sending = [_pending count] > 0 && [_outputStream hasSpaceAvailable];
    if (_sending) {
        void(^pending)(void) = (void(^)(void))_pending[0];
        pending();
        [_pending removeObjectAtIndex:0];
    }
}

@end
