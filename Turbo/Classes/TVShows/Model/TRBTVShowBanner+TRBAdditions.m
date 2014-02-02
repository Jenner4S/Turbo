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

#import "TRBTVShowBanner+TRBAdditions.h"
#import "TRBXMLElement.h"

#define FloatColor(color) (color / 255.0)

@implementation TRBTVShowBanner (TRBAdditions)

@dynamic lightAccentColor;
@dynamic darkAccentColor;
@dynamic neutralMidtoneColor;

- (void)setupWithXML:(TRBXMLElement *)xml {
	self.bannerID = @([xml[@"Banner.id"] integerValue]);
	self.bannerPath = xml[@"Banner.BannerPath"];
	self.bannerType = xml[@"Banner.BannerType"];
	self.bannerType2 = xml[@"Banner.BannerType2"];
	self.colors = xml[@"Banner.Colors"];
	self.language = xml[@"Banner.Language"];
	self.rating = @([xml[@"Banner.Rating"] doubleValue]);
	self.ratingCount = @([xml[@"Banner.RatingCount"] integerValue]);
	self.seriesName = @([xml[@"Banner.SeriesName"] isEqualToString:@"true"]);
	self.thumbnailPath = xml[@"Banner.ThumbnailPath"];
	self.vignettePath = xml[@"Banner.VignettePath"];
	self.season = @([xml[@"Banner.Season"] integerValue]);
}

- (UIColor *)lightAccentColor {
	return [self colorAtIndex:0];
}

- (UIColor *)darkAccentColor {
	return [self colorAtIndex:1];
}

- (UIColor *)neutralMidtoneColor {
	return [self colorAtIndex:2];
}

- (UIColor *)colorAtIndex:(NSUInteger)index {
	UIColor * color = nil;
	if ([self.colors length]) {
		NSArray * colorStrings = [self.colors componentsSeparatedByString:@"|"];
		if ([colorStrings count] == 5) {
			NSString * colorString = colorStrings[++index];
			NSArray * colorComponets = [colorString componentsSeparatedByString:@","];
			if ([colorComponets count] == 3) {
				color = [UIColor colorWithRed:FloatColor([colorComponets[0] floatValue])
										green:FloatColor([colorComponets[1] floatValue])
										 blue:FloatColor([colorComponets[2] floatValue])
										alpha:1.0f];
			}
		}
	}
	return color;
}

@end
