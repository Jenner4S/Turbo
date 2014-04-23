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

#import "TRBTorrentListViewController.h"
#import "TRBHostListViewController.h"
#import "TRBTorrentClient.h"
#import "TRBTorrent.h"
#import "TRBHost.h"
#import "TRBTabBarController.h"
#import "TRBProgressView.h"
#import "TKAlertCenter.h"
#import "Reachability.h"
#import "NSString+TRBUnits.h"

@interface TRBTorrentListViewController ()<TRBHostListDelegate>

@end

@implementation TRBTorrentListViewController {
	TRBHostList * _hostList;
	NSMutableArray * _sections;
	NSTimer * _refreshTimer;
	Reachability * _wifiReach;
	NetworkStatus _netStatus;
	NSTimeInterval _wifiRefreshRate;
	NSTimeInterval _cellularRefreshRate;
	id _observer;
	UINavigationController * _hostListNavigationController;
	NSIndexPath * _toDelete;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:_observer];
}

#pragma mark - UIView Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
	_hostList = [TRBHostList new];
	_hostList.delegate = self;
	_sections = [NSMutableArray arrayWithCapacity:[_hostList activeHostCount]];
	_wifiReach = [Reachability reachabilityForLocalWiFi];
	_netStatus = [_wifiReach currentReachabilityStatus];
	_wifiRefreshRate = (NSTimeInterval)[[NSUserDefaults standardUserDefaults] doubleForKey:TRBWiFiRefreshRateKey];
	if (!_wifiRefreshRate)
		_wifiRefreshRate = 1.0;
	_cellularRefreshRate = (NSTimeInterval)[[NSUserDefaults standardUserDefaults] doubleForKey:TRBCellularRefreshRateKey];
	if (!_cellularRefreshRate)
		_cellularRefreshRate = 10.0;
	_observer = [[NSNotificationCenter defaultCenter] addObserverForName:TRBSettingsUpdatedNotification
																  object:nil
																   queue:[NSOperationQueue mainQueue]
															  usingBlock:^(NSNotification * note) {
																  NSNumber * wifi = [note userInfo][TRBWiFiRefreshRateKey];
																  if (wifi)
																	  _wifiRefreshRate = [wifi doubleValue];
																  NSNumber * cellular = [note userInfo][TRBCellularRefreshRateKey];
																  if (cellular)
																	  _cellularRefreshRate = [cellular doubleValue];
															  }];
	if (self.revealingViewController)
		_hostListNavigationController = [self.storyboard instantiateViewControllerWithIdentifier:@"TRBHostListNavController"];
	else if (self.splitViewController)
		_hostListNavigationController = [self.splitViewController viewControllers][0];
	((TRBHostListViewController *)[_hostListNavigationController.viewControllers firstObject]).hostList = _hostList;
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	self.revealingViewController.rightViewController = _hostListNavigationController;
	[self updateSections];
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	if (!self.revealingViewController || self.revealingViewController.state == TRBRevealingViewControllerStateConcealed) {
		[self start];
	}
	self.revealingViewController.delegate = self;
}

- (void)dismiss:(id)sender {
	[self dismissViewControllerAnimated:YES completion:NULL];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	self.revealingViewController.delegate = nil;
	if (!self.revealingViewController || self.revealingViewController.state < TRBRevealingViewControllerStateLeftRevealed) {
		[self stop];
	}
}

#pragma mark - TRBHostListDelegate Implementation

- (void)hostListDidChangeActiveHosts:(TRBHostList *)hostList {
	[self updateSections];
	if ([_hostList activeHostCount] && self.tabBarController.selectedViewController == self.splitViewController)
		[self fetchTorrentList];
}

#pragma mark - TRBCoverViewControllerDelegate Implementation

- (void)revealingViewController:(TRBRevealingViewController *)revealingViewController
	   willRevealViewController:(UIViewController *)controller
		   andTransitionToState:(TRBRevealingViewControllerState)state {
	[self stop];
}

- (void)revealingViewController:(TRBRevealingViewController *)revealingViewController didConcealViewController:(UIViewController *)controller {
	[self start];
}

