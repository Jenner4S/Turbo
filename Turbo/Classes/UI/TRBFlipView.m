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

#import "TRBFlipView.h"

@implementation TRBFlipView

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
		[self setup];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
		[self setup];
    }
    return self;
}

- (void)setup {
	UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
	[self addGestureRecognizer:tapGesture];
}

- (void)setFrontView:(UIView *)view {
	if (_frontView != view) {
		[_frontView removeFromSuperview];
		_frontView = view;
		if (view.superview != self)
			[self addSubview:view];
		if (_state != TRBFlipViewStateNormal)
			view.hidden = YES;
		else
			_currentView = view;
	}
}

- (void)setBackView:(UIView *)view {
	if (_backView != view) {
		[_backView removeFromSuperview];
		_backView = view;
		if (view.superview != self)
			[self addSubview:view];
		if (_state != TRBFlipViewStateFlipped)
			view.hidden = YES;
		else
			_currentView = view;
	}
}

- (void)flip {
	if (_frontView && _backView) {
		[UIView transitionWithView:self
						  duration:.5
						   options:(_state == TRBFlipViewStateNormal ? UIViewAnimationOptionTransitionFlipFromRight : UIViewAnimationOptionTransitionFlipFromLeft)
						animations:^{
							if (_state == TRBFlipViewStateNormal) {
								_frontView.hidden = YES;
								_backView.hidden = NO;
								_state = TRBFlipViewStateFlipped;
								_currentView = _backView;
							} else {
								_frontView.hidden = NO;
								_backView.hidden = YES;
								_state = TRBFlipViewStateNormal;
								_currentView = _frontView;
							}
						} completion:nil];
	}
}

- (void)handleTap:(UITapGestureRecognizer *)sender {
	if (sender.state == UIGestureRecognizerStateEnded) {
		[self flip];
	}
}

@end
