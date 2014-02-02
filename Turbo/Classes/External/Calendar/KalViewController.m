/*
 * Copyright (c) 2009 Keith Lazuka
 * License: http://www.opensource.org/licenses/mit-license.html
 */

#import "KalViewController.h"
#import "KalLogic.h"
#import "KalDataSource.h"
#import "KalDate.h"
#import "KalPrivate.h"

#define PROFILER 0
#if PROFILER
#include <mach/mach_time.h>
#include <time.h>
#include <math.h>
void mach_absolute_difference(uint64_t end, uint64_t start, struct timespec *tp)
{
    uint64_t difference = end - start;
    static mach_timebase_info_data_t info = {0,0};

    if (info.denom == 0)
        mach_timebase_info(&info);

    uint64_t elapsednano = difference * (info.numer / info.denom);
    tp->tv_sec = elapsednano * 1e-9;
    tp->tv_nsec = elapsednano - (tp->tv_sec * 1e9);
}
#endif

NSString *const KalDataSourceChangedNotification = @"KalDataSourceChangedNotification";

@interface KalViewController ()
// The date that the calendar was initialized with *or* the currently selected date when the view hierarchy was torn down in order to satisfy a low memory warning.
@property (nonatomic, strong, readwrite) NSDate *initialDate;
// I cache the selected date because when we respond to a memory warning, we cannot rely on the view hierarchy still being alive,
// and thus we cannot always derive the selected date from KalView's selectedDate property.
@property (nonatomic, strong, readwrite) NSDate *selectedDate;
@end

@implementation KalViewController {
	KalLogic * _logic;
}

@dynamic calendarView;

- (id)initWithSelectedDate:(NSDate *)date {
	self = [super init];
	if (self) {
		_logic = [[KalLogic alloc] initForDate:date];
		_initialDate = date;
		_selectedDate = date;
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(significantTimeChangeOccurred) name:UIApplicationSignificantTimeChangeNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadData) name:KalDataSourceChangedNotification object:nil];
	}
	return self;
}

- (id)init
{
	return [self initWithSelectedDate:[NSDate date]];
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
		NSDate * date = [NSDate date];
		_logic = [[KalLogic alloc] initForDate:date];
		_initialDate = date;
		_selectedDate = date;
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(significantTimeChangeOccurred) name:UIApplicationSignificantTimeChangeNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadData) name:KalDataSourceChangedNotification object:nil];
    }
    return self;
}

- (KalView*)calendarView { return (KalView*)self.view; }

- (void)setDataSource:(id<KalDataSource>)aDataSource
{
	if (_dataSource != aDataSource || self.calendarView.tableView.dataSource != aDataSource) {
		_dataSource = aDataSource;
		self.calendarView.tableView.dataSource = _dataSource;
		[self reloadData];
	}
}

- (void)setDelegate:(id<UITableViewDelegate>)aDelegate
{
	if (self.calendarView.tableView.delegate != aDelegate) {
		self.calendarView.tableView.delegate = aDelegate;
	}
}

- (void)clearTable
{
	[_dataSource removeAllItems];
	[self.calendarView.tableView reloadData];
}

- (void)reloadData
{
	[_dataSource presentingDatesFrom:_logic.fromDate to:_logic.toDate delegate:self];
}

- (void)significantTimeChangeOccurred
{
	[[self calendarView] jumpToSelectedMonth];
	[self reloadData];
}

// -----------------------------------------
#pragma mark KalViewDelegate protocol

- (void)didSelectDate:(KalDate *)date
{
	self.selectedDate = [date NSDate];
	NSDate *from = [[date NSDate] cc_dateByMovingToBeginningOfDay];
	NSDate *to = [[date NSDate] cc_dateByMovingToEndOfDay];
	[self clearTable];
	[_dataSource loadItemsFromDate:from toDate:to];
	[self.calendarView.tableView reloadData];
	[self.calendarView.tableView flashScrollIndicators];
}

- (void)showPreviousMonth
{
	[self clearTable];
	[_logic retreatToPreviousMonth];
	[[self calendarView] slideDown];
	[self reloadData];
}

- (void)showFollowingMonth
{
	[self clearTable];
	[_logic advanceToFollowingMonth];
	[[self calendarView] slideUp];
	[self reloadData];
}

// -----------------------------------------
#pragma mark KalDataSourceCallbacks protocol

- (void)loadedDataSource:(id<KalDataSource>)theDataSource;
{
	NSArray *markedDates = [theDataSource markedDatesFrom:_logic.fromDate to:_logic.toDate];
	NSMutableArray *dates = [markedDates mutableCopy];
	for (int i=0; i<[dates count]; i++)
		[dates replaceObjectAtIndex:i withObject:[KalDate dateFromNSDate:[dates objectAtIndex:i]]];

	[[self calendarView] markTilesForDates:dates];
	[self didSelectDate:self.calendarView.selectedDate];
}

// ---------------------------------------
#pragma mark -

- (void)showAndSelectDate:(NSDate *)date
{
	if ([[self calendarView] isSliding])
		return;

	[_logic moveToMonthForDate:date];

#if PROFILER
	uint64_t start, end;
	struct timespec tp;
	start = mach_absolute_time();
#endif

	[[self calendarView] jumpToSelectedMonth];

#if PROFILER
	end = mach_absolute_time();
	mach_absolute_difference(end, start, &tp);
	printf("[[self calendarView] jumpToSelectedMonth]: %.1f ms\n", tp.tv_nsec / 1e6);
#endif

	[[self calendarView] selectDate:[KalDate dateFromNSDate:date]];
	[self reloadData];
}

- (NSDate *)selectedDate
{
	return [self.calendarView.selectedDate NSDate];
}

// -----------------------------------------------------------------------------------
#pragma mark UIViewController

- (void)didReceiveMemoryWarning
{
	_initialDate = self.selectedDate; // must be done before calling super
	[super didReceiveMemoryWarning];
}

- (void)loadView {
	if ([self.nibName length])
		[super loadView];
	else {
		KalView *kalView = [[KalView alloc] initWithFrame:CGRectZero andLogic:nil];
		self.view = kalView;
	}
}

- (void)viewDidLoad {
	[super viewDidLoad];
	if (!self.title)
		self.title = @"Calendar";
	self.calendarView.delegate = self;
	self.calendarView.logic = _logic;
	[self.calendarView selectDate:[KalDate dateFromNSDate:_initialDate]];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	[self.calendarView.tableView reloadData];
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	[self.calendarView.tableView flashScrollIndicators];
}

#pragma mark -

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationSignificantTimeChangeNotification object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:KalDataSourceChangedNotification object:nil];
}

@end