#pragma mark - UITableViewDelegate & UITableViewDataSource Implementation

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return [_sections count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	NSInteger result = 0;
	id list = _sections[section];
	if (list != [NSNull null])
		result = [((NSArray *)list) count];
	return result;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString * const CellIdentifier = @"TorrentCell";
	TRBTorrentListCell * cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
	TRBTorrent * torrent = _sections[indexPath.section][indexPath.row];
	[cell setupWithTorrent:torrent];
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (editingStyle == UITableViewCellEditingStyleDelete) {
		TRBTorrent * torrent = _sections[indexPath.section][indexPath.row];
		NSString * message = [NSString stringWithFormat:@"Delete %@", torrent.name];
		UIAlertView * alert = [[UIAlertView alloc] initWithTitle:@"Delete"
														 message:message
														delegate:self
											   cancelButtonTitle:@"Cancel"
											   otherButtonTitles:@"Delete from list", nil];
		_toDelete = indexPath;
		[alert show];
	}
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	return [_hostList activeHostAtIndex:section].domain;
}

#pragma mark - IBActions

- (IBAction)showHosts:(id)sender {
	[self.tmTabBarController toggleRightController];
}

- (IBAction)settingsButtonPressed:(UIBarButtonItem *)sender {
	[self.tmTabBarController showSettingsFromBarButtonItem:sender];
}

#pragma mark - Segues

- (IBAction)returnToTorrentList:(UIStoryboardSegue *)segue {
	if (isIdiomPad)
		[self dismissViewControllerAnimated:YES completion:NULL];
}

- (BOOL)canPerformUnwindSegueAction:(SEL)action fromViewController:(UIViewController *)fromViewController withSender:(id)sender {
	return action == @selector(returnToTorrentList:);
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	if (buttonIndex && _toDelete) {
		TRBTorrent * torrent = _sections[_toDelete.section][_toDelete.row];
		[[_hostList activeHostAtIndex:_toDelete.section].client removeTorrent:torrent
																   completion:^(BOOL success, NSError * error) {
																	   if (success) {
																		   [[TKAlertCenter defaultCenter] postAlertWithMessage:@"Torrent removed"];
																	   }
																   }];
	}
	_toDelete = nil;
}

#pragma mark - Private Methods

- (void)updateSections {
	NSUInteger count = [_hostList activeHostCount];
	if ([_sections count] < count) {
		NSUInteger start = [_sections count];
		for (NSUInteger i = start; i < count; ++i)
			[_sections addObject:[NSNull null]];
		[self.tableView insertSections:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(start, count - start)] withRowAnimation:UITableViewRowAnimationNone];
	} else if ([_sections count] > count) {
		NSUInteger end = [_sections count];
		for (NSUInteger i = count; i < end; ++i)
			[_sections removeLastObject];
		[self.tableView deleteSections:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(count, end - count)] withRowAnimation:UITableViewRowAnimationNone];
	}
}

