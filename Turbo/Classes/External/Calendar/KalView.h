/*
 * Copyright (c) 2009 Keith Lazuka
 * License: http://www.opensource.org/licenses/mit-license.html
 */

@class KalGridView, KalLogic, KalDate;
@protocol KalViewDelegate, KalDataSourceCallbacks;

/*
 *    KalView
 *    ------------------
 *
 *    Private interface
 *
 *  As a client of the Kal system you should not need to use this class directly
 *  (it is managed by KalViewController).
 *
 *  KalViewController uses KalView as its view.
 *  KalView defines a view hierarchy that looks like the following:
 *
 *       +-----------------------------------------+
 *       |                header view              |
 *       +-----------------------------------------+
 *       |                                         |
 *       |                                         |
 *       |                                         |
 *       |                 grid view               |
 *       |             (the calendar grid)         |
 *       |                                         |
 *       |                                         |
 *       +-----------------------------------------+
 *       |                                         |
 *       |           table view (events)           |
 *       |                                         |
 *       +-----------------------------------------+
 *
 */
@interface KalView : UIView

@property (nonatomic, weak) id<KalViewDelegate> delegate;
@property (nonatomic, weak) KalLogic * logic;
@property (nonatomic, readonly) UITableView *tableView;
@property (weak, nonatomic, readonly) KalDate *selectedDate;

- (id)initWithFrame:(CGRect)frame andLogic:(KalLogic *)theLogic;
- (BOOL)isSliding;
- (void)selectDate:(KalDate *)date;
- (void)markTilesForDates:(NSArray *)dates;
- (void)redrawEntireMonth;

// These 3 methods are exposed for the delegate. They should be called
// *after* the KalLogic has moved to the month specified by the user.
- (void)slideDown;
- (void)slideUp;
- (void)jumpToSelectedMonth;    // change months without animation (i.e. when directly switching to "Today")

@end

#pragma mark -

@class KalDate;

@protocol KalViewDelegate

- (void)showPreviousMonth;
- (void)showFollowingMonth;
- (void)didSelectDate:(KalDate *)date;

@end
