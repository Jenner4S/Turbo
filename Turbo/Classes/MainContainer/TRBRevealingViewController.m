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

#import "TRBRevealingViewController.h"
#import <objc/runtime.h>

#define TRBStateIsConcealed(state) (state == TRBRevealingViewControllerStateConcealed)
#define TRBStateIsRevealed(state) (state != TRBRevealingViewControllerStateConcealed && state != TRBRevealingViewControllerStateInitial)
#define kDefaultAnimationDuration 0.25

#define kDefaultInset 44.0
#define kShadowSize 1.0

typedef NS_ENUM(NSUInteger, TRBPanDirection) {
	TRBPanDirectionUnknown = 0,
	TRBPanDirectionLeft = 1 << 1,
	TRBPanDirectionRight = 1 << 2,
	TRBPanDirectionUp = 1 << 3,
	TRBPanDirectionDown = 1 << 4,
	TRBPanDirectionHorizontal = TRBPanDirectionLeft|TRBPanDirectionRight,
	TRBPanDirectionVertical = TRBPanDirectionUp|TRBPanDirectionDown,
};

#define TRBIsDirectionHorizontal(direction) (direction & TRBPanDirectionHorizontal)
#define TRBIsDirectionVertical(direction) (direction & TRBPanDirectionVertical)
#define TRBReverseDirection(direction) ((direction & (TRBPanDirectionLeft|TRBPanDirectionUp)) ? direction << 1 : direction >> 1)

static const char TRBRevealingViewControllerKey;

__attribute__((always_inline)) static inline CGPoint TRBMovementForPoints(CGPoint currentPoint, CGPoint previousPoint, TRBPanDirection direction);
__attribute__((always_inline)) static inline TRBPanDirection TRBDirectionFromVelocity(CGPoint velocity);
__attribute__((always_inline)) static inline CGRect TRBFrameForLeftViewController(TRBRevealingViewController * revealingViewController);
__attribute__((always_inline)) static inline CGRect TRBFrameForRightViewController(TRBRevealingViewController * revealingViewController);
__attribute__((always_inline)) static inline CGRect TRBFrameForTopViewController(TRBRevealingViewController * revealingViewController);
__attribute__((always_inline)) static inline CGRect TRBFrameForBottomViewController(TRBRevealingViewController * revealingViewController);

@interface TRBRevealingViewController ()

@end

@implementation TRBRevealingViewController {
	__weak UIViewController * _revealedViewController;
	__weak UIViewController * _revealingViewController;

	__weak UIScreenEdgePanGestureRecognizer * _leftEdgePanGestureRecognizer;
	__weak UIScreenEdgePanGestureRecognizer * _rightEdgePanGestureRecognizer;
	__weak UIScreenEdgePanGestureRecognizer * _topEdgePanGestureRecognizer;
	__weak UIScreenEdgePanGestureRecognizer * _bottomEdgePanGestureRecognizer;

	TRBRevealingViewControllerState _initialState;
	TRBPanDirection _initialPanDirection;
	TRBPanDirection _currentPanDirection;

	CGPoint _previousTouchLocation;
	CGPoint _finalVelocity;
	CGAffineTransform _initialTransform;
	UIInterfaceOrientation _fromInterfaceOrientation;

	BOOL _mainIsMoving;
	BOOL _viewIsVisible;

@package

	UIEdgeInsets _edgeInsets;
}

#pragma mark - Initialization

- (id)init {
    self = [super init];
    if (self) {
		_edgeInsets = UIEdgeInsetsMake(kDefaultInset, kDefaultInset, kDefaultInset, kDefaultInset);
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
	self = [super initWithCoder:aDecoder];
	if (self) {
		_edgeInsets = UIEdgeInsetsMake(kDefaultInset, kDefaultInset, kDefaultInset, kDefaultInset);
	}
	return self;
}

- (id)initWithControllers:(NSArray *)controllers {
    self = [super init];
    if (self) {
		_edgeInsets = UIEdgeInsetsMake(kDefaultInset, kDefaultInset, kDefaultInset, kDefaultInset);
		NSUInteger count = [controllers count];
		id controller = nil;
		switch (count) {
			case 5:
				controller = controllers[4];
				if (controller != [NSNull null])
					[self setBottomViewController:controller];
			case 4:
				controller = controllers[3];
				if (controller != [NSNull null])
					[self setTopViewController:controller];
			case 3:
				controller = controllers[2];
				if (controller != [NSNull null])
					[self setRightViewController:controller];
			case 2:
				controller = controllers[1];
				if (controller != [NSNull null])
					[self setLeftViewController:controller];
			case 1:
				controller = controllers[0];
				if (controller != [NSNull null])
					[self setMainViewController:controller];
			default:
				break;
		}
		_state = TRBRevealingViewControllerStateConcealed;
    }
    return self;
}

- (void)dealloc {
	[self setMainViewController:nil];
	[self setLeftViewController:nil];
	[self setRightViewController:nil];
	[self setTopViewController:nil];
    [self setBottomViewController:nil];
}

#pragma mark - View Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
	[self loadControllersFromStoryboard];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	_viewIsVisible = YES;
	if (_revealedViewController && _fromInterfaceOrientation != self.interfaceOrientation) {
		if ([_delegate respondsToSelector:@selector(revealingViewController:willAdjustToInterfaceOrientation:)])
			[_delegate revealingViewController:self willAdjustToInterfaceOrientation:self.interfaceOrientation];
		[self adjustToInterfaceOrientation];
		if ([_delegate respondsToSelector:@selector(revealingViewController:didAdjustFromInterfaceOrientation:)])
			[_delegate revealingViewController:self didAdjustFromInterfaceOrientation:_fromInterfaceOrientation];
	}
	[_mainViewController beginAppearanceTransition:YES animated:animated];
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	[_mainViewController endAppearanceTransition];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	_viewIsVisible = NO;
	[_mainViewController beginAppearanceTransition:NO animated:animated];
}

