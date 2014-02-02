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

#import "TRBServiceSelectionViewController.h"
#import "TRBLibraryManager.h"
#import "TRBNetServiceDiscoverer.h"

@interface TRBServiceSelectionViewController ()<TRBNetServiceDiscovererDelegate>

@end

@implementation TRBServiceSelectionViewController {
	TRBNetServiceDiscoverer * _serviceDiscoverer;
	NSArray * _services;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        _serviceDiscoverer = [TRBNetServiceDiscoverer new];
		_serviceDiscoverer.delegate = self;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	[_serviceDiscoverer startServiceSearch];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[_serviceDiscoverer stopServiceSearch];
}

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [_services count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString * CellIdentifier = @"TRBServiceCell";
    UITableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    NSNetService * service = _services[indexPath.row];
    cell.textLabel.text = service.name;
	cell.detailTextLabel.text = service.domain;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	NSNetService * service = _services[indexPath.row];
	[TRBLibraryManager sharedManager].host = service.hostName;
	[TRBLibraryManager sharedManager].port = service.port;
//	[TRBLibraryManager sharedManager].netService = _services[indexPath.row];
	[self dismissViewControllerAnimated:YES completion:NULL];
}

#pragma mark - TRBNetServiceDiscovererDelegate Implementation

- (BOOL)netServiceDiscoverer:(TRBNetServiceDiscoverer *)serviceDiscoverer shouldResolveService:(NSNetService *)service {
	return YES;
}

- (BOOL)netServiceDiscoverer:(TRBNetServiceDiscoverer *)serviceDiscoverer shouldKeepResolvedService:(NSNetService *)service {
	BOOL result = NO;
	NSDictionary * txt = [NSNetService dictionaryFromTXTRecordData:[service TXTRecordData]];
	NSData * vendorData = txt[@"vendor"];
	if ([vendorData length]) {
		NSString * vendor = [[NSString alloc] initWithData:vendorData encoding:NSUTF8StringEncoding];
		result = [vendor isEqualToString:@"Synology"];
	}
	return result;
}

- (void)netServiceDiscoverer:(TRBNetServiceDiscoverer *)serviceDiscoverer didUpdateServiceList:(NSArray *)services {
	_services = services;
	[self.tableView reloadData];
}

@end
