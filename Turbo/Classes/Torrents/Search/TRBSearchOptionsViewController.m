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

#import "TRBSearchOptionsViewController.h"
#import "TRBSearchViewController.h"

typedef NS_ENUM(NSInteger, TRBPickerViewType) {
	TRBPickerViewTypeAge = 0,
	TRBPickerViewTypeSize,

	TRBPickerViewTypeCount
};
typedef NS_ENUM(NSInteger, TRBPickerViewTitleCount) {
	TRBPickerViewAgeTitleCount = 3,
	TRBPickerViewSizeTitleCount = 3,
};
static NSUInteger TRBPickerViewRows[] = {TRBPickerViewAgeTitleCount, TRBPickerViewSizeTitleCount};
static NSString * TRBPickerViewAgeTitles[] = {@"days", @"weeks", @"months"};
static NSString * TRBPickerViewSizeTitles[] = {@"kilobytes", @"megabytes", @"gigabytes"};

NSString * const TRBAgeOptionKey = @"TRBAgeOption";
NSString * const TRBSizeOptionKey = @"TRBSizeOption";

@interface TRBPickerViewController : UIViewController
@property (nonatomic, strong) UIPickerView * pickerView;
@end

@implementation TRBPickerViewController

- (id)initWithPickerView:(UIPickerView *)pickerView {
	self = [super init];
	if (self) {
		_pickerView = pickerView;
		self.preferredContentSize = pickerView.frame.size;
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	CGFloat color = 235.0 / 255;
	self.view.backgroundColor = [UIColor colorWithRed:color green:color blue:color alpha:1.0];
	self.view.autoresizingMask = UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleBottomMargin|UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin;
	[self.view addSubview:_pickerView];
	if (isIdiomPhone) {
		self.view.frame = CGRectMake(0.0, 0.0, CGRectGetWidth(_pickerView.frame), CGRectGetHeight(self.view.frame));
		_pickerView.frame = CGRectMake(0.0, CGRectGetMaxY(self.view.bounds) - CGRectGetHeight(_pickerView.frame),
										 CGRectGetWidth(_pickerView.frame), CGRectGetHeight(_pickerView.frame));
		_pickerView.translatesAutoresizingMaskIntoConstraints = NO;
		NSArray * verticalContraints = [NSLayoutConstraint constraintsWithVisualFormat:@"V:[picker]-0-|"
																			   options: 0
																			   metrics:nil
																				 views:@{@"picker" : _pickerView}];
		NSArray * horizontalContraints = [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-0-[picker]-0-|"
																				 options:0
																				 metrics:nil
																				   views:@{@"picker" : _pickerView}];
		[self.view addConstraints:verticalContraints];
		[self.view addConstraints:horizontalContraints];
	}
}

@end

@interface TRBSearchOptionsViewController ()
@property (weak, nonatomic) IBOutlet UITextField * ageTextField;
@property (weak, nonatomic) IBOutlet UISegmentedControl * ageSegmentedControl;
@property (weak, nonatomic) IBOutlet UIButton * ageButton;
@property (weak, nonatomic) IBOutlet UITextField *sizeTextField;
@property (weak, nonatomic) IBOutlet UISegmentedControl * sizeSegmentedControl;
@property (weak, nonatomic) IBOutlet UIButton * sizeButton;
@end

@implementation TRBSearchOptionsViewController {
	TRBPickerViewController * _agePickerViewController;
	TRBPickerViewController * _sizePickerViewController;

	UIPopoverController * _popoverController;
}

#pragma mark - Initialization

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        _options = [[NSMutableDictionary alloc] initWithCapacity:4];
    }
    return self;
}

#pragma mark - View Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
	UIPickerView * agePickerView = [[UIPickerView alloc] init];
	agePickerView.dataSource = self;
	agePickerView.delegate = self;
	agePickerView.showsSelectionIndicator = YES;
	agePickerView.tag = TRBPickerViewTypeAge;
	[agePickerView selectRow:1 inComponent:0 animated:NO];
	_agePickerViewController = [[TRBPickerViewController alloc] initWithPickerView:agePickerView];

	UIPickerView * sizePickerView = [[UIPickerView alloc] init];
	sizePickerView.dataSource = self;
	sizePickerView.delegate = self;
	sizePickerView.showsSelectionIndicator = YES;
	sizePickerView.tag = TRBPickerViewTypeSize;
	[sizePickerView selectRow:2 inComponent:0 animated:NO];
	_sizePickerViewController = [[TRBPickerViewController alloc] initWithPickerView:sizePickerView];

	self.navigationItem.rightBarButtonItem.target = self;
	self.navigationItem.rightBarButtonItem.action = @selector(applyButtonPressed:);
	self.navigationItem.leftBarButtonItem.target = self;
	self.navigationItem.leftBarButtonItem.action = @selector(resetButtonPressed:);

	if (isIdiomPad)
		_popoverController = [[UIPopoverController alloc] initWithContentViewController:_agePickerViewController];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[self.view endEditing:YES];
}

//- (void)didReceiveMemoryWarning {
//    [super didReceiveMemoryWarning];
//}

#pragma mark - Public Methods

- (void)reset {
	[_options removeAllObjects];

	_ageTextField.text = nil;
	_sizeTextField.text = nil;

	[_sizeSegmentedControl setSelectedSegmentIndex:0];

	[_ageButton setTitle:@"days" forState:UIControlStateNormal];
	_ageButton.tag = 1;
	[_sizeButton setTitle:@"gigabytes" forState:UIControlStateNormal];
	_sizeButton.tag = 2;

	[_agePickerViewController.pickerView selectRow:1 inComponent:0 animated:NO];
	[_sizePickerViewController.pickerView selectRow:2 inComponent:0 animated:NO];

	[self.view endEditing:YES];
}