- (void)viewDidDisappear:(BOOL)animated {
	[super viewDidDisappear:animated];
	_fromInterfaceOrientation = self.interfaceOrientation;
	[_mainViewController endAppearanceTransition];
}

- (BOOL)shouldAutomaticallyForwardAppearanceMethods {
	return NO;
}

- (BOOL)shouldAutomaticallyForwardRotationMethods {
	return YES;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
	if ([_delegate respondsToSelector:@selector(revealingViewController:willAdjustToInterfaceOrientation:)])
		[_delegate revealingViewController:self willAdjustToInterfaceOrientation:toInterfaceOrientation];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
	if (_revealedViewController) {
		[self adjustToInterfaceOrientation];
	}
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
	if ([_delegate respondsToSelector:@selector(revealingViewController:didAdjustFromInterfaceOrientation:)])
		[_delegate revealingViewController:self didAdjustFromInterfaceOrientation:fromInterfaceOrientation];
}

- (void)viewWillLayoutSubviews {
	_leftViewController.view.frame = TRBFrameForLeftViewController(self);
	_rightViewController.view.frame = TRBFrameForRightViewController(self);
	_topViewController.view.frame = TRBFrameForTopViewController(self);
	_bottomViewController.view.frame = TRBFrameForBottomViewController(self);
}

- (BOOL)shouldAutorotate {
	BOOL result = YES;
	if (_mainViewController)
		result = [_mainViewController shouldAutorotate];
	return result;
}

- (NSUInteger)supportedInterfaceOrientations {
	NSUInteger result = UIInterfaceOrientationMaskAll;
	if (_mainViewController)
		result = [_mainViewController supportedInterfaceOrientations];
	return result;
}

- (UIViewController *)childViewControllerForStatusBarHidden {
	return _mainViewController;
}

- (UIViewController *)childViewControllerForStatusBarStyle {
	return _mainViewController;
}

#pragma mark - Custom Setters

- (void)setMainViewController:(UIViewController *)mainViewController {
	UIViewController * oldController = _mainViewController;
	_mainViewController = mainViewController;
	if (oldController != _mainViewController) {
		if (_mainViewController) {
			objc_setAssociatedObject(_mainViewController, &TRBRevealingViewControllerKey, self, OBJC_ASSOCIATION_ASSIGN);
			[self addChildViewController:_mainViewController];
			_mainViewController.view.transform = CGAffineTransformIdentity;
			_mainViewController.view.frame = self.view.bounds;
		}
		if (oldController) {
			_mainViewController.view.transform = oldController.view.transform;
			_mainViewController.view.layer.shadowOpacity = oldController.view.layer.shadowOpacity;
			_mainViewController.view.layer.shadowOffset = oldController.view.layer.shadowOffset;
			[self removeController:oldController isDisappearing:YES];
		}
		if (_state == TRBRevealingViewControllerStateInitial)
			_state = TRBRevealingViewControllerStateConcealed;
		if (_mainViewController && !_viewIsVisible)
			[self.view addSubview:_mainViewController.view];
		else if (_mainViewController) {
			[_mainViewController beginAppearanceTransition:YES animated:NO];
			[self.view addSubview:_mainViewController.view];
			[_mainViewController endAppearanceTransition];
		}
		[_mainViewController didMoveToParentViewController:self];
	}
}

- (void)setLeftViewController:(UIViewController *)leftViewController {
	UIViewController * oldController = _leftViewController;
	_leftViewController = leftViewController;
	if (oldController != _leftViewController) {
		if (_leftViewController) {
			objc_setAssociatedObject(_leftViewController, &TRBRevealingViewControllerKey, self, OBJC_ASSOCIATION_ASSIGN);
			[self addChildViewController:_leftViewController];
			_leftViewController.view.frame = TRBFrameForLeftViewController(self);
		}
		if (oldController) {
			BOOL leftRevealed = _state == TRBRevealingViewControllerStateLeftRevealed;
			[self removeController:oldController isDisappearing:leftRevealed];
			if (_leftViewController && leftRevealed) {
				[_leftViewController beginAppearanceTransition:YES animated:NO];
				[self.view insertSubview:_leftViewController.view belowSubview:_mainViewController.view];
				[_leftViewController endAppearanceTransition];
				_revealedViewController = _leftViewController;
			}
		}
		[_leftViewController didMoveToParentViewController:self];
	}
	if (_leftViewController && !_leftEdgePanGestureRecognizer) {
		[self addLeftEdgePanGestureRecognizer];
		if (!_rightEdgePanGestureRecognizer)
			[self addRightEdgePanGestureRecognizer];
	} else if (!_leftViewController && !_rightViewController) {
		[self.view removeGestureRecognizer:_leftEdgePanGestureRecognizer];
		[self.view removeGestureRecognizer:_rightEdgePanGestureRecognizer];
	}
}

