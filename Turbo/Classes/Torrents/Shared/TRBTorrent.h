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

typedef NS_ENUM(NSInteger, TRBTorrentStatus) {
    TRBTorrentStatusUnknown = -1,
    
	TRBTorrentStatusStopped = 0,		/* Torrent is stopped */
	TRBTorrentStatusCheckWait,		/* Queued to check files */
	TRBTorrentStatusCheck,			/* Checking files */
	TRBTorrentStatusDownloadWait,	/* Queued to download */
	TRBTorrentStatusDownload,		/* Downloading */
	TRBTorrentStatusSeedWait,		/* Queued to seed */
	TRBTorrentStatusSeed,			/* Seeding */
	
	TRBTorrentStatusCount
};

@interface TRBTorrent : NSObject

@property (assign, nonatomic, readonly) TRBTorrentStatus status;
@property (strong, nonatomic, readonly) NSNumber * identifier;
@property (strong, nonatomic, readonly) NSString * name;
@property (strong, nonatomic, readonly) NSNumber * percentDone;
@property (strong, nonatomic, readonly) NSNumber * peersConnected;
@property (strong, nonatomic, readonly) NSNumber * peersSendingToUs;
@property (strong, nonatomic, readonly) NSNumber * eta;
@property (strong, nonatomic, readonly) NSString * errorString;
@property (strong, nonatomic, readonly) NSNumber * rateDownload;
@property (strong, nonatomic, readonly) NSNumber * rateUpload;
@property (strong, nonatomic, readonly) NSNumber * haveValid;
@property (strong, nonatomic, readonly) NSNumber * sizeWhenDone;
@property (strong, nonatomic, readonly) NSNumber * isFinished;
@property (strong, nonatomic, readonly) NSNumber * isPrivate;
@property (strong, nonatomic, readonly) NSNumber * isStalled;

- (instancetype)initWithTransmissionJSON:(NSDictionary *)json;
- (BOOL)isEqualToTorrent:(TRBTorrent *)torrent;

@end
