/*
 * Copyright (c) 2009 Keith Lazuka
 * License: http://www.opensource.org/licenses/mit-license.html
 */

@import CoreGraphics;
#import "KalMonthView.h"
#import "KalTileView.h"
#import "KalView.h"
#import "KalDate.h"
#import "KalPrivate.h"

@implementation KalMonthView {
	CGSize _tileSize;
}

@synthesize numWeeks;

- (id)initWithFrame:(CGRect)frame
{
	if ((self = [super initWithFrame:frame])) {
		tileAccessibilityFormatter = [[NSDateFormatter alloc] init];
		[tileAccessibilityFormatter setDateFormat:@"EEEE, MMMM d"];
		self.opaque = NO;
		self.clipsToBounds = YES;
		CGFloat sideLength = CGRectGetWidth(frame) / 7.f;
		CGFloat dot = sideLength - (NSInteger)sideLength;
		if (dot >= .5f)
			sideLength = ceilf(sideLength);
		else
			sideLength = floorf(sideLength);
		_tileSize = CGSizeMake(sideLength, sideLength);
		for (int i=0; i<6; i++) {
			for (int j=0; j<7; j++) {
				CGRect r = CGRectMake(j*_tileSize.width, i*_tileSize.height, _tileSize.width, _tileSize.height);
				[self addSubview:[[KalTileView alloc] initWithFrame:r]];
			}
		}
	}
	return self;
}

- (void)showDates:(NSArray *)mainDates leadingAdjacentDates:(NSArray *)leadingAdjacentDates trailingAdjacentDates:(NSArray *)trailingAdjacentDates
{
	int tileNum = 0;
	NSArray *dates[] = { leadingAdjacentDates, mainDates, trailingAdjacentDates };

	for (int i=0; i<3; i++) {
		for (KalDate *d in dates[i]) {
			KalTileView *tile = [self.subviews objectAtIndex:tileNum];
			[tile resetState];
			tile.date = d;
			tile.type = dates[i] != mainDates
			? KalTileTypeAdjacent
			: [d isToday] ? KalTileTypeToday : KalTileTypeRegular;
			tileNum++;
		}
	}

	numWeeks = ceilf(tileNum / 7.f);
	[self sizeToFit];
	[self setNeedsDisplay];
}

- (KalTileView *)firstTileOfMonth
{
	KalTileView *tile = nil;
	for (KalTileView *t in self.subviews) {
		if (!t.belongsToAdjacentMonth) {
			tile = t;
			break;
		}
	}

	return tile;
}

- (KalTileView *)tileForDate:(KalDate *)date
{
	KalTileView *tile = nil;
	for (KalTileView *t in self.subviews) {
		if ([t.date isEqual:date]) {
			tile = t;
			break;
		}
	}
	NSAssert1(tile != nil, @"Failed to find corresponding tile for date %@", date);

	return tile;
}

- (void)sizeToFit
{
	self.height = 1.f + _tileSize.height * numWeeks;
}

- (void)markTilesForDates:(NSArray *)dates
{
	for (KalTileView *tile in self.subviews)
	{
		tile.marked = [dates containsObject:tile.date];
		NSString *dayString = [tileAccessibilityFormatter stringFromDate:[tile.date NSDate]];
		if (dayString) {
			NSMutableString *helperText = [[NSMutableString alloc] initWithCapacity:128];
			if ([tile.date isToday])
				[helperText appendFormat:@"%@ ", NSLocalizedString(@"Today", @"Accessibility text for a day tile that represents today")];
			[helperText appendString:dayString];
			if (tile.marked)
				[helperText appendFormat:@". %@", NSLocalizedString(@"Marked", @"Accessibility text for a day tile which is marked with a small dot")];
			[tile setAccessibilityLabel:helperText];
		}
	}
}

#pragma mark -


@end