- (void)setRightViewController:(UIViewController *)rightViewController {
	UIViewController * oldController = _rightViewController;
	_rightViewController = rightViewController;
	if (oldController != _rightViewController) {
		if (_rightViewController) {
			objc_setAssociatedObject(_rightViewController, &TRBRevealingViewControllerKey, self, OBJC_ASSOCIATION_ASSIGN);
			[self addChildViewController:_rightViewController];
			_rightViewController.view.frame = TRBFrameForRightViewController(self);
		}
		if (oldController) {
			BOOL rightRevealed = _state == TRBRevealingViewControllerStateRightRevealed;
			[self removeController:oldController isDisappearing:rightRevealed];
			if (_rightViewController && rightRevealed) {
				[_rightViewController beginAppearanceTransition:YES animated:NO];
				[self.view insertSubview:_rightViewController.view belowSubview:_mainViewController.view];
				[_rightViewController endAppearanceTransition];
				_revealedViewController = _rightViewController;
			}
		}
		[_rightViewController didMoveToParentViewController:self];
	}
	if (_rightViewController && !_rightEdgePanGestureRecognizer) {
		[self addRightEdgePanGestureRecognizer];
		if (!_leftEdgePanGestureRecognizer)
			[self addLeftEdgePanGestureRecognizer];
	} else if (!_rightViewController && !_leftViewController) {
		[self.view removeGestureRecognizer:_rightEdgePanGestureRecognizer];
		[self.view removeGestureRecognizer:_leftEdgePanGestureRecognizer];
	}
}

- (void)setTopViewController:(UIViewController *)topViewController {
	UIViewController * oldController = _topViewController;
	_topViewController = topViewController;
	if (oldController != _topViewController) {
		if (_topViewController) {
			objc_setAssociatedObject(_topViewController, &TRBRevealingViewControllerKey, self, OBJC_ASSOCIATION_ASSIGN);
			[self addChildViewController:_topViewController];
			_topViewController.view.frame = TRBFrameForTopViewController(self);
		}
		if (oldController) {
			BOOL topRevealed = _state == TRBRevealingViewControllerStateTopRevealed;
			[self removeController:oldController isDisappearing:topRevealed];
			if (_topViewController && topRevealed) {
				[_topViewController beginAppearanceTransition:YES animated:NO];
				[self.view insertSubview:_topViewController.view belowSubview:_mainViewController.view];
				[_topViewController endAppearanceTransition];
				_revealedViewController = _topViewController;
			}
		}
		[_topViewController didMoveToParentViewController:self];
	}
	if (_topViewController && !_topEdgePanGestureRecognizer) {
		[self addTopEdgePanGestureRecognizer];
		if (!_bottomEdgePanGestureRecognizer)
			[self addBottomEdgePanGestureRecognizer];
	} else if (!_topViewController && !_bottomViewController) {
		[self.view removeGestureRecognizer:_topEdgePanGestureRecognizer];
		[self.view removeGestureRecognizer:_bottomEdgePanGestureRecognizer];
	}
}

- (void)setBottomViewController:(UIViewController *)bottomViewController {
	UIViewController * oldController = _bottomViewController;
	_bottomViewController = bottomViewController;
	if (oldController != _bottomViewController) {
		if (_bottomViewController) {
			objc_setAssociatedObject(_bottomViewController, &TRBRevealingViewControllerKey, self, OBJC_ASSOCIATION_ASSIGN);
			[self addChildViewController:_bottomViewController];
			_bottomViewController.view.frame = TRBFrameForBottomViewController(self);
		}
		if (oldController) {
			BOOL bottomRevealed = _state == TRBRevealingViewControllerStateBottomRevealed;
			[self removeController:oldController isDisappearing:bottomRevealed];
			if (_bottomViewController && bottomRevealed) {
				[_bottomViewController beginAppearanceTransition:YES animated:NO];
				[self.view insertSubview:_bottomViewController.view belowSubview:_mainViewController.view];
				[_bottomViewController endAppearanceTransition];
				_revealedViewController = _bottomViewController;
			}
		}
		[_bottomViewController didMoveToParentViewController:self];
	}
	if (_bottomViewController && !_bottomEdgePanGestureRecognizer) {
		[self addBottomEdgePanGestureRecognizer];
		if (!_topEdgePanGestureRecognizer)
			[self addTopEdgePanGestureRecognizer];
	} else if (!_bottomViewController && !_topViewController) {
		[self.view removeGestureRecognizer:_bottomEdgePanGestureRecognizer];
		[self.view removeGestureRecognizer:_topEdgePanGestureRecognizer];
	}
}

- (void)setLeftInset:(CGFloat)leftInset animated:(BOOL)animated {
	_edgeInsets.left = leftInset;
	if (_state == TRBRevealingViewControllerStateRightRevealed) {
		CGRect bounds = self.view.bounds;
		CGPoint movement = CGPointMake(-(CGRectGetWidth(bounds) - _edgeInsets.left), 0.0);
		CGRect revealedFrame = TRBFrameForRightViewController(self);
		[UIView animateWithDuration:animated ? kDefaultAnimationDuration : 0.0
						 animations:^{
							 _mainViewController.view.transform = CGAffineTransformMakeTranslation(movement.x, movement.y);
							 _revealedViewController.view.frame = revealedFrame;
						 }];
	}
}

- (void)setRightInset:(CGFloat)rightInset animated:(BOOL)animated {
	_edgeInsets.right = rightInset;
	if (_state == TRBRevealingViewControllerStateLeftRevealed) {
		CGRect bounds = self.view.bounds;
		CGPoint movement = CGPointMake(CGRectGetWidth(bounds) - _edgeInsets.right, 0.0);
		CGRect revealedFrame = TRBFrameForLeftViewController(self);
		[UIView animateWithDuration:animated ? kDefaultAnimationDuration : 0.0
						 animations:^{
							 _mainViewController.view.transform = CGAffineTransformMakeTranslation(movement.x, movement.y);
							 _revealedViewController.view.frame = revealedFrame;
						 }];
	}
}

