/*
 * Copyright (c) 2009 Keith Lazuka
 * License: http://www.opensource.org/licenses/mit-license.html
 */

#import "KalView.h"
#import "KalGridView.h"
#import "KalLogic.h"
#import "KalPrivate.h"

@interface KalView ()
- (void)addSubviewsToHeaderView:(UIView *)headerView;
- (void)addSubviewsToContentView:(UIView *)contentView;
- (void)setHeaderTitleText:(NSString *)text;
@end

static const CGFloat kHeaderHeight = 44.f;
static const CGFloat kMonthLabelHeight = 17.f;

@implementation KalView {
	__weak UIView * _headerView;
	__weak UIView * _contentView;
	UILabel *headerTitleLabel;
	KalGridView *gridView;
	UITableView *tableView;
	UIImageView *shadowView;
}

@synthesize tableView;

- (id)initWithFrame:(CGRect)frame andLogic:(KalLogic *)theLogic {
	self = [super initWithFrame:frame];
	if (self) {
		_logic = theLogic;
		[_logic addObserver:self forKeyPath:@"selectedMonthNameAndYear" options:NSKeyValueObservingOptionNew context:NULL];
		self.autoresizingMask = UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleBottomMargin|UIViewAutoresizingFlexibleTopMargin;
	}

	return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
		self.autoresizingMask = UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleBottomMargin|UIViewAutoresizingFlexibleTopMargin;
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame {
	[NSException raise:@"Incomplete initializer" format:@"KalView must be initialized with a delegate and a KalLogic. Use the initWithFrame:delegate:logic: method."];
	return nil;
}

- (void)setDelegate:(id<KalViewDelegate>)delegate {
	_delegate = delegate;
	if (_logic)
		[self buildView];
}

- (void)setLogic:(KalLogic *)logic {
	if (_logic)
		[_logic removeObserver:self forKeyPath:@"selectedMonthNameAndYear"];
	_logic = logic;
	[_logic addObserver:self forKeyPath:@"selectedMonthNameAndYear" options:NSKeyValueObservingOptionNew context:NULL];
	if (_delegate)
		[self buildView];
}

- (void)layoutSubviews {
	[_headerView removeFromSuperview];
	[_contentView removeFromSuperview];
	[self buildView];
	[super layoutSubviews];
}

- (void)buildView {
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0.f, 0.f, self.frame.size.width, kHeaderHeight)];
	[headerView setTranslatesAutoresizingMaskIntoConstraints:NO];
	[self addSubviewsToHeaderView:headerView];
	[self addSubview:headerView];
	_headerView = headerView;
	UIView *contentView = [[UIView alloc] initWithFrame:CGRectMake(0.f, kHeaderHeight, self.frame.size.width, self.frame.size.height - kHeaderHeight)];
	[contentView setTranslatesAutoresizingMaskIntoConstraints:NO];
//	contentView.autoresizingMask = UIViewAutoresizingFlexibleHeight;
	[self addSubviewsToContentView:contentView];
	[self addSubview:contentView];
	_contentView = contentView;
	UIViewController * controller = (UIViewController *)self.nextResponder;
	NSMutableArray * constraints = [NSMutableArray array];
	[constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"|-0-[headerView]-0-|"
																			 options:kNilOptions
																			 metrics:nil
																			   views:@{@"headerView": _headerView}]];
	[constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"|-0-[contentView]-0-|"
																			 options:kNilOptions
																			 metrics:nil
																			   views:@{@"contentView": _contentView}]];
	[constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[topGuide]-0-[headerView(headerHight)]-0-[contentView]-0-|"
																			 options:kNilOptions
																			 metrics:@{@"headerHight": @(kHeaderHeight)}
																			   views:@{@"topGuide": controller.topLayoutGuide,
																					   @"headerView": _headerView,
																					   @"contentView": _contentView}]];
	[self addConstraints:constraints];
}

- (void)redrawEntireMonth { [self jumpToSelectedMonth]; }

