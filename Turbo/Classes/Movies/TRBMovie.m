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

#import "TRBMovie.h"
#import "NSArray+TRBAdditions.h"

@implementation TRBMovie

#pragma mark - Initialization

- (instancetype)initWithVSJSON:(NSDictionary *)movie {
	self = [super init];
	if (self) {
		NSDictionary * additional = movie[@"additional"];
		_vsID = movie[@"id"];
		_title = movie[@"title"];
		_tagline = movie[@"tagline"];
		_releaseDate = movie[@"original_available"];

		NSArray * genres = additional[@"genre"];
		_genres = [genres joinSelecionWithString:@", " selectionBlock:^NSString *(NSDictionary * item) {
			return item[@"name"];
		}];
	}
	return self;
}

- (instancetype)initWithRTJSON:(NSDictionary *)movie {
	self = [super init];
	if (self) {
		_rtID = movie[@"id"];
		_title = movie[@"title"];
		NSDictionary * ratings = movie[@"ratings"];
		_criticsScore = ratings[@"critics_score"];
		_criticsRating = [ratings[@"critics_rating"] lowercaseString];
		_audienceScore = ratings[@"audience_score"];
		_audienceRating = [ratings[@"audience_rating"] lowercaseString];
		_criticsConsensus = movie[@"critics_consensus"];
		_mpaaRating = movie[@"mpaa_rating"];
		_synopsis = movie[@"synopsis"];
		_year = movie[@"year"];
		_runtime = movie[@"runtime"];
		NSString * imdbID = movie[@"alternate_ids"][@"imdb"];
		if ([imdbID isKindOfClass:[NSString class]])
			_imdbID = [NSString stringWithFormat:@"tt%@", imdbID];
		_posters = movie[@"posters"];
		_links = movie[@"links"];

		NSArray * cast = movie[@"abridged_cast"];
		_cast = [cast joinSelecionWithString:@" | " selectionBlock:^NSString *(NSDictionary * item) {
			return item[@"name"];
		}];

		_releaseDate = movie[@"release_dates"][@"theater"];
	}
	return self;
}

#pragma mark - Public Methods

- (void)updateWithVSInfo:(NSDictionary *)movie {
	NSDictionary * additional = movie[@"additional"];

	_synopsis = additional[@"summary"];

	NSString *(^selectionBlock)(NSDictionary * item) = ^NSString *(NSDictionary * item) {
		return item[@"name"];
	};

	NSArray * actors = additional[@"actor"];
	_cast = [actors joinSelecionWithString:@" | " selectionBlock:selectionBlock];

	NSArray * directors = additional[@"director"];
	_directors = [directors joinSelecionWithString:@", " selectionBlock:selectionBlock];

	NSArray * writers = additional[@"writer"];
	_writers = [writers joinSelecionWithString:@", " selectionBlock:selectionBlock];

	NSString * extraString = additional[@"extra"];
	NSError * error = nil;
	NSDictionary * extra = [NSJSONSerialization JSONObjectWithData:[extraString dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:&error];
	if (!error) {
		NSDictionary * tmdbInfo = extra[@"com.synology.TheMovieDb"][@"reference"];
		_tmdbID = tmdbInfo[@"themoviedb"];
		_imdbID = tmdbInfo[@"imdb"];
	}

	_files = additional[@"files"];
}

- (void)updateWithRTInfo:(NSDictionary *)movie {
	NSArray * genres = movie[@"genres"];
	_genres = [genres componentsJoinedByString:@", "];

	NSArray * directors = movie[@"abridged_directors"];
	_directors = [directors joinSelecionWithString:@", " selectionBlock:^NSString *(NSDictionary * item) {
		return item[@"name"];
	}];
	_studio = movie[@"studio"];
}

- (void)updateWithTMDbInfo:(NSDictionary *)movie {
	_tmdbID = movie[@"id"];
	_backdropPath = movie[@"backdrop_path"];
	if (![_synopsis length])
		_synopsis = movie[@"overview"];
	if (![_imdbID length])
		_imdbID = movie[@"imdb_id"];
	if (![_genres length]) {
		NSArray * genres = movie[@"genres"];
		NSMutableString * genresString = [NSMutableString new];
		for (NSDictionary * genre in genres) {
			[genresString appendString:genre[@"name"]];
			if ([genres lastObject] != genre)
				[genresString appendString:@", "];
		}
		_genres = [genresString copy];
	}
}

@end