- (void)setTopInset:(CGFloat)topInset animated:(BOOL)animated {
	_edgeInsets.top = topInset;
	if (_state == TRBRevealingViewControllerStateBottomRevealed) {
		CGRect bounds = self.view.bounds;
		CGPoint movement = CGPointMake(0.0, -(CGRectGetHeight(bounds) - _edgeInsets.top));
		CGRect revealedFrame = TRBFrameForBottomViewController(self);
		[UIView animateWithDuration:animated ? kDefaultAnimationDuration : 0.0
						 animations:^{
							 _mainViewController.view.transform = CGAffineTransformMakeTranslation(movement.x, movement.y);
							 _revealedViewController.view.frame = revealedFrame;
						 }];
	}
}

- (void)setBottomInset:(CGFloat)bottomInset animated:(BOOL)animated {
	_edgeInsets.bottom = bottomInset;
	if (_state == TRBRevealingViewControllerStateTopRevealed) {
		CGRect bounds = self.view.bounds;
		CGPoint movement = CGPointMake(0.0, CGRectGetHeight(bounds) - _edgeInsets.bottom);
		CGRect revealedFrame = TRBFrameForTopViewController(self);
		[UIView animateWithDuration:animated ? kDefaultAnimationDuration : 0.0
						 animations:^{
							 _mainViewController.view.transform = CGAffineTransformMakeTranslation(movement.x, movement.y);
							 _revealedViewController.view.frame = revealedFrame;
						 }];
	}
}

- (void)setFriction:(CGFloat)friction {
	_friction = MIN(MAX(friction, -1.0), 1.0); // must be between -1.0 and 1.0
}

#pragma mark - Public Methods

- (void)concealViewControllerAnimated:(BOOL)animated completion:(void (^)(void))completion {
	if (TRBStateIsRevealed(_state)) {
		if ([_delegate respondsToSelector:@selector(revealingViewController:willConcealViewController:)])
			[_delegate revealingViewController:self willConcealViewController:_revealedViewController];
		[_revealedViewController beginAppearanceTransition:NO animated:animated];
		[self concealViewController:_revealedViewController animated:animated completion:^{
			_revealedViewController = nil;
			if (completion)
				completion();
		}];
	} else if (completion)
		completion();
}

- (void)revealLeftViewControllerAnimated:(BOOL)animated completion:(void (^)(void))completion {
	[self concealViewControllerAnimated:animated completion:^{
		if (_leftViewController) {
			if ([_delegate respondsToSelector:@selector(revealingViewController:willRevealViewController:andTransitionToState:)])
				[_delegate revealingViewController:self willRevealViewController:_leftViewController andTransitionToState:TRBRevealingViewControllerStateLeftRevealed];
			CGFloat width = CGRectGetWidth(self.view.bounds);
			CGFloat movement = width - _edgeInsets.right;
			[_leftViewController beginAppearanceTransition:YES animated:animated];
			[self.view insertSubview:_leftViewController.view belowSubview:_mainViewController.view];
			[self revealViewController:_leftViewController withMovement:CGPointMake(movement, 0.0) animated:animated completion:^{
				_state = TRBRevealingViewControllerStateLeftRevealed;
				if (completion)
					completion();
			}];
		} else if (completion)
			completion();
	}];
}

- (void)revealRightViewControllerAnimated:(BOOL)animated completion:(void (^)(void))completion {
	[self concealViewControllerAnimated:animated completion:^{
		if (_rightViewController) {
			if ([_delegate respondsToSelector:@selector(revealingViewController:willRevealViewController:andTransitionToState:)])
				[_delegate revealingViewController:self willRevealViewController:_rightViewController andTransitionToState:TRBRevealingViewControllerStateRightRevealed];
			CGFloat width = CGRectGetWidth(self.view.bounds);
			CGFloat movement = width - _edgeInsets.left;
			[_rightViewController beginAppearanceTransition:YES animated:animated];
			[self.view insertSubview:_rightViewController.view belowSubview:_mainViewController.view];
			[self revealViewController:_rightViewController withMovement:CGPointMake(-movement, 0.0) animated:animated completion:^{
				_state = TRBRevealingViewControllerStateRightRevealed;
				if (completion)
					completion();
			}];
		} else if (completion)
			completion();
	}];
}

- (void)revealTopViewControllerAnimated:(BOOL)animated completion:(void (^)(void))completion {
	[self concealViewControllerAnimated:animated completion:^{
		if (_topViewController) {
			if ([_delegate respondsToSelector:@selector(revealingViewController:willRevealViewController:andTransitionToState:)])
				[_delegate revealingViewController:self willRevealViewController:_topViewController andTransitionToState:TRBRevealingViewControllerStateTopRevealed];
			CGFloat height = CGRectGetHeight(self.view.bounds);
			CGFloat movement = height - _edgeInsets.bottom;
			[_topViewController beginAppearanceTransition:YES animated:animated];
			[self.view insertSubview:_topViewController.view belowSubview:_mainViewController.view];
			[self revealViewController:_topViewController withMovement:CGPointMake(0.0, movement) animated:animated completion:^{
				_state = TRBRevealingViewControllerStateTopRevealed;
				if (completion)
					completion();
			}];
		} else if (completion)
			completion();
	}];
}

