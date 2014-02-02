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

#import "TRBReleseFiltersViewController.h"
#import "TRBReleaseFilters.h"
#import "TRBReleasesViewController.h"

static NSString * const TRBSavedReleaseFiltersKey = @"TRBSavedReleaseFilters";
static NSString * const TRBSavedTickedKey = @"TRBSavedTicked";

@interface TRBReleseFiltersViewController ()
@end

@implementation TRBReleseFiltersViewController {
	NSInteger _currentYear;
	NSArray * _ticked;
	id _observer;
}

#pragma mark - Initialization

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
		NSData * tickedData = [[NSUserDefaults standardUserDefaults] dataForKey:TRBSavedTickedKey];
		if ([tickedData length])
			_ticked = [NSKeyedUnarchiver unarchiveObjectWithData:tickedData];
		else
			_ticked = @[[NSMutableSet new], [NSMutableSet new], [NSMutableSet new], [NSMutableSet new], [NSMutableSet new], [NSMutableSet new]];
		NSDictionary * savedFilters = [[NSUserDefaults standardUserDefaults] dictionaryForKey:TRBSavedReleaseFiltersKey];
		if ([savedFilters count])
			_filters = [savedFilters mutableCopy];
		else {
			_filters = [@{
						@"Type": @"0",
						@"Subtype": @"0",
						@"Video Format": @"0",
						@"Source": @"0",
						@"Genre": @"0",
						@"Year": @"0"} mutableCopy];
		}
		_observer = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillResignActiveNotification
																	  object:nil
																	   queue:[NSOperationQueue mainQueue]
																  usingBlock:^(NSNotification * note) {
																	  [[NSUserDefaults standardUserDefaults] setObject:_filters forKey:TRBSavedReleaseFiltersKey];
																	  [[NSUserDefaults standardUserDefaults] setObject:[NSKeyedArchiver archivedDataWithRootObject:_ticked] forKey:TRBSavedTickedKey];
																  }];
    }
    return self;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:_observer];
}

#pragma mark - View Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
	NSDate * now = [NSDate date];
	NSCalendar * calendar = [NSCalendar currentCalendar];
	NSDateComponents * components = [calendar components:NSYearCalendarUnit fromDate:now];
	_currentYear = components.year;
	self.tableView.sectionIndexMinimumDisplayRowCount = 0;
	self.tableView.sectionIndexTrackingBackgroundColor = [UIColor clearColor];
}

#pragma mark - IBActions

- (IBAction)applyButtonPressed:(UIBarButtonItem *)sender {
	[self.revealingViewController concealViewControllerAnimated:YES completion:NULL];
	if (_filtersUpadated)
		_filtersUpadated([_filters copy]);
}

- (IBAction)resetButtonPressed:(UIBarButtonItem *)sender {
	_filters = [@{
				@"Type": @"0",
				@"Subtype": @"0",
				@"Video Format": @"0",
				@"Source": @"0",
				@"Genre": @"0",
				@"Year": @"0"} mutableCopy];
	_ticked = @[[NSMutableSet new], [NSMutableSet new], [NSMutableSet new], [NSMutableSet new], [NSMutableSet new], [NSMutableSet new]];
	[self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return kTRBAllFiltersCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	NSInteger result = 0;
	if (section < kTRBStaticFiltersCount)
		result = TRBStaticFilterCounts[section];
	else
		result = (_currentYear - kTRBReleaseStartingYear) + 1;
    return result;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString * CellIdentifier = @"TRBReleasesFilterCell";
    TRBReleaseFilterCell * cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];

	if (indexPath.section < kTRBStaticFiltersCount)
		cell.textLabel.text = TRBReleaseStaticFilters[indexPath.section][indexPath.row];
	else
		cell.textLabel.text = [@(_currentYear - indexPath.row) description];

	cell.isTicked = [_ticked[indexPath.section] containsObject:@(indexPath.row)];

    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	return TRBReleaseFilterTitles[section];
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {
	return @[
	@"Tpt", @".", @".", @".", @".",
	@"Sbtp", @".", @".", @".", @".",
	@"Fmt", @".", @".", @".", @".",
	@"Src", @".", @".", @".", @".",
	@"Gnr", @".", @".", @".", @".",
	@"Yr"];
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index {
	return index / 5;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	TRBReleaseFilterCell * cell = (TRBReleaseFilterCell *)[tableView cellForRowAtIndexPath:indexPath];
	cell.isTicked = !cell.isTicked;
	NSString * filterKey = TRBReleaseFilterTitles[indexPath.section];
	NSString * filter = _filters[filterKey];
	id selectedFilter = indexPath.section < kTRBStaticFiltersCount ? @(indexPath.row + 1) : cell.textLabel.text;
	if (cell.isTicked) {
		[_ticked[indexPath.section] addObject:@(indexPath.row)];
		if (![filter isEqualToString:@"0"])
			filter = [filter stringByAppendingFormat:@"_%@", selectedFilter];
		else
			filter = [selectedFilter description];
	} else {
		[_ticked[indexPath.section] removeObject:@(indexPath.row)];
		NSString * toRemove = [NSString stringWithFormat:@"_%@", selectedFilter];
		NSRange range = [filter rangeOfString:toRemove];
		if (range.location != NSNotFound)
			filter = [filter stringByReplacingCharactersInRange:range withString:@""];
		else
			filter = @"0";
	}
	_filters[filterKey] = filter;
}

@end

@implementation TRBReleaseFilterCell

#pragma mark - Public Methods

- (void)setIsTicked:(BOOL)isTicked {
	_isTicked = isTicked;
	[self setAccessoryType:_isTicked ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone];
}

#pragma mark - UITableViewCell Overrides

- (void)prepareForReuse {
	[super prepareForReuse];
	self.isTicked = NO;
}

@end
