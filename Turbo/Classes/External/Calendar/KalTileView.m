/*
 * Copyright (c) 2009 Keith Lazuka
 * License: http://www.opensource.org/licenses/mit-license.html
 */

#import "KalTileView.h"
#import "KalDate.h"
#import "KalPrivate.h"

@implementation KalTileView {
	CGSize _tileSize;
}

- (id)initWithFrame:(CGRect)frame {
	if ((self = [super initWithFrame:frame])) {
		self.opaque = NO;
		self.backgroundColor = [UIColor whiteColor];
		self.clipsToBounds = NO;
		_tileSize = frame.size;
		origin = frame.origin;
		[self setIsAccessibilityElement:YES];
		[self setAccessibilityTraits:UIAccessibilityTraitButton];
		[self resetState];
	}
	return self;
}

- (void)setDate:(KalDate *)date {
	if (_date != date) {
		_date = date;
		[self setNeedsDisplay];
	}
}

#define DEGREES_TO_RADIANS(angle) ((angle) / 180.0 * M_PI)

- (void)drawRect:(CGRect)rect {
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	UIFont * font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];

	UIColor * textColor = self.tintColor;
	UIColor * circleColor = self.tintColor;

	if (_date) {
		NSDateComponents * components = [[NSCalendar currentCalendar] components:NSWeekdayCalendarUnit fromDate:[_date NSDate]];
		NSInteger weekday = [components weekday];
		if (weekday == 1 || weekday == 7) {
			textColor = [UIColor redColor];
			circleColor = [UIColor redColor];
		}
	}

	UIImage * markerImage = nil;
	BOOL drawCircle = [self isToday] || self.selected;

	if ([self isToday]) {
		textColor = [UIColor whiteColor];
		markerImage = [UIImage imageNamed:@"Kal.bundle/kal_marker_today"];
	} else if (self.selected) {
		textColor = [UIColor whiteColor];
		circleColor = [UIColor blackColor];
		markerImage = [UIImage imageNamed:@"Kal.bundle/kal_marker_selected"];
	} else if (self.belongsToAdjacentMonth) {
		textColor = [UIColor lightGrayColor];
		markerImage = [UIImage imageNamed:@"Kal.bundle/kal_marker_dim"];
	} else {
		markerImage = [UIImage imageNamed:@"Kal.bundle/kal_marker"];
	}

	if (drawCircle) {
		UIBezierPath * circle = [UIBezierPath bezierPathWithArcCenter:CGPointMake(_tileSize.width / 2.0, _tileSize.height / 2.0)
															   radius:(_tileSize.width / 2.0) - 2.0
														   startAngle:DEGREES_TO_RADIANS(0.0)
															 endAngle:DEGREES_TO_RADIANS(359.0) clockwise:YES];
		[circleColor setFill];
		[circle fill];
	}


	if (flags.marked)
		[markerImage drawInRect:CGRectMake((_tileSize.width / 2.f) - 2.f, _tileSize.height - 10.f, 4.f, 5.f)];

	NSUInteger n = [self.date day];
	NSString * dayText = [NSString stringWithFormat:@"%lu", (unsigned long)n];
	CGSize textSize = [dayText sizeWithAttributes:@{NSFontAttributeName: font}];
	CGPoint textPosition = CGPointMake(roundf(0.5f * (_tileSize.width - textSize.width)), roundf(0.5f * textSize.height));
	[textColor setFill];

	[dayText drawAtPoint:textPosition withAttributes:@{NSFontAttributeName: font, NSForegroundColorAttributeName: textColor}];


	if (self.highlighted) {
		[[UIColor colorWithWhite:0.25f alpha:0.3f] setFill];
		CGContextFillRect(ctx, CGRectMake(0.f, 0.f, _tileSize.width, _tileSize.height));
	}
}

- (void)resetState
{
	// realign to the grid
	CGRect frame = self.frame;
	frame.origin = origin;
	frame.size = _tileSize;
	self.frame = frame;

	_date = nil;
	flags.type = KalTileTypeRegular;
	flags.highlighted = NO;
	flags.selected = NO;
	flags.marked = NO;
}

- (BOOL)isSelected { return flags.selected; }

- (void)setSelected:(BOOL)selected
{
	if (flags.selected == selected)
		return;

	// workaround since I cannot draw outside of the frame in drawRect:
	if (![self isToday]) {
		CGRect rect = self.frame;
		if (selected) {
			rect.origin.x--;
			rect.size.width++;
			rect.size.height++;
		} else {
			rect.origin.x++;
			rect.size.width--;
			rect.size.height--;
		}
		self.frame = rect;
	}

	flags.selected = selected;
	[self setNeedsDisplay];
}

- (BOOL)isHighlighted { return flags.highlighted; }

- (void)setHighlighted:(BOOL)highlighted
{
	if (flags.highlighted == highlighted)
		return;

	flags.highlighted = highlighted;
	[self setNeedsDisplay];
}

- (BOOL)isMarked { return flags.marked; }

- (void)setMarked:(BOOL)marked
{
	if (flags.marked == marked)
		return;

	flags.marked = marked;
	[self setNeedsDisplay];
}

- (KalTileType)type { return flags.type; }

- (void)setType:(KalTileType)tileType
{
	if (flags.type == tileType)
		return;

	// workaround since I cannot draw outside of the frame in drawRect:
	CGRect rect = self.frame;
	if (tileType == KalTileTypeToday) {
		rect.origin.x--;
		rect.size.width++;
		rect.size.height++;
	} else if (flags.type == KalTileTypeToday) {
		rect.origin.x++;
		rect.size.width--;
		rect.size.height--;
	}
	self.frame = rect;

	flags.type = tileType;
	[self setNeedsDisplay];
}

- (BOOL)isToday { return flags.type == KalTileTypeToday; }

- (BOOL)belongsToAdjacentMonth { return flags.type == KalTileTypeAdjacent; }


@end
