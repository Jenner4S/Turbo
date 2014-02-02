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

#import "TRBProgressView.h"

#define kCustomProgressViewFillOffsetX 1
#define kCustomProgressViewFillOffsetTopY 1
#define kCustomProgressViewFillOffsetBottomY 2

@implementation TRBProgressView {
    NSString * _image;
    TRBTorrentStatus _status;
}

#pragma mark - Public Methods

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _image = @"PB_Progress_BG";
        _status = TRBTorrentStatusUnknown;
    }
    return self;
}

- (void)updateWithStatus:(TRBTorrentStatus)status {
    if (_status != status) {
        switch (status) {
            case TRBTorrentStatusStopped:
                _image = @"PB_Progress_BG_gray";
                break;
            case TRBTorrentStatusCheckWait:
            case TRBTorrentStatusCheck:
                _image = @"PB_Progress_BG_red";
                break;
            case TRBTorrentStatusDownloadWait:
                _image = @"PB_Progress_BG_blue";
                break;
            case TRBTorrentStatusDownload:
                _image = @"PB_Progress_BG";
                break;
            case TRBTorrentStatusSeedWait:
            case TRBTorrentStatusSeed:
                _image = @"PB_Progress_BG_yellow";
                break;
            default:
                break;
        }
        [self setNeedsDisplay];
    }
    _status = status;
}

- (void)drawRect:(CGRect)rect {
    
    // Initialize the stretchable images.
    UIImage *background = [[UIImage imageNamed:@"PB_BG"] resizableImageWithCapInsets:UIEdgeInsetsMake(0.0, 2.0, 0.0, 2.0)
                                                                            resizingMode:UIImageResizingModeStretch];
    
    UIImage *fill = [[UIImage imageNamed:_image] resizableImageWithCapInsets:UIEdgeInsetsMake(0.0, 2.0, 0.0, 2.0)
                                                                               resizingMode:UIImageResizingModeStretch];
    
    // Draw the background in the current rect
    [background drawInRect:rect];
    
    // Compute the max width in pixels for the fill.  Max width being how
    // wide the fill should be at 100% progress.
    NSInteger maxWidth = rect.size.width - (2 * kCustomProgressViewFillOffsetX);
    
    // Compute the width for the current progress value, 0.0 - 1.0 corresponding
    // to 0% and 100% respectively.
	float progress = [self progress];
    NSInteger curWidth = floor(progress * maxWidth);
    
    // Create the rectangle for our fill image accounting for the position offsets,
    // 1 in the X direction and 1, 3 on the top and bottom for the Y.
    CGRect fillRect = CGRectMake(rect.origin.x + kCustomProgressViewFillOffsetX,
                                 rect.origin.y + kCustomProgressViewFillOffsetTopY,
                                 curWidth,
                                 rect.size.height - kCustomProgressViewFillOffsetBottomY);
    
    // Draw the fill
    [fill drawInRect:fillRect];
}

@end
