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

#import "TRBRSSFeed.h"
#import "TRBXMLElement.h"
#import "NSString+TRBUnits.h"

@implementation TRBRSSFeed

#pragma mark - Initialization

- (id)initWithXMLElement:(TRBXMLElement *)element {
    self = [super init];
    if (self) {
		TRBXMLElement * channel = [element elementAtPath:@"rss.channel"];
		_title = channel[@"channel.title"];
		_link = channel[@"channel.link"];
		_desc = channel[@"channel.description"];
		_language = channel[@"channel.language"];
		_pubDate = channel[@"channel.pubDate"];
		_lastBuildDate = channel[@"channel.lastBuildDate"];
		_docs = channel[@"channel.docs"];
		_generator = channel[@"channel.generator"];
		NSArray * xmlItems = [channel elementsAtPath:@"channel.item"];
		__block NSMutableArray * items = [[NSMutableArray alloc] initWithCapacity:[xmlItems count]];
		[xmlItems enumerateObjectsUsingBlock:^(TRBXMLElement * element, NSUInteger idx, BOOL *stop) {
			TRBRSSItem * item = [[TRBRSSItem alloc] initWithXMLElement:element];
			[items addObject:item];
		}];
		_items = [NSArray arrayWithArray:items];
    }
    return self;
}

@end

@interface TRBRSSItem ()
@property (nonatomic, strong) NSDictionary * info;
@end

@implementation TRBRSSItem

#pragma mark - Initialization

- (id)initWithXMLElement:(TRBXMLElement *)element {
	self = [super init];
	if (self) {
		_title = element[@"item.title"];
		_link = element[@"item.link"];
		_comments = element[@"item.comments"];
		_pubDate = [element[@"item.pubDate"] shortDateFromInputFormat:@"EEE, dd MMM yyyy HH:mm:ss ZZZ"];
		_category = element[@"item.category"];
		_creator = element[@"item.creator"];
		_guid = element[@"item.guid"];
		_desc = element[@"item.description"];
		_seeders = element[@"item.numSeeders"];
		_leechers = element[@"item.numLeechers"];
		_magnetURI = element[@"item.torrent.magnetURI"];
		NSDictionary * enclosure = [[element elementAtPath:@"item.enclosure"] attributes];
		if ([enclosure count]) {
			_enclosureURL = enclosure[@"url"];
			_enclosureType = enclosure[@"type"];
			_enclosureLength = [enclosure[@"length"] longLongValue];
		}
	}
	return self;
}

// Size: 422 MB Seeds: 28 Peers: 1 Hash: be23e5537c07d0e82c454f3501e7b7a34179a313
- (NSDictionary *)infoFromDescription {
	if (!self.info) {
		NSError * error = nil;
		NSRegularExpression * regex = [NSRegularExpression regularExpressionWithPattern:@"(\\w+):"
																				options:0
																				  error:&error];
		LogCE(error != nil, error);
		if (!error) {
			NSRange testRange = NSMakeRange(0, [_desc length]);
			NSArray * matches = [regex matchesInString:_desc options:0 range:testRange];
			NSUInteger n = [matches count];
			NSMutableDictionary * info = [[NSMutableDictionary alloc] initWithCapacity:n];
			for (NSUInteger i = 0; i < n; i++) {
				NSTextCheckingResult * match = matches[i];
				if ([match numberOfRanges]) {
					NSRange keyRange = [match rangeAtIndex:1];
					NSString * key = [_desc substringWithRange:keyRange];
					NSRange valueRange;
					if ((i + 1) < n) {
						NSTextCheckingResult * nextMatch = matches[i + 1];
						valueRange = NSMakeRange(match.range.location + match.range.length, nextMatch.range.location - (match.range.location + match.range.length));
					} else
						valueRange = NSMakeRange(match.range.location + match.range.length, [_desc length] - (match.range.location + match.range.length));
					NSString * value = [[_desc substringWithRange:valueRange] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
					info[key] = value;
				}
			}
			self.info = info;
		}
	}
	return self.info;
}

@end
