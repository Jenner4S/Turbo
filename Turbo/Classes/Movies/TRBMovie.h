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

@interface TRBMovie : NSObject

@property (nonatomic, strong) NSString * vsID;
@property (nonatomic, strong) NSString * rtID;
@property (nonatomic, strong) NSNumber * tmdbID;
@property (nonatomic, strong) NSString * imdbID;
@property (nonatomic, strong) NSString * title;
@property (nonatomic, strong) NSString * genres;
@property (nonatomic, strong) NSNumber * criticsScore;
@property (nonatomic, strong) NSString * criticsRating;
@property (nonatomic, strong) NSNumber * audienceScore;
@property (nonatomic, strong) NSString * audienceRating;
@property (nonatomic, strong) NSString * criticsConsensus;
@property (nonatomic, strong) NSString * mpaaRating;
@property (nonatomic, strong) NSNumber * year;
@property (nonatomic, strong) NSNumber * runtime;
@property (nonatomic, strong) NSString * synopsis;
@property (nonatomic, strong) NSString * tagline;
@property (nonatomic, strong) NSDictionary * posters;
@property (nonatomic, strong) UIImage * posterImage;
@property (nonatomic, strong) NSString * backdropPath;
@property (nonatomic, strong) UIImage * backdropImage;
@property (nonatomic, strong) NSDictionary * links;
@property (nonatomic, strong) NSString * cast;
@property (nonatomic, strong) NSString * studio;
@property (nonatomic, strong) NSString * directors;
@property (nonatomic, strong) NSString * writers;
@property (nonatomic, strong) NSString * releaseDate;
@property (nonatomic, strong) NSArray * files;

- (instancetype)initWithVSJSON:(NSDictionary *)movie;
- (instancetype)initWithRTJSON:(NSDictionary *)movie;
- (void)updateWithVSInfo:(NSDictionary *)movie;
- (void)updateWithRTInfo:(NSDictionary *)movie;
- (void)updateWithTMDbInfo:(NSDictionary *)movie;

@end