- (void)revealBottomViewControllerAnimated:(BOOL)animated completion:(void (^)(void))completion {
	[self concealViewControllerAnimated:animated completion:^{
		if (_bottomViewController) {
			if ([_delegate respondsToSelector:@selector(revealingViewController:willRevealViewController:andTransitionToState:)])
				[_delegate revealingViewController:self willRevealViewController:_bottomViewController andTransitionToState:TRBRevealingViewControllerStateBottomRevealed];
			CGFloat height = CGRectGetHeight(self.view.bounds);
			CGFloat movement = height - _edgeInsets.top;
			[_bottomViewController beginAppearanceTransition:YES animated:animated];
			[self.view insertSubview:_bottomViewController.view belowSubview:_mainViewController.view];
			[self revealViewController:_bottomViewController withMovement:CGPointMake(0.0, -movement) animated:animated completion:^{
				_state = TRBRevealingViewControllerStateBottomRevealed;
				if (completion) {
					completion();
				}
			}];
		} else if (completion)
			completion();
	}];
}

#pragma mark - Private Methods

- (void)loadControllersFromStoryboard {
    if (self.storyboard) {
		if ([_storyboardIDForLeftViewController length])
			[self setLeftViewController:[self.storyboard instantiateViewControllerWithIdentifier:_storyboardIDForLeftViewController]];
		if ([_storyboardIDForRightViewController length])
			[self setRightViewController:[self.storyboard instantiateViewControllerWithIdentifier:_storyboardIDForRightViewController]];
		if ([_storyboardIDForTopViewController length])
			[self setTopViewController:[self.storyboard instantiateViewControllerWithIdentifier:_storyboardIDForTopViewController]];
		if ([_storyboardIDForBottomViewController length])
			[self setBottomViewController:[self.storyboard instantiateViewControllerWithIdentifier:_storyboardIDForBottomViewController]];
		if ([_storyboardIDForMainViewController length])
			[self setMainViewController:[self.storyboard instantiateViewControllerWithIdentifier:_storyboardIDForMainViewController]];
	}
}

- (void)concealViewController:(UIViewController *)controller animated:(BOOL)animated completion:(void(^)(void))completion {
	NSTimeInterval duration = animated ? kDefaultAnimationDuration : 0.0;
	[UIView animateWithDuration:duration
					 animations:^{
						 _mainViewController.view.transform = CGAffineTransformMakeTranslation(0.0, 0.0);
					 }
					 completion:^(BOOL finished) {
						 _mainViewController.view.layer.shadowOpacity = 0.0;
						 _mainViewController.view.layer.shadowOffset = CGSizeMake(0.0, -kShadowSize);
						 _state = TRBRevealingViewControllerStateConcealed;
						 controller.view.alpha = 0.0;
						 [controller endAppearanceTransition];
						 [_mainViewController.view setUserInteractionEnabled:YES];
						 if ([_delegate respondsToSelector:@selector(revealingViewController:didConcealViewController:)])
							 [_delegate revealingViewController:self didConcealViewController:controller];
						 if (completion)
							 completion();
					 }];
}

- (void)revealViewController:(UIViewController *)controller withMovement:(CGPoint)movement animated:(BOOL)animated completion:(void(^)(void))completion {
	NSTimeInterval duration = animated ? kDefaultAnimationDuration : 0.0;
	_mainViewController.view.layer.shadowOpacity = 1.0;
	_mainViewController.view.layer.shadowOffset = CGSizeMake((movement.x <= 0.0 ? kShadowSize : -kShadowSize), (movement.y <= 0.0 ? kShadowSize : -kShadowSize));
	controller.view.alpha = 1.0;
	[UIView animateWithDuration:duration
					 animations:^{
						 _mainViewController.view.transform = CGAffineTransformMakeTranslation(movement.x, movement.y);
					 }
					 completion:^(BOOL finished) {
						 [controller endAppearanceTransition];
						 _revealedViewController = controller;
						 [_mainViewController.view setUserInteractionEnabled:NO];
						 if ([_delegate respondsToSelector:@selector(revealingViewController:didRevealViewController:)])
							 [_delegate revealingViewController:self didRevealViewController:_revealedViewController];
						 completion();
					 }];
}

- (void)adjustToInterfaceOrientation {
    CGPoint movement = CGPointZero;
    CGRect bounds = self.view.bounds;
	CGRect revealedFrame = CGRectZero;
    switch (_state) {
        case TRBRevealingViewControllerStateLeftRevealed:
            movement = CGPointMake(CGRectGetWidth(bounds) - _edgeInsets.right, 0.0);
			revealedFrame = TRBFrameForLeftViewController(self);
            break;
        case TRBRevealingViewControllerStateRightRevealed:
            movement = CGPointMake(-(CGRectGetWidth(bounds) - _edgeInsets.left), 0.0);
			revealedFrame = TRBFrameForRightViewController(self);
            break;
        case TRBRevealingViewControllerStateTopRevealed:
            movement = CGPointMake(0.0, CGRectGetHeight(bounds) - _edgeInsets.bottom);
			revealedFrame = TRBFrameForTopViewController(self);
            break;
        case TRBRevealingViewControllerStateBottomRevealed:
            movement = CGPointMake(0.0, -(CGRectGetHeight(bounds) - _edgeInsets.top));
			revealedFrame = TRBFrameForBottomViewController(self);
            break;
        default:
            break;
    }
    _mainViewController.view.transform = CGAffineTransformMakeTranslation(movement.x, movement.y);
    _revealedViewController.view.frame = revealedFrame;
}

