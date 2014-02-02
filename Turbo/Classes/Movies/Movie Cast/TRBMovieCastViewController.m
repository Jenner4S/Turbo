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

#import "TRBMovieCastViewController.h"
#import "TRBRottenTomatoesClient.h"
#import "TRBTMDbClient.h"
#import "TRBMovie.h"
#import "TKAlertCenter.h"

typedef NS_ENUM(NSUInteger, TMDbCastSection) {
	TRBCastSectionCast = 0,
	TRBCastSectionCrew,

	TRBCastSectionCount
};

static NSString * const TRBCastSectionTitles[TRBCastSectionCount] = {@"Cast", @"Crew" };

@interface TRBMovieCastViewController ()

@end

@implementation TRBMovieCastViewController {
	TRBCastSource _source;
	NSArray * _rtCasts;
	NSMutableArray * _tmdbCasts;
	NSMutableDictionary * _images;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
		_tmdbCasts = [[NSMutableArray alloc] initWithCapacity:TRBCastSectionCount];
		_images = [NSMutableDictionary new];
    }
    return self;
}

//- (void)viewDidLoad {
//    [super viewDidLoad];
//}

#pragma mark - Public Methods

- (void)showCastForMovie:(TRBMovie *)movie andSource:(TRBCastSource)source {
	_source = source;
	switch (_source) {
		case TRBCastSourceRT:
			[self fetcthRTCastForMovie:movie];
			break;
		case TRBCastSourceTMDb:
			[self fetchTMDbCastForMovie:movie];
			break;
		default:
			break;
	}
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	NSInteger result = 0;
	switch (_source) {
		case TRBCastSourceRT:
			result = 1;
			break;
		case TRBCastSourceTMDb:
			result = [_tmdbCasts count];
			break;
		default:
			break;
	}
    return result;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	NSInteger result = 0;
	switch (_source) {
		case TRBCastSourceRT:
			result = [_rtCasts count];
			break;
		case TRBCastSourceTMDb:
			result = [_tmdbCasts[section] count];
			break;
		default:
			break;
	}
    return result;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"TRBCastCell";
    UITableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];

	switch (_source) {
		case TRBCastSourceRT:
			[self setupCell:cell forRTCastAtIndex:indexPath];
			break;
		case TRBCastSourceTMDb:
			[self setupCell:cell forTMDbCastAtIndex:indexPath];
			break;
		default:
			break;
	}

    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	return TRBCastSectionTitles[section];
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	CGFloat result = 44.0;
	if (_source == TRBCastSourceTMDb) {
		result = [UIScreen mainScreen].scale > 1.0 ? 132.0 : 68.0;
		NSDictionary * cast = _tmdbCasts[indexPath.section][indexPath.row];
		UIImage * profile = _images[cast[@"profile_path"]];
		if (profile)
			result = profile.size.height;
	}
	return result;
}

#pragma mark - Private Methods

- (void)fetcthRTCastForMovie:(TRBMovie *)movie {
    [[TRBRottenTomatoesClient sharedInstance] fetchCastsInfoForID:movie.rtID withHandler:^(NSDictionary *json, NSError *error) {
		LogCE(error, [error localizedDescription]);
		if (json) {
			_rtCasts = json[@"cast"];
			[self.tableView reloadData];
		} else if (error)
			[[TKAlertCenter defaultCenter] postAlertWithMessage:[error localizedDescription]];
	}];
}

- (void)fetchTMDbCastForMovie:(TRBMovie *)movie {
	[[TRBTMDbClient sharedInstance] fetchMovieCastsWithID:movie.tmdbID completion:^(NSDictionary * json, NSError * error) {
		if (json) {
			_tmdbCasts[TRBCastSectionCast] = json[@"cast"];
			_tmdbCasts[TRBCastSectionCrew] = json[@"crew"];
			[self.tableView reloadData];
		} else if (error)
		[[TKAlertCenter defaultCenter] postAlertWithMessage:[error localizedDescription]];
	}];
}

- (void)setupCell:(UITableViewCell *)cell forRTCastAtIndex:(NSIndexPath *)indexPath {
	NSDictionary * cast = _rtCasts[indexPath.row];

	cell.textLabel.text = cast[@"name"];

	NSArray * characters = cast[@"characters"];
	NSMutableString * chars = [NSMutableString new];
	for (NSString * character in characters) {
		[chars appendString:character];
		if (character != [characters lastObject])
			[chars appendString:@", "];
	}
	cell.detailTextLabel.text = chars;
}

- (void)setupCell:(UITableViewCell *)cell forTMDbCastAtIndex:(NSIndexPath *)indexPath {
	NSDictionary * cast = _tmdbCasts[indexPath.section][indexPath.row];

	cell.textLabel.text = cast[@"name"];

	switch (indexPath.section) {
		case TRBCastSectionCast: {
			NSString * character = cast[@"character"];
			if ([character isKindOfClass:[NSString class]])
				cell.detailTextLabel.text = character;
			break;
		} case TRBCastSectionCrew: {
			NSString * job = cast[@"job"];
			if ([job isKindOfClass:[NSString class]])
				cell.detailTextLabel.text = cast[@"job"];
			break;
		} default:
			break;
	}

	UIImage * profile = nil;
	if (cast[@"profile_path"] != [NSNull null]) {
		profile = _images[cast[@"profile_path"]];
		if (!profile) {
			TRBTMDbProfileSize size = [UIScreen mainScreen].scale > 1.0 ? TRBTMDbProfileSizeW185 : TRBTMDbProfileSizeW45;
			[[TRBTMDbClient sharedInstance] fetchProfileImage:cast[@"profile_path"] withSize:size completion:^(UIImage * image, NSError * error) {
				LogCE(error, [error localizedDescription]);
				if (!image)
					image = [UIImage imageNamed:@"profile"];
				_images[cast[@"profile_path"]] = image;
				[self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
			}];
		}
	} else
		profile = [UIImage imageNamed:@"profile"];

	cell.imageView.image = profile;
}

@end
