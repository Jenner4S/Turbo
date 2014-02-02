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

typedef NS_ENUM(NSUInteger, TRBPRPowerState) {
	TRBPRPowerStateUnknown = 0,
	TRBPRPowerStateOn,
	TRBPRPowerStateOff,
};

typedef NS_ENUM(NSUInteger, TRBPRInputSource) {
	TRBPRInputSourceDVD = 0,
	TRBPRInputSourceBD,
	TRBPRInputSourceTVSAT,
	TRBPRInputSourceDVRBDR,
	TRBPRInputSourceVideo1,
	TRBPRInputSourceVideo2,
	TRBPRInputSourceHDMI1,
	TRBPRInputSourceHDMI2,
	TRBPRInputSourceHDMI3,
	TRBPRInputSourceHDMI4,
	TRBPRInputSourceHDMI5,
	TRBPRInputSourceHomeMedia,
	TRBPRInputSourceUSBiPod,
	TRBPRInputSourceXMRadio,
	TRBPRInputSourceCD,
	TRBPRInputSourceCDRTape,
	TRBPRInputSourceTuner,
	TRBPRInputSourcePhono,
	TRBPRInputSourceMultiChIn,
	TRBPRInputSourceAdapterPort,
	TRBPRInputSourceSirius,
	TRBPRInputSourceHDMICyclic,

	TRBPRInputSourceUnknown
};

@interface TRBPioneerReceiverManager : NSObject

@property (nonatomic, readonly) TRBPRPowerState powerState;
@property (nonatomic, readonly) TRBPRInputSource inputSource;
@property (nonatomic, readonly) BOOL isConnected;

+ (instancetype)sharedInstance;

- (void)connectToAddress:(NSString *)address port:(UInt32)port inputHandler:(void(^)(NSString *))inputHandler onOpen:(void(^)(void))onOpen;
- (void)disconnect;
- (void)powerOn:(void(^)(void))completion;
- (void)powerOff:(void(^)(void))completion;
- (void)changeToInput:(TRBPRInputSource)input completion:(void(^)(void))completion;
- (void)sendCommand:(NSString *)command;

@end
