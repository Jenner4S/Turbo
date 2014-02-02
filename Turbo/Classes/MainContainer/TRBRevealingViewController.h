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

typedef NS_ENUM(NSUInteger, TRBRevealingViewControllerState) {
	TRBRevealingViewControllerStateInitial = 0,
	TRBRevealingViewControllerStateSlidingIn,
	TRBRevealingViewControllerStateConcealed,
	TRBRevealingViewControllerStateSlidingOut,
	TRBRevealingViewControllerStateLeftRevealed,
	TRBRevealingViewControllerStateRightRevealed,
	TRBRevealingViewControllerStateTopRevealed,
	TRBRevealingViewControllerStateBottomRevealed,
};

@protocol TRBRevealingViewControllerDelegate;

@interface TRBRevealingViewController : UIViewController

@property (nonatomic, readonly, assign) TRBRevealingViewControllerState state;
@property (nonatomic, weak) id<TRBRevealingViewControllerDelegate> delegate;

@property (nonatomic, assign, readonly) UIEdgeInsets edgeInsets;
@property (nonatomic, assign) CGFloat friction;

@property (nonatomic, strong) UIViewController * mainViewController;
@property (nonatomic, strong) UIViewController * leftViewController;
@property (nonatomic, strong) UIViewController * rightViewController;
@property (nonatomic, strong) UIViewController * topViewController;
@property (nonatomic, strong) UIViewController * bottomViewController;

@property (nonatomic, strong) NSString * storyboardIDForMainViewController;
@property (nonatomic, strong) NSString * storyboardIDForLeftViewController;
@property (nonatomic, strong) NSString * storyboardIDForRightViewController;
@property (nonatomic, strong) NSString * storyboardIDForTopViewController;
@property (nonatomic, strong) NSString * storyboardIDForBottomViewController;

- (id)initWithControllers:(NSArray *)controllers;
- (void)concealViewControllerAnimated:(BOOL)animated completion:(void (^)(void))completion;
- (void)revealLeftViewControllerAnimated:(BOOL)animated completion:(void (^)(void))completion;
- (void)revealRightViewControllerAnimated:(BOOL)animated completion:(void (^)(void))completion;
- (void)revealTopViewControllerAnimated:(BOOL)animated completion:(void (^)(void))completion;
- (void)revealBottomViewControllerAnimated:(BOOL)animated completion:(void (^)(void))completion;
- (void)setLeftInset:(CGFloat)leftInset animated:(BOOL)animated;
- (void)setRightInset:(CGFloat)rightInset animated:(BOOL)animated;
- (void)setTopInset:(CGFloat)topInset animated:(BOOL)animated;
- (void)setBottomInset:(CGFloat)bottomInset animated:(BOOL)animated;

@end

@protocol TRBRevealingViewControllerDelegate <NSObject>

@optional

- (void)revealingViewController:(TRBRevealingViewController *)revealingViewController
	   willRevealViewController:(UIViewController *)controller
		   andTransitionToState:(TRBRevealingViewControllerState)state;
- (void)revealingViewController:(TRBRevealingViewController *)revealingViewController didRevealViewController:(UIViewController *)controller;
- (void)revealingViewController:(TRBRevealingViewController *)revealingViewController willConcealViewController:(UIViewController *)controller;
- (void)revealingViewController:(TRBRevealingViewController *)revealingViewController didConcealViewController:(UIViewController *)controller;
- (void)revealingViewController:(TRBRevealingViewController *)revealingViewController willAdjustToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation;
- (void)revealingViewController:(TRBRevealingViewController *)revealingViewController didAdjustFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation;

@end

@interface UIViewController (TRBRevealingViewControllerAddition)
@property (nonatomic, readonly, assign) TRBRevealingViewController * revealingViewController;
@end