- (void)addLeftEdgePanGestureRecognizer {
	UIScreenEdgePanGestureRecognizer * leftEdgePan = [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanGesture:)];
	leftEdgePan.edges = UIRectEdgeLeft;
	if ([_mainViewController isKindOfClass:[UINavigationController class]]) {
		UINavigationController * navController = (UINavigationController *)_mainViewController;
		[leftEdgePan requireGestureRecognizerToFail:navController.interactivePopGestureRecognizer];
	}
	[self.view addGestureRecognizer:leftEdgePan];
	_leftEdgePanGestureRecognizer = leftEdgePan;
}

- (void)addRightEdgePanGestureRecognizer {
	UIScreenEdgePanGestureRecognizer * rightEdgePan = [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanGesture:)];
	rightEdgePan.edges = UIRectEdgeRight;
	[self.view addGestureRecognizer:rightEdgePan];
	_rightEdgePanGestureRecognizer = rightEdgePan;
}

- (void)addTopEdgePanGestureRecognizer {
	UIScreenEdgePanGestureRecognizer * topEdgePan = [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanGesture:)];
	topEdgePan.edges = UIRectEdgeTop;
	[self.view addGestureRecognizer:topEdgePan];
	_topEdgePanGestureRecognizer = topEdgePan;
}

- (void)addBottomEdgePanGestureRecognizer {
	UIScreenEdgePanGestureRecognizer * bottomEdgePan = [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanGesture:)];
	bottomEdgePan.edges = UIRectEdgeBottom;
	[self.view addGestureRecognizer:bottomEdgePan];
	_bottomEdgePanGestureRecognizer = bottomEdgePan;
}

#pragma mark Handle Panning

- (void)handlePanGesture:(UIPanGestureRecognizer *)gestureRecognizer {
	switch (gestureRecognizer.state) {
		case UIGestureRecognizerStateBegan:
			[self handlePanBegan:gestureRecognizer];
			break;
		case UIGestureRecognizerStateChanged:
			[self handlePanChanged:gestureRecognizer];
			break;
		case UIGestureRecognizerStateEnded:
			[self handlePanEnded:gestureRecognizer];
			break;
		case UIGestureRecognizerStateCancelled:
			[self handlePanCancelled];
			break;
		default:
			break;
	}
}

- (void)handlePanBegan:(UIPanGestureRecognizer *)gestureRecognizer {
	_mainIsMoving = NO;
	_initialState = _state;
    _previousTouchLocation = [gestureRecognizer locationInView:self.view];
    CGPoint velocity = [gestureRecognizer velocityInView:self.view];
	_initialPanDirection = TRBDirectionFromVelocity(velocity);
    _mainViewController.view.layer.shadowOpacity = 1.0;
	_initialTransform = _mainViewController.view.transform;
	if (TRBStateIsRevealed(_state))
		_state = TRBRevealingViewControllerStateSlidingIn;
	else if (TRBStateIsConcealed(_state)) {
		_mainViewController.view.layer.shadowOffset = CGSizeMake((_initialPanDirection == TRBPanDirectionLeft ? kShadowSize : -kShadowSize),
																	 (_initialPanDirection == TRBPanDirectionUp ? kShadowSize : -kShadowSize));
		[self updateRevealingViewController];
		if (_revealingViewController)
			_state = TRBRevealingViewControllerStateSlidingOut;
	}
}

- (void)handlePanChanged:(UIPanGestureRecognizer *)gestureRecognizer {
	if (_state == TRBRevealingViewControllerStateSlidingOut || _state == TRBRevealingViewControllerStateSlidingIn) {
		CGPoint velocity = [gestureRecognizer velocityInView:self.view];
		_currentPanDirection = TRBDirectionFromVelocity(velocity);
		if (!_mainIsMoving && _state == TRBRevealingViewControllerStateSlidingIn)
			_initialPanDirection = _currentPanDirection;
		CGPoint location = [gestureRecognizer locationInView:self.view];
		CGPoint movement = TRBMovementForPoints(location, _previousTouchLocation, _initialPanDirection);
		if ((_mainIsMoving = [self canPerformMovement:movement]))
			_mainViewController.view.transform = CGAffineTransformTranslate(_mainViewController.view.transform, movement.x, movement.y);
		_previousTouchLocation = location;
	}
}

- (void)handlePanEnded:(UIPanGestureRecognizer *)gestureRecognizer {
	_finalVelocity = [gestureRecognizer velocityInView:self.view];
    if (_state == TRBRevealingViewControllerStateSlidingOut) {
		if ([self shouldCompleteReveal])
			[self completeReveal];
		else
			[self cancelReveal];
    } else if (_state == TRBRevealingViewControllerStateSlidingIn) {
		if ([self shouldCompleteConceal])
			[self concealViewControllerAnimated:YES completion:NULL];
		else
			[self cancelConceal];
	}
}

- (void)handlePanCancelled {
	switch (_state) {
		case TRBRevealingViewControllerStateSlidingIn:
			[self cancelConceal];
			break;
		case TRBRevealingViewControllerStateSlidingOut:
			[self cancelReveal];
			break;
		default:
			break;
	}
}

