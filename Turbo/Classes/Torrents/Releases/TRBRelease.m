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

#import "TRBRelease.h"
#import "NSString+TRBUnits.h"
#import "TRBXMLElement.h"

typedef NS_ENUM(NSUInteger, TRBReleaseCategory) {
	TRBReleaseCategoryType = 0,
	TRBReleaseCategorySubType,
	TRBReleaseCategoryVideoFormat,
	TRBReleaseCategorySource,
	TRBReleaseCategoryGroup,
	TRBReleaseCategoryGenre,
	TRBReleaseCategoryYear,
};

@implementation TRBRelease

- (id)initWithXMLElement:(TRBXMLElement *)element {
	self = [super init];
	if (self) {
		_title = element[@"item.title"];
		_link = element[@"item.link"];
		_desc = element[@"item.description"];
		NSLocale * locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
//		<pubDate>Sat, 23 Mar 2013 02:10:23 +0000</pubDate> 
		_pubDate = [element[@"item.pubDate"] dateFromInputFormat:@"EEE, dd MMM yyyy HH:mm:ss ZZZ" withLocale:locale];
		NSArray * categories = [element elementsAtPath:@"item.category"];
		TRBReleaseCategory lastIndex = [categories count] - 1;
		switch (lastIndex) {
			case TRBReleaseCategoryYear:
				_year = [(TRBXMLElement *)categories[TRBReleaseCategoryYear] text];
			case TRBReleaseCategoryGenre:
				_genre = [(TRBXMLElement *)categories[TRBReleaseCategoryGenre] text];
			case TRBReleaseCategoryGroup:
				_group = [(TRBXMLElement *)categories[TRBReleaseCategoryGroup] text];
			case TRBReleaseCategorySource:
				_source = [(TRBXMLElement *)categories[TRBReleaseCategorySource] text];
			case TRBReleaseCategoryVideoFormat:
				_videoFormat = [(TRBXMLElement *)categories[TRBReleaseCategoryVideoFormat] text];
			case TRBReleaseCategorySubType:
				_subType = [(TRBXMLElement *)categories[TRBReleaseCategorySubType] text];
			case TRBReleaseCategoryType:
				_type = [(TRBXMLElement *)categories[TRBReleaseCategoryType] text];
			default:
				break;
		}
	}
	return self;
}

@end
