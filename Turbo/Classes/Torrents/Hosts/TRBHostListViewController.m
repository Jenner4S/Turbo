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

#import "TRBHostListViewController.h"
#import "TRBHost.h"
#import "TRBHostSelectionController.h"
#import "TRBHostDetailViewController.h"

typedef enum _TRBHostSectionIndex {
	TRBHostSectionIndexActive = 0,
	TRBHostSectionIndexInactive,
	
	TRBHostSectionIndexCount
} TRBHostSectionIndex;

@interface TRBHostListViewController ()<TRBHostSelectionControllerDelegate>
@property (nonatomic, weak) TRBHostDetailViewController * detailViewController;
@end

@implementation TRBHostListViewController

@dynamic detailViewController;

#pragma mark - Dynamic Properties

- (TRBHostDetailViewController *)detailViewController {
	TRBHostDetailViewController * result = nil;
	if (self.splitViewController)
		result = self.splitViewController.viewControllers[1];
	return result;
}

#pragma mark - UIView Lifecycle

#pragma mark - UITableViewDelegate & UITableViewDataSource Implementation

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return TRBHostSectionIndexCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	NSInteger result = 0;
	switch (section) {
		case TRBHostSectionIndexActive:
			result = MAX([_hostList activeHostCount], 1);
			break;
		case TRBHostSectionIndexInactive:
			result = [_hostList inactiveHostCount];
			break;
		default:
			break;
	}
    return result;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	NSString * CellIdentifier =  @"HostCell";
	UITableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];

	switch (indexPath.section) {
		case TRBHostSectionIndexActive:
			[self setupActiveHostCell:cell atIndex:indexPath.row];
			break;
		case TRBHostSectionIndexInactive:
			[self setupInactiveHostCell:cell atIndex:indexPath.row];
			break;
		default:
			break;
	}

    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	NSString * result = @"Active";
	if (section == TRBHostSectionIndexInactive)
		result = @"Inactive";
	return result;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	return indexPath.section == TRBHostSectionIndexInactive;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (editingStyle == UITableViewCellEditingStyleDelete) {
		[_hostList removeHostAtIndex:indexPath.row];
		NSIndexSet * indexes = [NSIndexSet indexSetWithIndex:indexPath.section];
		[self.tableView reloadSections:indexes withRowAnimation:UITableViewRowAnimationAutomatic];
	}
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
	switch (indexPath.section) {
		case TRBHostSectionIndexActive:
			[self deactivateHostAtIndexPath:indexPath];
			break;
		case TRBHostSectionIndexInactive:
			[self activateHostAtIndexPath:indexPath];
			break;
		default:
			break;
	}
}

#pragma mark - UIViewController Overrides

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
	if ([segue.identifier isEqualToString:@"TRBHostAdd"]) {
		TRBHostSelectionController * controller = segue.destinationViewController;
		controller.hostSelectionDelegate = self;
	} else if ([segue.identifier isEqualToString:@"TRBShowHostDetails"]) {
		NSIndexPath * indexPath = [self.tableView indexPathForCell:(UITableViewCell *)sender];
		TRBHostDetailViewController * controller = segue.destinationViewController;
		TRBHost * p = [self hostForIndexPath:indexPath];
		[controller showHost:p];
	}
}

- (BOOL)canPerformUnwindSegueAction:(SEL)action fromViewController:(UIViewController *)fromViewController withSender:(id)sender {
	return action == @selector(cancel:);
}

#pragma mark - TRBAddHostViewControllerDelegate Implementation

- (void)hostSelectionController:(TRBHostSelectionController *)controller didSelectHost:(TRBHost *)host {
	[self.navigationController dismissViewControllerAnimated:YES completion:NULL];
	[_hostList addHost:host];
	[self.tableView reloadData];
}

#pragma mark - IBActions

- (IBAction)cancel:(UIStoryboardSegue *)segue {
	if (isIdiomPad)
		[self dismissViewControllerAnimated:YES completion:NULL];
}

#pragma mark - Private Methods

- (void)setupActiveHostCell:(UITableViewCell *)cell atIndex:(NSUInteger)index {
    if (index < [_hostList activeHostCount]) {
		TRBHost * host = [_hostList activeHostAtIndex:index];
		cell.textLabel.text = host.domain;
		cell.detailTextLabel.text = host.name;
		cell.imageView.hidden = NO;
		cell.imageView.image = host.icon;
		cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
	} else {
		cell.textLabel.text = @"No Active Host";
		cell.detailTextLabel.text = @"Select one!";
		cell.imageView.hidden = YES;
		cell.accessoryType = UITableViewCellAccessoryNone;
	}
}

- (void)setupInactiveHostCell:(UITableViewCell *)cell atIndex:(NSInteger)index {
	TRBHost * host = [_hostList inactiveHostAtIndex:index];
    cell.textLabel.text = host.domain;
	cell.detailTextLabel.text = host.name;
	cell.imageView.hidden = NO;
	cell.imageView.image = host.icon;
	cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
}

- (void)activateHostAtIndexPath:(NSIndexPath *)indexPath {
    TRBHost * host = [_hostList inactiveHostAtIndex:indexPath.row];
    [_hostList activateHost:host];
    NSIndexPath * insertedIndexPath = [NSIndexPath indexPathForRow:[_hostList activeHostCount] - 1 inSection:0];
    [self.tableView beginUpdates];
	if ([_hostList activeHostCount] == 1)
		[self.tableView deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:0]] withRowAnimation:UITableViewRowAnimationFade];
	[self.tableView moveRowAtIndexPath:indexPath toIndexPath:insertedIndexPath];
    [self.tableView endUpdates];
}

- (void)deactivateHostAtIndexPath:(NSIndexPath *)indexPath {
	if ([_hostList activeHostCount] < indexPath.row) {
		TRBHost * host = [_hostList activeHostAtIndex:indexPath.row];
		[_hostList deactivateHost:host];
		NSIndexPath * insertedIndexPath = [NSIndexPath indexPathForRow:[_hostList inactiveHostCount] - 1 inSection:1];
		[self.tableView beginUpdates];
		if ([_hostList activeHostCount] == 0)
			[self.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:0]] withRowAnimation:UITableViewRowAnimationFade];
		[self.tableView moveRowAtIndexPath:indexPath toIndexPath:insertedIndexPath];
		[self.tableView endUpdates];
	}
}

- (TRBHost *)hostForIndexPath:(NSIndexPath *)indexPath {
    TRBHost * host= nil;
    switch (indexPath.section) {
        case TRBHostSectionIndexActive:
            host = [_hostList activeHostAtIndex:indexPath.row];
            break;
        case TRBHostSectionIndexInactive:
            host = [_hostList inactiveHostAtIndex:indexPath.row];
            break;
        default:
            break;
    }
    return host;
}

@end
