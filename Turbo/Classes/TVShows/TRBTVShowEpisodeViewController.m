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

#import "TRBTVShowEpisodeViewController.h"
#import "TRBTVShowEpisode.h"
#import "TRBTVShowEpisode+TRBAddtions.h"
#import "TRBTvDBClient.h"

@interface TRBTVShowEpisodeViewController ()
@property (weak, nonatomic) IBOutlet UIImageView *episodeImageView;
@property (weak, nonatomic) IBOutlet UITextView *overviewTextView;
@end

@implementation TRBTVShowEpisodeViewController {
	TRBTVShowEpisode * _episode;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        self.preferredContentSize = CGSizeMake(320.0, 260.0);
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
	[self displayEpisode];
}

- (void)showEpisode:(TRBTVShowEpisode *)episode {
	_episode = episode;
	if (self.isViewLoaded)
		[self displayEpisode];
}

- (void)displayEpisode {
	self.navigationItem.title = _episode.episodeTitle;
	_overviewTextView.text = _episode.overview;
	if ([_episode.imagePath length]) {
		[[TRBTvDBClient sharedInstance] fetchSeriesBannerAtPath:_episode.imagePath completion:^(UIImage *image, NSError *error) {
			LogCE(error, [error localizedDescription]);
			_episodeImageView.image = image;
		}];
	}
}

@end