#pragma mark - IBActions

- (IBAction)ageButtonPressed:(UIButton *)sender {
	[self.view endEditing:YES];
	if (isIdiomPad) {
		[_popoverController setContentViewController:_agePickerViewController];
		CGRect frame = [self.view convertRect:sender.frame fromView:sender.superview];
		[_popoverController presentPopoverFromRect:frame
											inView:self.view
						  permittedArrowDirections:UIPopoverArrowDirectionUp
										  animated:YES];
	} else {
		_agePickerViewController.modalTransitionStyle = UIModalTransitionStylePartialCurl;
		[self presentViewController:_agePickerViewController animated:YES completion:NULL];
	}
}

- (IBAction)sizeButtonPressed:(UIButton *)sender {
	[self.view endEditing:YES];
	if (isIdiomPad) {
		[_popoverController setContentViewController:_sizePickerViewController];
		CGRect frame = [self.view convertRect:sender.frame fromView:sender.superview];
		[_popoverController presentPopoverFromRect:frame
											inView:self.view
						  permittedArrowDirections:UIPopoverArrowDirectionUp
										  animated:YES];
	} else {
		_sizePickerViewController.modalTransitionStyle = UIModalTransitionStylePartialCurl;
		[self presentViewController:_sizePickerViewController animated:YES completion:NULL];
	}
}

- (IBAction)sizeOperatorChanged:(UISegmentedControl *)sender {
	[self updateSizeOption];
}

- (IBAction)ageUnitValueChanged:(UISegmentedControl *)sender {
	[self updateAgeOption];
}

- (IBAction)resetButtonPressed:(id)sender {
	[self reset];
}

- (IBAction)applyButtonPressed:(id)sender {
	[self.view endEditing:YES];
	if (_optionsUpadated)
		_optionsUpadated([_options copy]);
	[self.revealingViewController concealViewControllerAnimated:YES completion:NULL];
}

#pragma mark - UITextFieldDelegate Implementation

//- (void)textFieldDidBeginEditing:(UITextField *)textField {
//
//}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
	BOOL result = YES;
	if ((textField == _ageTextField || textField == _sizeTextField) && [string length]) {
		NSRegularExpression * regex = [NSRegularExpression regularExpressionWithPattern:@"^[0-9]+$"
																				options:0
																				  error:NULL];
		NSRange match = [regex rangeOfFirstMatchInString:string options:0 range:NSMakeRange(0, [string length])];
		result = match.location != NSNotFound;
	}
	return result;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
	if (textField == _ageTextField)
		[self updateAgeOption];
	else if (textField == _sizeTextField)
		[self updateSizeOption];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	[textField resignFirstResponder];
	if (_optionsUpadated)
		_optionsUpadated([_options copy]);
	[self.revealingViewController concealViewControllerAnimated:YES completion:NULL];
	return NO;
}

#pragma mark - UIPickerViewDataSource Implementation

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
	return TRBPickerViewRows[pickerView.tag];
}

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
	return 1;
}

#pragma mark - UIPickerViewDelegate Implementation

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
	NSString * result = @"";
	switch (pickerView.tag) {
		case TRBPickerViewTypeAge:
			result = TRBPickerViewAgeTitles[row];
			break;
		case TRBPickerViewTypeSize:
			result = TRBPickerViewSizeTitles[row];
			break;
		default:
			break;
	}
	return result;
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
	NSString * selected = nil;
	switch (pickerView.tag) {
		case TRBPickerViewTypeAge: {
			selected = TRBPickerViewAgeTitles[row];
			[_ageButton setTitle:selected forState:UIControlStateNormal];
			_ageButton.tag = row;
			[self updateAgeOption];
			break;
		} case TRBPickerViewTypeSize: {
			selected = TRBPickerViewSizeTitles[row];
			[_sizeButton setTitle:selected forState:UIControlStateNormal];
			_sizeButton.tag = row;
			[self updateSizeOption];
			break;
		} default:
			break;
	}
}

#pragma mark - Private Methods

- (void)updateAgeOption {
    NSString * age = _ageTextField.text;
    if ([age length]) {
        NSString * selectedTimeUnit = [TRBPickerViewAgeTitles[_ageButton.tag] substringToIndex:1];
        NSString * selectedComparator = _ageSegmentedControl.selectedSegmentIndex ? @"<" : @">";
        _options[TRBAgeOptionKey] = [NSString stringWithFormat:@"added %@ %@%@", selectedComparator, age, selectedTimeUnit];
    } else
        [_options setValue:nil forKey:TRBAgeOptionKey];
}

- (void)updateSizeOption {
    NSString * size = _sizeTextField.text;
    if ([size length]) {
        NSString * selectedSizeUnit = [TRBPickerViewSizeTitles[_sizeButton.tag] substringToIndex:1];
        NSString * selectedComparator = _sizeSegmentedControl.selectedSegmentIndex ? @"<" : @">";
        _options[TRBSizeOptionKey] = [NSString stringWithFormat:@"size %@ %@%@", selectedComparator, size, selectedSizeUnit];
    } else
        [_options setValue:nil forKey:TRBSizeOptionKey];
}

- (NSArray *)constraintsForPicker:(UIPickerView *)pickerView {
	NSArray * verticalContraints = [NSLayoutConstraint constraintsWithVisualFormat:@"V:[picker]-0-|"
																		   options: 0
																		   metrics:nil
																			 views:@{@"picker" : pickerView}];
	NSArray * horizontalContraints = [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-0-[picker]-0-|"
																			 options:0
																			 metrics:nil
																			   views:@{@"picker" : pickerView}];
	NSMutableArray * result = [NSMutableArray arrayWithArray:verticalContraints];
	[result addObjectsFromArray:horizontalContraints];
	return result;
}

@end