- (void)slideDown { [gridView slideDown]; }
- (void)slideUp { [gridView slideUp]; }

- (void)showPreviousMonth
{
	if (!gridView.transitioning)
		[_delegate showPreviousMonth];
}

- (void)showFollowingMonth
{
	if (!gridView.transitioning)
		[_delegate showFollowingMonth];
}

- (void)addSubviewsToHeaderView:(UIView *)headerView
{
	const CGFloat kChangeMonthButtonWidth = 46.0f;
	const CGFloat kChangeMonthButtonHeight = 30.0f;
	const CGFloat kMonthLabelWidth = 200.0f;
	const CGFloat kHeaderVerticalAdjust = 5.f;


	// Create the previous month button on the left side of the view
	CGRect previousMonthButtonFrame = CGRectMake(0.0, 0.0,
												 kChangeMonthButtonWidth,
												 kChangeMonthButtonHeight);
	UIButton * previousMonthButton = [[UIButton alloc] initWithFrame:previousMonthButtonFrame];
	[previousMonthButton setAccessibilityLabel:NSLocalizedString(@"Previous month", nil)];
	[previousMonthButton setTitle:@"<" forState:UIControlStateNormal];
	[previousMonthButton setTitleColor:self.tintColor forState:(UIControlStateNormal)];
	[previousMonthButton addTarget:self action:@selector(showPreviousMonth) forControlEvents:UIControlEventTouchUpInside];
	[headerView addSubview:previousMonthButton];

	// Draw the selected month name centered and at the top of the view
	CGRect monthLabelFrame = CGRectMake((self.width/2.0f) - (kMonthLabelWidth/2.0f),
										kHeaderVerticalAdjust,
										kMonthLabelWidth,
										kMonthLabelHeight);
	headerTitleLabel = [[UILabel alloc] initWithFrame:monthLabelFrame];
	headerTitleLabel.backgroundColor = [UIColor clearColor];
	headerTitleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
	headerTitleLabel.textAlignment = NSTextAlignmentCenter;
	headerTitleLabel.textColor = self.tintColor;
	[self setHeaderTitleText:[_logic selectedMonthNameAndYear]];
	[headerView addSubview:headerTitleLabel];

	// Create the next month button on the right side of the view
	CGRect nextMonthButtonFrame = CGRectMake(self.width - kChangeMonthButtonWidth, 0.0,
											 kChangeMonthButtonWidth,
											 kChangeMonthButtonHeight);
	UIButton *nextMonthButton = [[UIButton alloc] initWithFrame:nextMonthButtonFrame];
	[nextMonthButton setAccessibilityLabel:NSLocalizedString(@"Next month", nil)];
	[nextMonthButton setTitle:@">" forState:UIControlStateNormal];
	[nextMonthButton setTitleColor:self.tintColor forState:(UIControlStateNormal)];
	[nextMonthButton addTarget:self action:@selector(showFollowingMonth) forControlEvents:UIControlEventTouchUpInside];
	[headerView addSubview:nextMonthButton];

	// Add column labels for each weekday (adjusting based on the current locale's first weekday)
	NSArray * weekdayNames = [[[NSDateFormatter alloc] init] shortWeekdaySymbols];
	NSArray * fullWeekdayNames = [[[NSDateFormatter alloc] init] standaloneWeekdaySymbols];
	NSUInteger firstWeekday = [[NSCalendar currentCalendar] firstWeekday];
	NSUInteger i = firstWeekday - 1;

	CGFloat tileWidth = CGRectGetWidth(self.frame) / 7.f;
	CGFloat dot = tileWidth - (NSInteger)tileWidth;
	if (dot >= .5f)
		tileWidth = ceilf(tileWidth);
	else
		tileWidth = floorf(tileWidth);

	for (CGFloat xOffset = 0.f; xOffset < headerView.width; xOffset += tileWidth, i = (i+1)%7) {
		CGRect weekdayFrame = CGRectMake(xOffset, 26.f, tileWidth, kHeaderHeight - 25.f);
		UILabel * weekdayLabel = [[UILabel alloc] initWithFrame:weekdayFrame];
		weekdayLabel.backgroundColor = [UIColor clearColor];
		weekdayLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
		weekdayLabel.textAlignment = NSTextAlignmentCenter;
		weekdayLabel.textColor = i == 0 || i == 6 ? [UIColor redColor] : self.tintColor;
		weekdayLabel.text = [weekdayNames objectAtIndex:i];
		[weekdayLabel setAccessibilityLabel:[fullWeekdayNames objectAtIndex:i]];
		[headerView addSubview:weekdayLabel];
	}
}

