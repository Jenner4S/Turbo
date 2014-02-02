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

#import "TRBLibraryFilterViewController.h"

@implementation TRBLibraryFilterViewController {
	@protected
	TRBLibraryFilterName _selectedFilter;
	NSString * _filterDescription;
}

@dynamic filter;

@end

@interface TRBLibraryFilterSelectionViewController ()

@end

@implementation TRBLibraryFilterSelectionViewController

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.row == _selectedFilter)
		cell.accessoryType = UITableViewCellAccessoryCheckmark;
	else
		cell.accessoryType = indexPath.row < 2 ? UITableViewCellAccessoryNone : UITableViewCellAccessoryDisclosureIndicator;
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	_selectedFilter = (TRBLibraryFilterName)indexPath.row;
	switch (_selectedFilter) {
		case TRBLibraryFilterRecentlyAdded:
			_filterDescription = @"Recently Added";
			break;
		default:
			_filterDescription = nil;
			break;
	}
	return indexPath;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[self performSegueWithIdentifier:@"TRBShowSpecificFilter" sender:self];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
	if ([segue.identifier isEqualToString:@"TRBShowSpecificFilter"]) {
		TRBLibraryFilterViewController * filterViewController = segue.destinationViewController;
		filterViewController.selectedFilter = _selectedFilter;
	}
}

- (NSDictionary *)filter {
	NSDictionary * result = nil;
	if (_selectedFilter == TRBLibraryFilterRecentlyAdded)
		result = @{@"recently_added": @"-1"};
	return result;
}

@end

static NSDictionary * TRBFilterMap = nil;

@implementation TRBLibrarySpecificSelectionViewController {
	NSArray * _filterList;
	NSDictionary * _filter;
}

+ (void)initialize {
	TRBFilterMap = @{@(TRBLibraryFilterByYear): @"year",
					@(TRBLibraryFilterByGenre): @"genre",
					@(TRBLibraryFilterByActor): @"actor",
					@(TRBLibraryFilterByDirector): @"director",
					@(TRBLibraryFilterByWriter): @"writer"};
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	NSString * category = TRBFilterMap[@(_selectedFilter)];
	if (category) {
		[[TRBLibraryManager sharedManager] fetchMetadataForType:@"movie" category:category completion:^(NSDictionary *json, NSError *error) {
			if (!error) {
				_filterList = [json[@"data"][@"metadatas"] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary * filter, NSDictionary * bindings) {
					return [filter count] > 0;
				}]];
			}
			[self.tableView reloadData];
		}];
	}
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [_filterList count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString * const CellIdentifier = @"TRBFilterCell";
	UITableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
	cell.textLabel.text = _filterList[indexPath.row][@"name"];
	return cell;
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	NSDictionary * filter = _filterList[indexPath.row];
	NSString * category = TRBFilterMap[@(_selectedFilter)];
	if (category) {
		_filter = @{category: filter[@"id"]};
		_filterDescription = [NSString stringWithFormat:@"%@: %@", [category capitalizedString], filter[@"name"]];
	} else {
		_filter = nil;
		_filterDescription = nil;
	}
	return indexPath;
}

- (NSDictionary *)filter {
	return _filter;
}

@end