- (BOOL)shouldCompleteReveal {
	BOOL result = NO;
	switch (_initialPanDirection) {
		case TRBPanDirectionLeft: {
			CGFloat maxX = CGRectGetMaxX(_mainViewController.view.frame);
			CGFloat midX = CGRectGetMidX(self.view.bounds);
			CGFloat projection = maxX + (_finalVelocity.x - (_friction * _finalVelocity.x));
			result = projection < (MAX((midX + _edgeInsets.left), midX / 2.0));
			break;
		} case TRBPanDirectionRight: {
			CGFloat minX = CGRectGetMinX(_mainViewController.view.frame);
			CGFloat midX = CGRectGetMidX(self.view.bounds);
			CGFloat projection = minX + (_finalVelocity.x - (_friction * _finalVelocity.x));
			result = projection > (MIN(midX - _edgeInsets.right, midX + (midX / 2.0)));
			break;
		} case TRBPanDirectionUp: {
			CGFloat maxY = CGRectGetMaxY(_mainViewController.view.frame);
			CGFloat midY = CGRectGetMidY(self.view.bounds);
			CGFloat projection = maxY + (_finalVelocity.y - (_friction * _finalVelocity.y));
			result = projection < (MAX(midY + _edgeInsets.top, midY / 2.0));
			break;
		} case TRBPanDirectionDown: {
			CGFloat minY = CGRectGetMinY(_mainViewController.view.frame);
			CGFloat midY = CGRectGetMidY(self.view.bounds);
			CGFloat projection = minY + (_finalVelocity.y - (_friction * _finalVelocity.y));
			result = projection > (MIN(midY - _edgeInsets.bottom, midY + (midY / 2.0)));
			break;
		}
		default:
			break;
	}
	return result;
}

- (BOOL)shouldCompleteConceal {
	BOOL result = NO;
	if (_mainIsMoving) {
		switch (_initialPanDirection) {
			case TRBPanDirectionLeft: {
				CGFloat minX = CGRectGetMinX(_mainViewController.view.frame);
				CGFloat midX = CGRectGetMidX(self.view.bounds);
				CGFloat projection = minX + (_finalVelocity.x - (_friction * _finalVelocity.x));
				result = projection < (MAX((midX - _edgeInsets.right), midX / 2.0));
				break;
			} case TRBPanDirectionRight: {
				CGFloat maxX = CGRectGetMaxX(_mainViewController.view.frame);
				CGFloat midX = CGRectGetMidX(self.view.bounds);
				CGFloat projection = maxX + (_finalVelocity.x - (_friction * _finalVelocity.x));
				result = projection > (MIN(midX + _edgeInsets.left, midX + (midX / 2.0)));
				break;
			} case TRBPanDirectionUp: {
				CGFloat minY = CGRectGetMinY(_mainViewController.view.frame);
				CGFloat midY = CGRectGetMidY(self.view.bounds);
				CGFloat projection = minY + (_finalVelocity.y - (_friction * _finalVelocity.y));
				result = projection < (MAX(midY - _edgeInsets.bottom, midY / 2.0));
				break;
			} case TRBPanDirectionDown: {
				CGFloat maxY = CGRectGetMaxY(_mainViewController.view.frame);
				CGFloat midY = CGRectGetMidY(self.view.bounds);
				CGFloat projection = maxY + (_finalVelocity.y - (_friction * _finalVelocity.y));
				result = projection > (MIN(midY + _edgeInsets.top, midY + (midY / 2.0)));
				break;
			}
			default:
				break;
		}
	} else {
		CGFloat xDiff = ABS(CGRectGetMinX(_mainViewController.view.frame));
		CGFloat yDiff = ABS(CGRectGetMinY(_mainViewController.view.frame));
		result = (xDiff < 20.0) && (yDiff < 20.0);
	}
	return result;
}

- (BOOL)canPerformMovement:(CGPoint)movement {
	TRBPanDirection direction = _initialPanDirection;
	if (_state == TRBRevealingViewControllerStateSlidingIn)
		direction = TRBReverseDirection(direction);
	CGRect rect1 = _mainViewController.view.frame;
	rect1.origin.x += movement.x;
	rect1.origin.y += movement.y;
	CGRect rect2 = CGRectZero;
	if (TRBIsDirectionHorizontal(direction)) {
		rect2.size.width = _edgeInsets.left;
		rect2.size.height = CGRectGetHeight(self.view.bounds);
		if (direction == TRBPanDirectionRight) {
			rect2.size.width = _edgeInsets.right;
			rect2.origin.x = CGRectGetWidth(self.view.bounds) - rect2.size.width;
		}
	} else {
		rect2.size.width = CGRectGetWidth(self.view.bounds);
		rect2.size.height = _edgeInsets.top;
		if (direction == TRBPanDirectionDown) {
			rect2.size.height = _edgeInsets.bottom;
			rect2.origin.y = CGRectGetHeight(self.view.bounds) - rect2.size.height;
		}
	}
	return CGRectContainsRect(rect1, rect2);
}

- (void)completeReveal {
	CGPoint movement = CGPointZero;
	TRBRevealingViewControllerState endState;
	if (TRBIsDirectionHorizontal(_initialPanDirection)) {
		CGFloat width = CGRectGetWidth(self.view.bounds);
		CGFloat xMovement = 0.0;
		if (_initialPanDirection == TRBPanDirectionLeft) {
			xMovement = -(width - _edgeInsets.left);
			endState = TRBRevealingViewControllerStateRightRevealed;
		} else {
			xMovement = width - _edgeInsets.right;
			endState = TRBRevealingViewControllerStateLeftRevealed;
		}
		movement.x = xMovement;
	} else {
		CGFloat height = CGRectGetHeight(self.view.bounds);
		CGFloat yMovement = 0.0;
		if (_initialPanDirection == TRBPanDirectionUp) {
			yMovement = -(height - _edgeInsets.top);
			endState = TRBRevealingViewControllerStateBottomRevealed;
		} else {
			yMovement = height - _edgeInsets.bottom;
			endState = TRBRevealingViewControllerStateTopRevealed;
		}
		movement.y = yMovement;
	}
	if ([_delegate respondsToSelector:@selector(revealingViewController:willRevealViewController:andTransitionToState:)])
		[_delegate revealingViewController:self willRevealViewController:_revealingViewController andTransitionToState:endState];
	[_revealingViewController beginAppearanceTransition:YES animated:YES];
	[self revealViewController:_revealingViewController withMovement:movement animated:YES completion:^{
		_state = endState;
		_revealingViewController = nil;
	}];
}

