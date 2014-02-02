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

#import "TRBHostSelectionController.h"
#import "TRBHost.h"
#import "TRBNetServiceDiscoverer.h"

@interface TRBHostSelectionController ()
- (void)deliverHost:(TRBHost *)host;
@end

@implementation TRBHostSelectionController

#pragma mark - Public Methods

- (void)deliverHost:(TRBHost *)host; {
	[_hostSelectionDelegate hostSelectionController:self didSelectHost:host];
}

@end

@interface TRBAddHostViewController : UIViewController

@property (weak, nonatomic) IBOutlet UIBarButtonItem * saveButton;
@property (weak, nonatomic) IBOutlet UISegmentedControl * protocol;
@property (weak, nonatomic) IBOutlet UITextField * domainTextField;
@property (weak, nonatomic) IBOutlet UITextField * portTextField;
@property (weak, nonatomic) IBOutlet UITextField * pathTextField;

@property (nonatomic, strong) TRBHost * host;

- (IBAction)textChanged:(UITextField *)sender;

@end

@implementation TRBAddHostViewController

#pragma mark - Memory Management


#pragma mark - UIView Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
	_host = [[TRBTransmissionHost alloc] init];
}

#pragma mark - Custom Getters

- (TRBHostSelectionController *)hostSelectionController {
	TRBHostSelectionController * result = nil;
	if ([self.navigationController isKindOfClass:[TRBHostSelectionController class]])
		result = (TRBHostSelectionController *)self.navigationController;
	return result;
}

#pragma mark - IBActions

- (IBAction)textChanged:(UITextField *)sender {
	_saveButton.enabled = [_domainTextField.text length] && [_portTextField.text length] && [_pathTextField.text length];
}

- (IBAction)saveButtonPressed:(id)sender {
	_host.protocol = _protocol.selectedSegmentIndex;
	_host.domain = _domainTextField.text;
	_host.port = [_portTextField.text integerValue];
	_host.path = _pathTextField.text;
	[_domainTextField resignFirstResponder];
	[_portTextField resignFirstResponder];
	[_pathTextField resignFirstResponder];
	[self.hostSelectionController deliverHost:_host];
}

@end

@interface TRBBonjourListViewController : UITableViewController<TRBNetServiceDiscovererDelegate>

@end

@implementation TRBBonjourListViewController {
	TRBNetServiceDiscoverer * _serviceDiscoverer;
	NSArray * _services;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
    }
    return self;
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	_serviceDiscoverer = [TRBNetServiceDiscoverer new];
	[_serviceDiscoverer startServiceSearch];
	_serviceDiscoverer.delegate = self;
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[_serviceDiscoverer stopServiceSearch];
}

#pragma mark - Dynamic Properties

- (TRBHostSelectionController *)hostSelectionController {
	TRBHostSelectionController * result = nil;
	if ([self.navigationController isKindOfClass:[TRBHostSelectionController class]])
		result = (TRBHostSelectionController *)self.navigationController;
	return result;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    return [_services count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString * CellIdentifier = @"BonjourCell";
    UITableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
	NSNetService * service = _services[indexPath.row];
    cell.textLabel.text = service.name;
	cell.detailTextLabel.text = service.domain;
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSNetService * service = _services[indexPath.row];
	TRBHost * host = [[TRBTransmissionHost alloc] init];
	host.name = service.name;
	host.desc = service.domain;
	host.domain = service.hostName;
	host.port = service.port;
	[self.hostSelectionController deliverHost:host];
}

#pragma mark - TRBNetServiceDiscovererDelegate Implementation

- (BOOL)netServiceDiscoverer:(TRBNetServiceDiscoverer *)serviceDiscoverer shouldResolveService:(NSNetService *)service {
	return [service.name hasPrefix:@"Transmission"];
}

- (BOOL)netServiceDiscoverer:(TRBNetServiceDiscoverer *)serviceDiscoverer shouldKeepResolvedService:(NSNetService *)service {
	return YES;
}

- (void)netServiceDiscoverer:(TRBNetServiceDiscoverer *)serviceDiscoverer didUpdateServiceList:(NSArray *)services {
	_services = services;
	[self.tableView reloadData];
}

@end

@interface TRBHostPickerCell : UITableViewCell
@end

@implementation TRBHostPickerCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	return [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier];
}

@end

@implementation TRBHostPickerViewController {
	TRBHostList * _hostList;
}

- (instancetype)initWithHostList:(TRBHostList *)hostList {
	self = [super initWithStyle:UITableViewStylePlain];
	if (self) {
		_hostList = hostList;
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = @"Add torrent to...";
	[self.tableView registerClass:[TRBHostPickerCell class] forCellReuseIdentifier:@"HostCell"];
	self.tableView.rowHeight = 80.0;
	UIBarButtonItem * cancel = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelButtonPressed:)];
	self.navigationItem.rightBarButtonItem = cancel;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	NSInteger result = 0;
	if (section == 0)
		result = [_hostList activeHostCount];
	else
		result = [_hostList inactiveHostCount];
	return result;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:@"HostCell" forIndexPath:indexPath];
	TRBHost * host = indexPath.section == 0 ? [_hostList activeHostAtIndex:indexPath.row] : [_hostList inactiveHostAtIndex:indexPath.row];
	cell.textLabel.text = host.domain;
	cell.detailTextLabel.text = host.name;
	cell.imageView.hidden = NO;
	cell.imageView.image = host.icon;
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	TRBHost * host = indexPath.section == 0 ? [_hostList activeHostAtIndex:indexPath.row] : [_hostList inactiveHostAtIndex:indexPath.row];
	[self dismissViewControllerAnimated:YES completion:^{
		if (_onHostPick) {
			_onHostPick(host);
		}
	}];
}

- (void)cancelButtonPressed:(id)sender {
	[self dismissViewControllerAnimated:YES completion:^{
		if (_onHostPick) {
			_onHostPick(nil);
		}
	}];
}

@end;
