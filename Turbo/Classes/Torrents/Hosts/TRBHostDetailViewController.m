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

#import "TRBHostDetailViewController.h"
#import "TRBHost.h"

typedef NS_ENUM(NSUInteger, TRBHostDetailRow) {
	TRBHostDetailRowName = 0,
	TRBHostDetailRowDescription,
	TRBHostDetailRowProtocol,
	TRBHostDetailRowHost,
	TRBHostDetailRowPort,
	TRBHostDetailRowPath,

	TRBHostDetailRowCount
};

@interface TRBHostDetailViewController ()
@property (nonatomic, strong) TRBHost * host;
@end

@implementation TRBHostDetailViewController

- (id)initWithStyle:(UITableViewStyle)style {
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
	self.title = @"Host";
//	self.tableView.backgroundView = nil;
//	self.tableView.backgroundColor = [UIColor viewFlipsideBackgroundColor];
}

- (BOOL)shouldAutorotate {
	return YES;
}

- (NSUInteger)supportedInterfaceOrientations {
	NSUInteger result = UIInterfaceOrientationMaskPortrait;
	if (isIdiomPad)
		result = UIInterfaceOrientationMaskLandscape;
	return result;
}

#pragma mark - Public Methods

- (void)showHost:(TRBHost *)host {
	self.host = host;
	[self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.host ? TRBHostDetailRowCount : 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"HostDetailCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    switch (indexPath.row) {
		case TRBHostDetailRowName:
			cell.textLabel.text = @"Name";
			cell.detailTextLabel.text = self.host.name;
			break;
		case TRBHostDetailRowDescription:
			cell.textLabel.text = @"Description";
			cell.detailTextLabel.text = self.host.desc;
			break;
		case TRBHostDetailRowProtocol:
			cell.textLabel.text = @"Protocol";
			cell.detailTextLabel.text = self.host.protocol == HTTPProtocolHTTP ? @"HTTP" : @"HTTPS";
			break;
		case TRBHostDetailRowHost:
			cell.textLabel.text = @"Domain";
			cell.detailTextLabel.text = self.host.domain;
			break;
		case TRBHostDetailRowPort:
			cell.textLabel.text = @"Port";
			cell.detailTextLabel.text = [NSString stringWithFormat:@"%li", (long)self.host.port];
			break;
		case TRBHostDetailRowPath:
			cell.textLabel.text = @"Path";
			cell.detailTextLabel.text = self.host.path;
			break;
		default:
			break;
	}
    
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