- (void)addSubviewsToContentView:(UIView *)contentView
{
	// Both the tile grid and the list of events will automatically lay themselves
	// out to fit the # of weeks in the currently displayed month.
	// So the only part of the frame that we need to specify is the width.
	CGRect fullWidthAutomaticLayoutFrame = CGRectMake(0.f, 0.f, self.width, 0.f);

	// The tile grid (the calendar body)
	if (gridView)
		[gridView removeObserver:self forKeyPath:@"frame"];
	gridView = [[KalGridView alloc] initWithFrame:fullWidthAutomaticLayoutFrame logic:_logic delegate:_delegate];
	[gridView addObserver:self forKeyPath:@"frame" options:NSKeyValueObservingOptionNew context:NULL];
	[contentView addSubview:gridView];

	// The list of events for the selected day
	tableView = [[UITableView alloc] initWithFrame:fullWidthAutomaticLayoutFrame style:UITableViewStylePlain];
	tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[contentView addSubview:tableView];
	// Drop shadow below tile grid and over the list of events for the selected day
	shadowView = [[UIImageView alloc] initWithFrame:fullWidthAutomaticLayoutFrame];
	shadowView.image = [UIImage imageNamed:@"Kal.bundle/kal_grid_shadow"];
	shadowView.height = shadowView.image.size.height;
	[contentView addSubview:shadowView];

	// Trigger the initial KVO update to finish the contentView layout
	[gridView sizeToFit];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if (object == gridView && [keyPath isEqualToString:@"frame"]) {

		/* Animate tableView filling the remaining space after the
		 * gridView expanded or contracted to fit the # of weeks
		 * for the month that is being displayed.
		 *
		 * This observer method will be called when gridView's height
		 * changes, which we know to occur inside a Core Animation
		 * transaction. Hence, when I set the "frame" property on
		 * tableView here, I do not need to wrap it in a
		 * [UIView beginAnimations:context:].
		 */
		CGFloat gridBottom = gridView.top + gridView.height;
		CGRect frame = tableView.frame;
		frame.origin.y = gridBottom;
		frame.size.height = tableView.superview.height - gridBottom;
		tableView.frame = frame;
		shadowView.top = gridBottom;

	} else if ([keyPath isEqualToString:@"selectedMonthNameAndYear"]) {
		[self setHeaderTitleText:[change objectForKey:NSKeyValueChangeNewKey]];

	} else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

- (void)setHeaderTitleText:(NSString *)text
{
	[headerTitleLabel setText:text];
	[headerTitleLabel sizeToFit];
	headerTitleLabel.left = floorf(self.width/2.f - headerTitleLabel.width/2.f);
}

- (void)jumpToSelectedMonth { [gridView jumpToSelectedMonth]; }

- (void)selectDate:(KalDate *)date { [gridView selectDate:date]; }

- (BOOL)isSliding { return gridView.transitioning; }

- (void)markTilesForDates:(NSArray *)dates { [gridView markTilesForDates:dates]; }

- (KalDate *)selectedDate { return gridView.selectedDate; }

- (void)dealloc
{
	[_logic removeObserver:self forKeyPath:@"selectedMonthNameAndYear"];

	[gridView removeObserver:self forKeyPath:@"frame"];
}

@end