- (void)cancelConceal {
	[UIView animateWithDuration:kDefaultAnimationDuration
					 animations:^{
						 _mainViewController.view.transform = _initialTransform;
					 } completion:^(BOOL finished) {
						 _state = _initialState;
					 }];
}

- (void)cancelReveal {
	[UIView animateWithDuration:kDefaultAnimationDuration
					 animations:^{
						 _mainViewController.view.transform = _initialTransform;
					 } completion:^(BOOL finished) {
						 _state = TRBRevealingViewControllerStateConcealed;
						 _mainViewController.view.layer.shadowOpacity = 0.0;
						 _mainViewController.view.layer.shadowOffset = CGSizeMake(0.0, -kShadowSize);
						 _revealingViewController.view.alpha = 0.0;
						 _revealingViewController = nil;
					 }];
}

- (void)updateRevealingViewController {
	UIViewController * controller = nil;
	if (TRBIsDirectionHorizontal(_initialPanDirection)) {
		if (_initialPanDirection == TRBPanDirectionRight)
			controller = _leftViewController;
		else
			controller = _rightViewController;
	} else {
		if (_initialPanDirection == TRBPanDirectionDown)
			controller = _topViewController;
		else
			controller = _bottomViewController;
	}
	if (_revealingViewController != controller) {
		_revealingViewController.view.alpha = 0.0;
		_revealingViewController = controller;
		_revealingViewController.view.alpha = 1.0;
		[self.view insertSubview:controller.view belowSubview:_mainViewController.view];
	}
}

#pragma mark Remove Controller

- (void)removeController:(UIViewController *)controller isDisappearing:(BOOL)isDisappearing {
	[controller willMoveToParentViewController:nil];
	if (isDisappearing)
		[controller beginAppearanceTransition:NO animated:NO];
	[controller.view removeFromSuperview];
	if (isDisappearing)
		[controller endAppearanceTransition];
	[controller removeFromParentViewController];
	objc_setAssociatedObject(controller, &TRBRevealingViewControllerKey, nil, OBJC_ASSOCIATION_ASSIGN);
	controller.view.transform = CGAffineTransformIdentity;
}

@end

__attribute__((always_inline)) static inline CGPoint TRBMovementForPoints(CGPoint currentPoint, CGPoint previousPoint, TRBPanDirection direction) {
	CGPoint result = CGPointMake(currentPoint.x - previousPoint.x, currentPoint.y - previousPoint.y);
	if (TRBIsDirectionHorizontal(direction))
		result.y = 0.0;
	else
		result.x = 0.0;
	return result;
}

__attribute__((always_inline)) static inline TRBPanDirection TRBDirectionFromVelocity(CGPoint velocity) {
	TRBPanDirection result = TRBPanDirectionUnknown;
	if (ABS(velocity.x) >= ABS(velocity.y)) {
		if (velocity.x >= 0.0)
			result = TRBPanDirectionRight;
		else
			result = TRBPanDirectionLeft;
	} else {
		if (velocity.y >= 0.0)
			result = TRBPanDirectionDown;
		else
			result = TRBPanDirectionUp;
	}
	return result;
}

__attribute__((always_inline)) static inline CGRect TRBFrameForLeftViewController(TRBRevealingViewController * revealingViewController) {
	return CGRectMake(0.0, 0.0, CGRectGetWidth(revealingViewController.view.bounds) - revealingViewController->_edgeInsets.right, CGRectGetHeight(revealingViewController.view.bounds));
}

__attribute__((always_inline)) static inline CGRect TRBFrameForRightViewController(TRBRevealingViewController * revealingViewController) {
	return CGRectMake(revealingViewController->_edgeInsets.left, 0.0,
					  CGRectGetWidth(revealingViewController.view.bounds) - revealingViewController->_edgeInsets.left,
					  CGRectGetHeight(revealingViewController.view.bounds));
}

__attribute__((always_inline)) static inline CGRect TRBFrameForTopViewController(TRBRevealingViewController * revealingViewController) {
	return CGRectMake(0.0, 0.0, CGRectGetWidth(revealingViewController.view.bounds), CGRectGetHeight(revealingViewController.view.bounds) - revealingViewController->_edgeInsets.bottom);
}

__attribute__((always_inline)) static inline CGRect TRBFrameForBottomViewController(TRBRevealingViewController * revealingViewController) {
	return CGRectMake(0.0, revealingViewController->_edgeInsets.top,
					  CGRectGetWidth(revealingViewController.view.bounds),
					  CGRectGetHeight(revealingViewController.view.bounds) -  revealingViewController->_edgeInsets.top);
}

@implementation UIViewController (TRBRevealingViewControllerAddition)

- (TRBRevealingViewController *)revealingViewController {
	TRBRevealingViewController * result = objc_getAssociatedObject(self, &TRBRevealingViewControllerKey);
	if (!result && self.parentViewController != self)
		result = self.parentViewController.revealingViewController;
	return result;
}

@end
