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

#import "TRBSettingsViewController.h"
#import "TRBTvDBClient.h"
#import "TRBDataCache.h"

@interface TRBSettingsViewController () <UITextFieldDelegate>
@property (weak, nonatomic) IBOutlet UILabel * wifiRefreshRateLabel;
@property (weak, nonatomic) IBOutlet UILabel * cellularRefreshRateLabel;
@property (weak, nonatomic) IBOutlet UISegmentedControl * imdbSearchSegmentedControl;
@property (weak, nonatomic) IBOutlet UIStepper * wifiRefreshRateStepper;
@property (weak, nonatomic) IBOutlet UIStepper * cellularRefreshRateStepper;
@property (weak, nonatomic) IBOutlet UIStepper * dbUpdateRateStepper;
@property (weak, nonatomic) IBOutlet UILabel *dbUpdateRateLabel;
@property (weak, nonatomic) IBOutlet UISwitch *tvShowEpisodeNotificationSwitch;
@property (weak, nonatomic) IBOutlet UITextField *synologyHostTextField;
@property (weak, nonatomic) IBOutlet UITextField *synologyPortTextField;
@end

@implementation TRBSettingsViewController {
	NSMutableDictionary * _updateInfo;
}

- (void)viewDidLoad {
    [super viewDidLoad];
	_updateInfo = [NSMutableDictionary new];
	NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
	NSTimeInterval wifiRefreshRate = [defaults doubleForKey:TRBWiFiRefreshRateKey];
	if (!wifiRefreshRate)
		wifiRefreshRate = 1.0;
	[self updateWifiRefreshRateLabelWithValue:(NSInteger)wifiRefreshRate];
	_wifiRefreshRateStepper.value = wifiRefreshRate;
	NSTimeInterval cellularRefreshRate = [defaults doubleForKey:TRBCellularRefreshRateKey];
	if (!cellularRefreshRate)
		cellularRefreshRate = 10.0;
	[self updateCellularRefreshRateLabelWithValue:(NSInteger)cellularRefreshRate];
	_cellularRefreshRateStepper.value = cellularRefreshRate;
	BOOL IMDbWebOnlyApp = [defaults boolForKey:TRBIMDbSearchWebOnlyKey];
	NSInteger index = IMDbWebOnlyApp ? 1 : 0;
	_imdbSearchSegmentedControl.selectedSegmentIndex = index;
	NSTimeInterval tvShowRefreshRate = [defaults doubleForKey:TRBTVShowInfoRefreshRateKey];
	if (tvShowRefreshRate) {
		_dbUpdateRateStepper.value = tvShowRefreshRate;
		_dbUpdateRateLabel.text = [NSString stringWithFormat:@"Update TV Show information %@ day%@",
								   tvShowRefreshRate > 1.0 ? @(tvShowRefreshRate) : @"every", tvShowRefreshRate > 1 ? @"s" : @""];
	}
	_tvShowEpisodeNotificationSwitch.on = [defaults boolForKey:TRBTVShowNotificationsKey];
	_synologyHostTextField.text = [defaults objectForKey:TRBSynologyHostKey];
	NSString * port = [defaults objectForKey:TRBSynologyPortKey];
	if ([port length])
		_synologyPortTextField.text = port;
	else if ([_synologyPortTextField.text length])
		[defaults setObject:_synologyPortTextField.text forKey:TRBSynologyPortKey];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[_synologyHostTextField resignFirstResponder];
	[_synologyPortTextField resignFirstResponder];
	if ([_updateInfo count]) {
		[[NSNotificationCenter defaultCenter] postNotificationName:TRBSettingsUpdatedNotification object:self userInfo:[_updateInfo copy]];
		[_updateInfo removeAllObjects];
	}
}

#pragma mark - IBActions

- (IBAction)wifiStepperValueChanged:(UIStepper *)sender {
	NSTimeInterval value = sender.value;
	[self updateWifiRefreshRateLabelWithValue:(NSInteger)value];
	_updateInfo[TRBWiFiRefreshRateKey] = @(value);
	[[NSUserDefaults standardUserDefaults] setDouble:value forKey:TRBWiFiRefreshRateKey];
}

- (IBAction)cellularSepperValueChanged:(UIStepper *)sender {
	NSTimeInterval value = sender.value;
	[self updateCellularRefreshRateLabelWithValue:(NSInteger)value];
	_updateInfo[TRBCellularRefreshRateKey] = @(value);
	[[NSUserDefaults standardUserDefaults] setDouble:value forKey:TRBCellularRefreshRateKey];
}

- (IBAction)imdbSearchValueChanged:(UISegmentedControl *)sender {
	NSInteger selected = sender.selectedSegmentIndex;
	BOOL webOnly = selected == 1;
	_updateInfo[TRBIMDbSearchWebOnlyKey] = @(webOnly);
	[[NSUserDefaults standardUserDefaults] setBool:webOnly forKey:TRBIMDbSearchWebOnlyKey];
}
- (IBAction)dbUpdateStepperValueChanged:(UIStepper *)sender {
	NSTimeInterval value = sender.value;
	_updateInfo[TRBTVShowInfoRefreshRateKey] = @(value);
	_dbUpdateRateLabel.text = [NSString stringWithFormat:@"Update TV Shows every %@ day%@", value > 1.0 ? @(value) : @"", value > 1 ? @"s" : @""];
	[[NSUserDefaults standardUserDefaults] setDouble:value forKey:TRBTVShowInfoRefreshRateKey];
}

- (IBAction)clearCacheButtonPressed:(id)sender {
	[[TRBDataCache sharedInstance] clearCache];
}

- (IBAction)notificationsSwitchValueChanged:(UISwitch *)sender {
	BOOL disabled = sender.on;
	[[NSUserDefaults standardUserDefaults] setBool:disabled forKey:TRBTVShowNotificationsKey];
	if (disabled)
		[[TRBTvDBClient sharedInstance] removeEpisodeNotifications];
	else
		[[TRBTvDBClient sharedInstance] scheduleEpisodeNotifications];
	_updateInfo[TRBTVShowNotificationsKey] = @(disabled);
}

#pragma mark - UITextFieldDelegate Implementation

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	[textField resignFirstResponder];
	return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
	NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
	NSString * key = textField == _synologyHostTextField ? TRBSynologyHostKey : TRBSynologyPortKey;
	if (![textField.text length]) {
		[defaults removeObjectForKey:key];
		[_updateInfo removeObjectForKey:key];
	} else {
		[defaults setObject:textField.text forKey:key];
		_updateInfo[key] = textField.text;
	}
}

#pragma mark - Private Methods

- (void)updateWifiRefreshRateLabelWithValue:(NSInteger)value {
	_wifiRefreshRateLabel.text = [NSString stringWithFormat:@"%li second%@", (long)value, value > 1 ? @"s" : @""];
}

- (void)updateCellularRefreshRateLabelWithValue:(NSInteger)value {
	_cellularRefreshRateLabel.text = [NSString stringWithFormat:@"%li second%@", (long)value, value > 1 ? @"s" : @""];
}

@end