- (void)start {
    [[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(reachabilityChanged:)
												 name:kReachabilityChangedNotification
											   object:_wifiReach];
	[_wifiReach startNotifier];
	[self fetchTorrentList];
}

- (void)stop {
	[_refreshTimer invalidate];
	[_wifiReach stopNotifier];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[[_hostList activeHosts] enumerateObjectsUsingBlock:^(TRBHost * host, NSUInteger idx, BOOL *stop) {
		host.error = nil;
		[host.client reset];
	}];
}

- (void)refreshTimerFired:(NSTimer *)timer {
	if ((!self.revealingViewController || self.revealingViewController.state == TRBRevealingViewControllerStateConcealed) &&
		self.tabBarController.selectedViewController == self.parentViewController) {
		[self fetchTorrentList];
	}
}

- (void)fetchTorrentList {
	[_refreshTimer invalidate];
	NSArray * hosts = [_hostList activeHosts];
	NSMutableSet * remaining = [NSMutableSet setWithArray:hosts];
	BOOL __block rescheduleTimer = NO;
	[hosts enumerateObjectsUsingBlock:^(TRBHost * host, NSUInteger idx, BOOL * stop) {
		if (!host.error) {
			[host.client fetchTorrentsWithCompletion:^(NSArray * torrents, NSError * error) {
				[remaining removeObject:host];
				host.error = error;
				if (!error) {
					[_sections replaceObjectAtIndex:idx withObject:torrents];
					if (!rescheduleTimer)
						rescheduleTimer = YES;
				} else
					[_sections replaceObjectAtIndex:idx withObject:[NSNull null]];
				if (!self.tableView.editing)
					[self.tableView reloadSections:[NSIndexSet indexSetWithIndex:idx] withRowAnimation:UITableViewRowAnimationNone];
				if ([remaining count] == 0 && rescheduleTimer) {
					NSTimeInterval delay = [self isUsingWiFi] ? _wifiRefreshRate : _cellularRefreshRate;
					_refreshTimer = [NSTimer scheduledTimerWithTimeInterval:delay
																	 target:self
																   selector:@selector(refreshTimerFired:)
																   userInfo:nil
																	repeats:NO];
				}
			}];
		} else {
			[remaining removeObject:host];
			if ([remaining count] == 0) {
				NSTimeInterval delay = [self isUsingWiFi] ? _wifiRefreshRate : _cellularRefreshRate;
				_refreshTimer = [NSTimer scheduledTimerWithTimeInterval:delay
																 target:self
															   selector:@selector(refreshTimerFired:)
															   userInfo:nil
																repeats:NO];
			}
		}
	}];
}

- (BOOL)isUsingWiFi {
	return _netStatus == ReachableViaWiFi;
}

- (void)reachabilityChanged:(NSNotification *)notification {
	_netStatus = [_wifiReach currentReachabilityStatus];
}

@end

static NSString * const PeersLabelFmt = @"%li of %li peers";
static NSString * const RatesLabelFmt = @"Down: %@ Up: %@";
static NSString * const DownloadedLabelFmt = @"%@ of %@ (%.2f%%)";

static NSString * const StatusStrings[TRBTorrentStatusCount] = {
	@"Torrent is stopped",
	@"Queued to check files",
	@"Checking files",
	@"Queued to download",
	@"Downloading",
	@"Queued to seed",
	@"Seeding",
};

#define SanitizeStatus(status) (((status) >= 0 && (status) < TRBTorrentStatusCount) ? (status) : 0)
#define StatusString(status) StatusStrings[SanitizeStatus(status)]

@implementation TRBTorrentListCell

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
    }
    return self;
}

- (void)prepareForReuse {
	[super prepareForReuse];
	_nameLabel.text = nil;
	_peersLabel.text = nil;
	_ratesLabel.text = nil;
	_downloadedLabel.text = nil;
	[_progressView setProgress:0.0];
}

#pragma mark - Public Methods

- (void)setupWithTorrent:(TRBTorrent *)torrent {
	_nameLabel.text = torrent.name;
	NSString * peersLabelText = @"";
	TRBTorrentStatus status = torrent.status;
	if (status != TRBTorrentStatusDownload && status != TRBTorrentStatusSeed)
		peersLabelText = StatusString(status);
	else
		peersLabelText = [NSString stringWithFormat:PeersLabelFmt, (long)[torrent.peersSendingToUs integerValue], (long)[torrent.peersConnected integerValue]];
	_peersLabel.text = peersLabelText;
	NSString * error = torrent.errorString;
	if ([error length])
		_ratesLabel.text = error;
	else
		_ratesLabel.text = [self rateStringWithDown:[torrent.rateDownload longLongValue] andUp:[torrent.rateUpload longLongValue]];
	_downloadedLabel.text = [self donwloadedStringWithCurrentSize:[torrent.haveValid longLongValue]
														totalSize:[torrent.sizeWhenDone longLongValue]
													   andPercent:[torrent.percentDone floatValue]];
	[_progressView setProgress:[torrent.percentDone floatValue] animated:NO];
}

#pragma mark - Private Methods

- (NSString *)rateStringWithDown:(long long)down andUp:(long long)up {
	return [NSString stringWithFormat:RatesLabelFmt, [NSString stringWithTransferRate:down], [NSString stringWithTransferRate:up]];
}

- (NSString *)donwloadedStringWithCurrentSize:(long long)current totalSize:(long long)total andPercent:(CGFloat)percent {
	return [NSString stringWithFormat:DownloadedLabelFmt, [NSString stringWithByteCount:current], [NSString stringWithByteCount:total], (percent * 100.0)];
}

@end
