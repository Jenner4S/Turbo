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

#import "TRBTVShowsStorage.h"
#import "TRBTVShow.h"
#import "TRBTVShow+TRBAdditions.h"
#import "TRBTVShowEpisode.h"
#import "TRBTVShowEpisode+TRBAddtions.h"
#import "TRBTVShowBanner.h"
#import "TRBTVShowBanner+TRBAdditions.h"
#import "TRBTVShowSeason.h"
#import "TRBXMLElement+TRBTVShow.h"
#import "TRBXMLElement.h"

#define FileManager [NSFileManager defaultManager]
#define kSecondsInDay 86400.0

static NSString * const SQLiteStorageName = @"TRBTVShows.sqlite";
static BOOL saving = NO;

static NSString * TRBTVShowBannerTypeStrings[TRBTVShowBannerTypeCount] = {@"poster", @"fanart", @"series", @"season"};

@interface TRBTVShowsStorage ()
@property (atomic, readonly) NSManagedObjectModel * managedObjectModel;
@property (atomic, readonly) NSManagedObjectContext * managedObjectContext;
@property (atomic, readonly) NSManagedObjectContext * managedObjectContextMain;
@property (atomic, readonly) NSPersistentStoreCoordinator * persistentStoreCoordinator;
@end

@implementation TRBTVShowsStorage {
	id _observer;
	id _observerMain;
}

+ (instancetype)sharedInstance {
	static id sharedInstance = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedInstance = [[self alloc] init];
	});
	return sharedInstance;
}

- (instancetype)init {
	self = [super init];
	if (self) {
		if (!_managedObjectModel)
			_managedObjectModel = [NSManagedObjectModel mergedModelFromBundles:@[[NSBundle mainBundle]]];
		[self createPersistentStoreCoordinator];
		if (!_managedObjectContext) {
			_managedObjectContextMain = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSConfinementConcurrencyType];
			[_managedObjectContextMain setPersistentStoreCoordinator:self.persistentStoreCoordinator];
			[_managedObjectContextMain setMergePolicy:NSMergeByPropertyObjectTrumpMergePolicy];
		}
		if (!_managedObjectContext) {
			_managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
			[_managedObjectContext setPersistentStoreCoordinator:self.persistentStoreCoordinator];
			[_managedObjectContext setMergePolicy:NSMergeByPropertyObjectTrumpMergePolicy];
		}
		if (!_observer) {
			_observer = [[NSNotificationCenter defaultCenter] addObserverForName:NSManagedObjectContextDidSaveNotification
																		  object:_managedObjectContext
																		   queue:[NSOperationQueue mainQueue]
																	  usingBlock:^(NSNotification *note) {
																		  [_managedObjectContextMain mergeChangesFromContextDidSaveNotification:note];
																	  }];
		}
		if (!_observerMain) {
			_observerMain = [[NSNotificationCenter defaultCenter] addObserverForName:NSManagedObjectContextDidSaveNotification
																			  object:_managedObjectContextMain
																			   queue:[NSOperationQueue mainQueue]
																		  usingBlock:^(NSNotification *note) {
																			  [_managedObjectContext mergeChangesFromContextDidSaveNotification:note];
																		  }];
		}
	}
	return self;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:_observer];
	[[NSNotificationCenter defaultCenter] removeObserver:_observerMain];
}

#pragma mark - Public Methods

#pragma mark TV Shows

- (void)insertNewTVShowWithXML:(TRBXMLElement *)xml overwrite:(BOOL)overwrite andHandler:(void(^)(TRBTVShow * tvShow))handler {
	NSInteger seriesID = [xml[@"Series.id"] integerValue];
	[self fetchTVShowWithID:seriesID andHandler:^(TRBTVShow *tvShow) {
		if (!tvShow) {
			[self.managedObjectContext performBlock:^{
				TRBTVShow * result = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([TRBTVShow class])
																  inManagedObjectContext:self.managedObjectContext];

				[result setupWithXML:xml];
				NSError * error = nil;
				[self.managedObjectContext save:&error];
				LogCE(error, [error localizedDescription]);
				if (handler) {
					NSManagedObjectID * moID = result.objectID;
					dispatch_async(dispatch_get_main_queue(), ^{
						handler((TRBTVShow *)[self.managedObjectContextMain objectWithID:moID]);
					});
				}
			}];
		} else if (overwrite) {
			[tvShow setupWithXML:xml];
			[self.managedObjectContextMain save:NULL];
			if (handler)
				handler(tvShow);
		} else if (handler)
			handler(nil);
	}];
}

- (void)updateTVShowWithRecords:(NSArray *)records andHandler:(void(^)(TRBTVShow * result))handler {
	[self.managedObjectContext performBlock:^{
		NSMutableArray * xmls = [records mutableCopy];
		TRBXMLElement * seriesXML = xmls[0];
		NSInteger seriesID = [seriesXML[@"Series.id"] integerValue];
		NSEntityDescription * entity = [NSEntityDescription entityForName:NSStringFromClass([TRBTVShow class])
												   inManagedObjectContext:self.managedObjectContext];
		NSFetchRequest * request = [[NSFetchRequest alloc] init];
		[request setEntity:entity];
		NSPredicate * predicate = [NSPredicate predicateWithFormat:@"seriesID = %i", seriesID];
		[request setPredicate:predicate];
		[request setFetchLimit:1];
		[request setReturnsDistinctResults:YES];
		NSError * error = nil;
		NSArray * array = [self.managedObjectContext executeFetchRequest:request error:&error];
		LogCE(error, [error localizedDescription]);
		TRBTVShow * tvShow = [array lastObject];
		if (!tvShow) {
			tvShow = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([TRBTVShow class])
												   inManagedObjectContext:self.managedObjectContext];
		}
		[tvShow setupWithXML:seriesXML];
		[xmls removeObjectAtIndex:0];
		for (TRBXMLElement * episodeXML in xmls) {
			entity = [NSEntityDescription entityForName:NSStringFromClass([TRBTVShowEpisode class])
								 inManagedObjectContext:self.managedObjectContext];
			request = [[NSFetchRequest alloc] init];
			[request setEntity:entity];
			predicate = [NSPredicate predicateWithFormat:@"episodeID = %@ OR (seriesID = %@ AND seasonNumber = %@ AND episodeNumber = %@)",
						 episodeXML.episodeID, episodeXML.seriesID, episodeXML.seasonNumber, episodeXML.episodeNumber];
			[request setPredicate:predicate];
			[request setReturnsDistinctResults:YES];
			[request setFetchLimit:1];
			error = nil;
			array = [self.managedObjectContext executeFetchRequest:request error:&error];
			LogCE(error, [error localizedDescription]);
			TRBTVShowEpisode * episode = [array lastObject];
			if (!episode) {
				episode = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([TRBTVShowEpisode class])
														inManagedObjectContext:self.managedObjectContext];
			}
			[episode setupWithXML:episodeXML];

			entity = [NSEntityDescription entityForName:NSStringFromClass([TRBTVShowSeason class])
								 inManagedObjectContext:self.managedObjectContext];
			request = [[NSFetchRequest alloc] init];
			[request setEntity:entity];
			predicate = [NSPredicate predicateWithFormat:@"seriesID = %@ AND number = %@", tvShow.seriesID, episode.seasonNumber];
			[request setPredicate:predicate];
			[request setReturnsDistinctResults:YES];
			[request setFetchLimit:1];
			error = nil;
			array = [self.managedObjectContext executeFetchRequest:request error:&error];
			TRBTVShowSeason * season = [array lastObject];
			LogCE(error, [error localizedDescription]);
			if (!season) {
				season = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([TRBTVShowSeason class])
													   inManagedObjectContext:self.managedObjectContext];
				season.number = episode.seasonNumber;
				season.series = tvShow;
				season.seriesID = tvShow.seriesID;
				[season addEpisodesObject:episode];
				[tvShow addSeasonsObject:season];
			}
			episode.season = season;
			[season addEpisodesObject:episode];
		}
		error = nil;
		[self.managedObjectContext save:&error];
		LogCE(error, [error localizedDescription]);
		if (handler) {
			NSManagedObjectID * moID = tvShow.objectID;
			dispatch_async(dispatch_get_main_queue(), ^{
				handler((TRBTVShow *)[self.managedObjectContextMain objectWithID:moID]);
			});
		}
	}];
}

- (void)fetchAllTVShowsWithHandler:(void(^)(NSArray * results))handler {
	NSEntityDescription * entityDescription = [NSEntityDescription entityForName:NSStringFromClass([TRBTVShow class])
														  inManagedObjectContext:self.managedObjectContext];
	NSFetchRequest * request = [[NSFetchRequest alloc] init];
	[request setEntity:entityDescription];
	[request setReturnsDistinctResults:YES];
	[request setResultType:NSManagedObjectIDResultType];
	[self.managedObjectContext performBlock:^{
		NSError * error = nil;
		NSArray * array = [self.managedObjectContext executeFetchRequest:request error:&error];
		LogCE(error, [error localizedDescription]);
		dispatch_async(dispatch_get_main_queue(), ^{
			NSMutableArray * results = [NSMutableArray arrayWithCapacity:[array count]];
			for (NSManagedObjectID * moID in array)
				[results addObject:[self.managedObjectContextMain objectWithID:moID]];
			handler(results);
		});
	}];
}

- (void)fetchTVShowWithID:(NSUInteger)seriesID andHandler:(void(^)(TRBTVShow * tvShow))handler {
	NSEntityDescription * entityDescription = [NSEntityDescription entityForName:NSStringFromClass([TRBTVShow class])
														  inManagedObjectContext:self.managedObjectContext];
	NSFetchRequest * request = [[NSFetchRequest alloc] init];
	[request setEntity:entityDescription];
	NSPredicate * predicate = [NSPredicate predicateWithFormat:@"seriesID = %i", seriesID];
	[request setPredicate:predicate];
	[request setReturnsDistinctResults:YES];
	[request setResultType:NSManagedObjectIDResultType];
	[self.managedObjectContext performBlock:^{
		NSError * error = nil;
		NSArray * array = [self.managedObjectContext executeFetchRequest:request error:&error];
		LogCE(error, [error localizedDescription]);
		dispatch_async(dispatch_get_main_queue(), ^{
			if ([array count] == 1) {
				NSManagedObjectID * moID = [array lastObject];
				handler((TRBTVShow *)[self.managedObjectContextMain objectWithID:moID]);
			} else
				handler(nil);
		});
	}];
}

- (void)fetchTVShowCountWithHandler:(void(^)(NSUInteger count))handler {
	NSEntityDescription * entityDescription = [NSEntityDescription entityForName:NSStringFromClass([TRBTVShow class])
														  inManagedObjectContext:self.managedObjectContext];
	NSFetchRequest * request = [[NSFetchRequest alloc] init];
	[request setEntity:entityDescription];
	[request setResultType:NSCountResultType];
	[request setReturnsDistinctResults:YES];
	[self.managedObjectContext performBlock:^{
		NSError * error = nil;
		NSArray * array = [self.managedObjectContext executeFetchRequest:request error:&error];
		LogCE(error, [error localizedDescription]);
		dispatch_async(dispatch_get_main_queue(), ^{
			handler([array[0] unsignedIntegerValue]);
		});
	}];
}

- (void)fetchStaleTVShowsWithHandler:(void(^)(NSArray * results))handler {
	NSEntityDescription * entityDescription = [NSEntityDescription entityForName:NSStringFromClass([TRBTVShow class])
														  inManagedObjectContext:self.managedObjectContext];
	NSFetchRequest * request = [[NSFetchRequest alloc] init];
	[request setEntity:entityDescription];
	NSTimeInterval refreshRate = [[NSUserDefaults standardUserDefaults] doubleForKey:TRBTVShowInfoRefreshRateKey];
	if (!refreshRate)
		refreshRate = 1.0;
	NSDate * staleDate = [NSDate dateWithTimeIntervalSinceNow:(NSTimeInterval)(-kSecondsInDay * refreshRate)];
	NSPredicate * predicate = [NSPredicate predicateWithFormat:@"updated <= %@", staleDate];
	[request setPredicate:predicate];
	[request setReturnsDistinctResults:YES];
	[request setResultType:NSManagedObjectIDResultType];
	[self.managedObjectContext performBlock:^{
		NSError * error = nil;
		NSArray * array = [self.managedObjectContext executeFetchRequest:request error:&error];
		LogCE(error, [error localizedDescription]);
		dispatch_async(dispatch_get_main_queue(), ^{
			NSMutableArray * results = [NSMutableArray arrayWithCapacity:[array count]];
			for (NSManagedObjectID * moID in array)
				[results addObject:[self.managedObjectContextMain objectWithID:moID]];
			handler(results);
		});
	}];
}

- (void)searchTVShowsWithTitle:(NSString *)title andHandler:(void(^)(NSArray * results))handler {
	NSEntityDescription * entityDescription = [NSEntityDescription entityForName:NSStringFromClass([TRBTVShow class])
														  inManagedObjectContext:self.managedObjectContext];
	NSFetchRequest * request = [[NSFetchRequest alloc] init];
	[request setEntity:entityDescription];
	NSPredicate * predicate = [NSPredicate predicateWithFormat:@"title = %@", title];
	[request setPredicate:predicate];
	[request setReturnsDistinctResults:YES];
	[request setResultType:NSManagedObjectIDResultType];
	[self.managedObjectContext performBlock:^{
		NSError * error = nil;
		NSArray * array = [self.managedObjectContext executeFetchRequest:request error:&error];
		LogCE(error, [error localizedDescription]);
		dispatch_async(dispatch_get_main_queue(), ^{
			NSMutableArray * results = [NSMutableArray arrayWithCapacity:[array count]];
			for (NSManagedObjectID * moID in array)
				[results addObject:[self.managedObjectContextMain objectWithID:moID]];
			handler(results);
		});
	}];
}

- (void)removeTVShow:(TRBTVShow *)tvShow {
	NSArray * notifications = [[UIApplication sharedApplication].scheduledLocalNotifications copy];
	[notifications enumerateObjectsUsingBlock:^(UILocalNotification * note, NSUInteger idx, BOOL *stop) {
		NSNumber * seriesID = note.userInfo[@"seriesID"];
		if ([seriesID isEqualToNumber:tvShow.seriesID])
			[[UIApplication sharedApplication] cancelLocalNotification:note];
	}];
	[self.managedObjectContextMain deleteObject:tvShow];
	NSError * error = nil;
	[self.managedObjectContextMain save:&error];
	LogCE(error, [error localizedDescription]);
}

- (void)removeTVShowWithID:(NSUInteger)seriesID {
	[self fetchTVShowWithID:seriesID andHandler:^(TRBTVShow * tvShow) {
		if (tvShow)
			[self removeTVShow:tvShow];
	}];
}

#pragma mark TV Show Season

- (void)fetchTVShowSeasonForEpisode:(TRBTVShowEpisode *)episode forTVShow:(TRBTVShow *)tvShow andHandler:(void(^)(TRBTVShowSeason * season))handler {
	NSEntityDescription * entityDescription = [NSEntityDescription entityForName:NSStringFromClass([TRBTVShowSeason class])
														  inManagedObjectContext:self.managedObjectContext];
	NSFetchRequest * request = [[NSFetchRequest alloc] init];
	[request setEntity:entityDescription];
	NSPredicate * predicate = [NSPredicate predicateWithFormat:@"seriesID = %@ AND number = %@", tvShow.seriesID, episode.seasonNumber];
	[request setPredicate:predicate];
	[request setReturnsDistinctResults:YES];
	[self.managedObjectContext performBlock:^{
		NSError * error = nil;
		NSArray * array = [self.managedObjectContext executeFetchRequest:request error:&error];
		LogCE(error, [error localizedDescription]);
		if ([array count] == 1) {
			handler(array[0]);
		} else {
			TRBTVShowSeason * season = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([TRBTVShowSeason class])
																	inManagedObjectContext:self.managedObjectContext];
			season.number = episode.seasonNumber;
			season.series = tvShow;
			season.seriesID = tvShow.seriesID;
			[season addEpisodesObject:episode];
			[tvShow addSeasonsObject:season];
			handler(season);
		}
	}];
}

#pragma mark TV Show Episodes

- (void)insertNewTVShowEpisodeWithXML:(TRBXMLElement *)xml forTVShow:(TRBTVShow *)tvShow overwrite:(BOOL)overwrite andHandler:(void(^)(TRBTVShowEpisode * episode))handler {
	NSInteger episodeID = [xml[@"Episode.id"] integerValue];
	[self fetchTVShowEpisodeWithID:episodeID andHandler:^(TRBTVShowEpisode * episode) {
		if (!episode) {
			NSManagedObjectID * tvShowMoID = tvShow.objectID;
			[self.managedObjectContext performBlock:^{
				TRBTVShowEpisode * result = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([TRBTVShowEpisode class])
																		 inManagedObjectContext:self.managedObjectContext];
				[result setupWithXML:xml];
				TRBTVShow * tvShowBkrg = (TRBTVShow *)[self.managedObjectContext objectWithID:tvShowMoID];
				[self fetchTVShowSeasonForEpisode:result forTVShow:tvShowBkrg andHandler:^(TRBTVShowSeason * season) {
					result.season = season;
					[season addEpisodesObject:result];
					NSError * error = nil;
					[self.managedObjectContext save:&error];
					LogCE(error, [error localizedDescription]);
					if (handler) {
						NSManagedObjectID * moID = result.objectID;
						dispatch_async(dispatch_get_main_queue(), ^{
							handler((TRBTVShowEpisode *)[self.managedObjectContextMain objectWithID:moID]);
						});
					}
				}];
			}];
		} else if (overwrite) {
			[episode setupWithXML:xml];
			[self.managedObjectContextMain save:NULL];
			if (handler)
				handler(episode);
		} else if (handler)
			handler(nil);
	}];
}

- (void)fetchTVShowEpisodeWithID:(NSUInteger)episodeID andHandler:(void(^)(TRBTVShowEpisode * episode))handler {
	NSEntityDescription * entityDescription = [NSEntityDescription entityForName:NSStringFromClass([TRBTVShowEpisode class])
														  inManagedObjectContext:self.managedObjectContext];
	NSFetchRequest * request = [[NSFetchRequest alloc] init];
	[request setEntity:entityDescription];
	NSPredicate * predicate = [NSPredicate predicateWithFormat:@"episodeID = %i", episodeID];
	[request setPredicate:predicate];
	[request setReturnsDistinctResults:YES];
	[request setResultType:NSManagedObjectIDResultType];
	[self.managedObjectContext performBlock:^{
		NSError * error = nil;
		NSArray * array = [self.managedObjectContext executeFetchRequest:request error:&error];
		LogCE(error, [error localizedDescription]);
		dispatch_async(dispatch_get_main_queue(), ^{
			if ([array count] == 1) {
				handler((TRBTVShowEpisode *)[self.managedObjectContextMain objectWithID:array[0]]);
			} else
				handler(nil);
		});
	}];
}

- (void)fetchNextEpisodeForTVShow:(TRBTVShow *)tvShow andHandler:(void(^)(TRBTVShowEpisode * episode))handler {
	NSEntityDescription * entityDescription = [NSEntityDescription entityForName:NSStringFromClass([TRBTVShowEpisode class])
														  inManagedObjectContext:self.managedObjectContext];
	NSFetchRequest * request = [[NSFetchRequest alloc] init];
	[request setEntity:entityDescription];
	NSCalendar * calendar = [NSCalendar currentCalendar];
	NSDateComponents * comps = [calendar components:NSYearCalendarUnit|NSMonthCalendarUnit|NSDayCalendarUnit fromDate:[NSDate date]];
	NSDate * today = [calendar dateFromComponents:comps];
	NSPredicate * predicate = [NSPredicate predicateWithFormat:@"seriesID = %@ AND airDate >= %@", tvShow.seriesID, today];
	[request setPredicate:predicate];
	[request setFetchLimit:1];
	NSSortDescriptor * sortDesc1 = [NSSortDescriptor sortDescriptorWithKey:@"airDate" ascending:YES];
	NSSortDescriptor * sortDesc2 = [NSSortDescriptor sortDescriptorWithKey:@"episodeNumber" ascending:NO];
	[request setSortDescriptors:@[sortDesc1, sortDesc2]];
	[request setReturnsDistinctResults:YES];
	[request setResultType:NSManagedObjectIDResultType];
	[self.managedObjectContext performBlock:^{
		NSError * error = nil;
		NSArray * array = [self.managedObjectContext executeFetchRequest:request error:&error];
		LogCE(error, [error localizedDescription]);
		dispatch_async(dispatch_get_main_queue(), ^{
			if ([array count])
				handler((TRBTVShowEpisode *)[self.managedObjectContextMain objectWithID:array[0]]);
			else
				handler(nil);
		});
	}];
}

- (void)fetchPreviousEpisodeForTVShow:(TRBTVShow *)tvShow andHandler:(void(^)(TRBTVShowEpisode * episode))handler {
	NSEntityDescription * entityDescription = [NSEntityDescription entityForName:NSStringFromClass([TRBTVShowEpisode class])
														  inManagedObjectContext:self.managedObjectContext];
	NSFetchRequest * request = [[NSFetchRequest alloc] init];
	[request setEntity:entityDescription];
	NSCalendar * calendar = [NSCalendar currentCalendar];
	NSDateComponents * comps = [calendar components:NSYearCalendarUnit|NSMonthCalendarUnit|NSDayCalendarUnit fromDate:[NSDate date]];
	NSDate * today = [calendar dateFromComponents:comps];
	NSPredicate * predicate = [NSPredicate predicateWithFormat:@"seriesID = %@ AND airDate < %@", tvShow.seriesID, today];
	[request setPredicate:predicate];
	[request setFetchLimit:1];
	NSSortDescriptor * sortDesc1 = [NSSortDescriptor sortDescriptorWithKey:@"airDate" ascending:NO];
	NSSortDescriptor * sortDesc2 = [NSSortDescriptor sortDescriptorWithKey:@"episodeNumber" ascending:NO];
	[request setSortDescriptors:@[sortDesc1, sortDesc2]];
	[request setReturnsDistinctResults:YES];
	[request setResultType:NSManagedObjectIDResultType];
	[self.managedObjectContext performBlock:^{
		NSError * error = nil;
		NSArray * array = [self.managedObjectContext executeFetchRequest:request error:&error];
		LogCE(error, [error localizedDescription]);
		dispatch_async(dispatch_get_main_queue(), ^{
			if ([array count])
				handler((TRBTVShowEpisode *)[self.managedObjectContextMain objectWithID:array[0]]);
			else
				handler(nil);
		});
	}];
}

- (void)fetchAllNextEpisodesWithHandler:(void(^)(NSArray * results))handler {
	NSEntityDescription * entityDescription = [NSEntityDescription entityForName:NSStringFromClass([TRBTVShowEpisode class])
														  inManagedObjectContext:self.managedObjectContext];
	NSFetchRequest * request = [[NSFetchRequest alloc] init];
	[request setEntity:entityDescription];
	NSCalendar * calendar = [NSCalendar currentCalendar];
	NSDateComponents * comps = [calendar components:NSYearCalendarUnit|NSMonthCalendarUnit|NSDayCalendarUnit fromDate:[NSDate date]];
	NSDate * today = [calendar dateFromComponents:comps];
	NSPredicate * predicate = [NSPredicate predicateWithFormat:@"airDate >= %@ AND notificationScheduled = NO", today];
	[request setPredicate:predicate];
	NSSortDescriptor * sortDesc1 = [NSSortDescriptor sortDescriptorWithKey:@"airDate" ascending:YES];
	[request setSortDescriptors:@[sortDesc1]];
	[request setReturnsDistinctResults:YES];
	[request setResultType:NSManagedObjectIDResultType];
	[self.managedObjectContext performBlock:^{
		NSError * error = nil;
		NSArray * array = [self.managedObjectContext executeFetchRequest:request error:&error];
		LogCE(error, [error localizedDescription]);
		dispatch_async(dispatch_get_main_queue(), ^{
			NSMutableArray * results = [NSMutableArray arrayWithCapacity:[array count]];
			for (NSManagedObjectID * moID in array)
				[results addObject:[self.managedObjectContextMain objectWithID:moID]];
			handler(results);
		});
	}];
}

- (void)fetchAllScheduledEpisodesWithHandler:(void(^)(NSArray * results))handler {
	NSEntityDescription * entityDescription = [NSEntityDescription entityForName:NSStringFromClass([TRBTVShowEpisode class])
														  inManagedObjectContext:self.managedObjectContext];
	NSFetchRequest * request = [[NSFetchRequest alloc] init];
	[request setEntity:entityDescription];
	NSCalendar * calendar = [NSCalendar currentCalendar];
	NSDateComponents * comps = [calendar components:NSYearCalendarUnit|NSMonthCalendarUnit|NSDayCalendarUnit fromDate:[NSDate date]];
	NSDate * today = [calendar dateFromComponents:comps];
	NSPredicate * predicate = [NSPredicate predicateWithFormat:@"airDate >= %@ AND notificationScheduled = YES", today];
	[request setPredicate:predicate];
	NSSortDescriptor * sortDesc1 = [NSSortDescriptor sortDescriptorWithKey:@"airDate" ascending:YES];
	[request setSortDescriptors:@[sortDesc1]];
	[request setReturnsDistinctResults:YES];
	[request setResultType:NSManagedObjectIDResultType];
	[self.managedObjectContext performBlock:^{
		NSError * error = nil;
		NSArray * array = [self.managedObjectContext executeFetchRequest:request error:&error];
		LogCE(error, [error localizedDescription]);
		dispatch_async(dispatch_get_main_queue(), ^{
			NSMutableArray * results = [NSMutableArray arrayWithCapacity:[array count]];
			for (NSManagedObjectID * moID in array)
				[results addObject:[self.managedObjectContextMain objectWithID:moID]];
			handler(results);
		});
	}];
}

- (void)fetchEpisodesAiringFromDate:(NSDate *)fromDate toDate:(NSDate *)toDate withHandler:(void(^)(NSArray * results))handler {
	NSEntityDescription * entityDescription = [NSEntityDescription entityForName:NSStringFromClass([TRBTVShowEpisode class])
														  inManagedObjectContext:self.managedObjectContext];
	NSFetchRequest * request = [[NSFetchRequest alloc] init];
	[request setEntity:entityDescription];
	NSPredicate * predicate = [NSPredicate predicateWithFormat:@"airDate >= %@ AND airDate <= %@", fromDate, toDate];
	[request setPredicate:predicate];
	NSSortDescriptor * sortDesc1 = [NSSortDescriptor sortDescriptorWithKey:@"airDate" ascending:YES];
	[request setSortDescriptors:@[sortDesc1]];
	[request setReturnsDistinctResults:YES];
	[request setResultType:NSManagedObjectIDResultType];
	[self.managedObjectContext performBlock:^{
		NSError * error = nil;
		NSArray * array = [self.managedObjectContext executeFetchRequest:request error:&error];
		LogCE(error, [error localizedDescription]);
		dispatch_async(dispatch_get_main_queue(), ^{
			NSMutableArray * results = [NSMutableArray arrayWithCapacity:[array count]];
			for (NSManagedObjectID * moID in array)
				[results addObject:[self.managedObjectContextMain objectWithID:moID]];
			handler(results);
		});
	}];
}

#pragma mark TV Show Banners

- (void)insertNewTVShowBannerWithXML:(TRBXMLElement *)xml forTVShow:(TRBTVShow *)tvShow overwrite:(BOOL)overwrite andHandler:(void(^)(TRBTVShowBanner * banner))handler {
	NSInteger bannerID = [xml[@"Banner.id"] integerValue];
	[self fetchTVShowBannerWithID:bannerID andHandler:^(TRBTVShowBanner * banner) {
		if (!banner) {
			NSManagedObjectID * moID = tvShow.objectID;
			[self.managedObjectContext performBlock:^{
				TRBTVShowBanner * result = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([TRBTVShowBanner class])
																		 inManagedObjectContext:self.managedObjectContext];
				[result setupWithXML:xml];
				TRBTVShow * tvShowBkgr =(TRBTVShow *)[self.managedObjectContext objectWithID:moID];
				result.series = tvShowBkgr;
				result.seriesID = tvShowBkgr.seriesID;
				[tvShowBkgr addBannersObject:result];
				NSError * error = nil;
				[self.managedObjectContext save:&error];
				LogCE(error, [error localizedDescription]);
				if (handler) {
					NSManagedObjectID * moID = result.objectID;
					dispatch_async(dispatch_get_main_queue(), ^{
						handler((TRBTVShowBanner *)[self.managedObjectContextMain objectWithID:moID]);
					});
				}
			}];
		} else if (overwrite) {
			[banner setupWithXML:xml];
			[self.managedObjectContextMain save:NULL];
			if (handler)
				handler(banner);
		} else if (handler)
			handler(nil);
	}];
}

- (void)updateTVShowBannersWithRecords:(NSArray *)records forTVShow:(NSManagedObjectID *)tvShowID andHandler:(void(^)())handler {
	[self.managedObjectContext performBlock:^{
		NSError * error = nil;
		for (TRBXMLElement * bannerXML in records) {
			TRBTVShow * tvShow = (TRBTVShow *)[self.managedObjectContext objectWithID:tvShowID];
			NSInteger bannerID = [bannerXML[@"Banner.id"] integerValue];
			NSEntityDescription * entityDescription = [NSEntityDescription entityForName:NSStringFromClass([TRBTVShowBanner class])
																  inManagedObjectContext:self.managedObjectContext];
			NSFetchRequest * request = [[NSFetchRequest alloc] init];
			[request setEntity:entityDescription];
			NSPredicate * predicate = [NSPredicate predicateWithFormat:@"bannerID = %i", bannerID];
			[request setPredicate:predicate];
			[request setReturnsDistinctResults:YES];
			[request setFetchLimit:1];
			error = nil;
			NSArray * array = [self.managedObjectContext executeFetchRequest:request error:&error];
			LogCE(error, [error localizedDescription]);
			TRBTVShowBanner * banner = [array lastObject];
			if (!banner) {
				banner = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([TRBTVShowBanner class])
													   inManagedObjectContext:self.managedObjectContext];
			}
			[banner setupWithXML:bannerXML];
			banner.series = tvShow;
			banner.seriesID = tvShow.seriesID;
			[tvShow addBannersObject:banner];
		}
		error = nil;
		[self.managedObjectContext save:&error];
		LogCE(error, [error localizedDescription]);
		if (handler)
			dispatch_async(dispatch_get_main_queue(), handler);
	}];
}

- (void)fetchTVShowBannerWithID:(NSUInteger)bannerID andHandler:(void(^)(TRBTVShowBanner * banner))handler {
	NSEntityDescription * entityDescription = [NSEntityDescription entityForName:NSStringFromClass([TRBTVShowBanner class])
														  inManagedObjectContext:self.managedObjectContext];
	NSFetchRequest * request = [[NSFetchRequest alloc] init];
	[request setEntity:entityDescription];
	NSPredicate * predicate = [NSPredicate predicateWithFormat:@"bannerID = %i", bannerID];
	[request setPredicate:predicate];
	[request setReturnsDistinctResults:YES];
	[request setResultType:NSManagedObjectIDResultType];
	[self.managedObjectContext performBlock:^{
		NSError * error = nil;
		NSArray * array = [self.managedObjectContext executeFetchRequest:request error:&error];
		LogCE(error, [error localizedDescription]);
		dispatch_async(dispatch_get_main_queue(), ^{
			if ([array count] == 1) {
				handler((TRBTVShowBanner *)[self.managedObjectContextMain objectWithID:array[0]]);
			} else
				handler(nil);
		});
	}];
}

- (void)fetchTVShowBannerWithType:(TRBTVShowBannerType)type forTVShow:(TRBTVShow *)tvShow mustHaveColors:(BOOL)colors andHandler:(void(^)(NSArray * banners))handler {
	NSEntityDescription * entityDescription = [NSEntityDescription entityForName:NSStringFromClass([TRBTVShowBanner class])
														  inManagedObjectContext:self.managedObjectContext];
	NSFetchRequest * request = [[NSFetchRequest alloc] init];
	[request setEntity:entityDescription];
	NSPredicate * predicate = nil;
	if (colors)
		predicate = [NSPredicate predicateWithFormat:@"seriesID = %@ AND colors != NULL AND bannerType = %@ ", tvShow.seriesID, TRBTVShowBannerTypeStrings[type]];
	else
		predicate = [NSPredicate predicateWithFormat:@"seriesID = %@ AND bannerType = %@", tvShow.seriesID, TRBTVShowBannerTypeStrings[type]];
	[request setPredicate:predicate];
	[request setReturnsDistinctResults:YES];
	[request setResultType:NSManagedObjectIDResultType];
	[self.managedObjectContext performBlock:^{
		NSError * error = nil;
		NSArray * array = [self.managedObjectContext executeFetchRequest:request error:&error];
		LogCE(error, [error localizedDescription]);
		dispatch_async(dispatch_get_main_queue(), ^{
			NSMutableArray * results = [NSMutableArray arrayWithCapacity:[array count]];
			for (NSManagedObjectID * moID in array)
				[results addObject:[self.managedObjectContextMain objectWithID:moID]];
			handler(results);
		});
	}];
}

#pragma mark Shared

- (void)save {
	if (!saving) {
		saving = YES;
		[self.managedObjectContext performBlock:^{
			if ([self.managedObjectContext hasChanges]) {
				NSError * error = nil;
				[self.managedObjectContext save:&error];
				LogCE(error, [error localizedDescription]);

			}
			dispatch_async(dispatch_get_main_queue(), ^{
				if ([self.managedObjectContextMain hasChanges]) {
					NSError * error = nil;
					[self.managedObjectContextMain save:&error];
					LogCE(error, [error localizedDescription]);
				}
				saving = NO;
			});
		}];
	}
}

#pragma mark - Private Methods

- (void)createPersistentStoreCoordinator {
	NSString * documentsDirectory;
	NSArray * paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	if ([paths count])
		documentsDirectory = paths[0];
	NSString * storePath = [documentsDirectory stringByAppendingPathComponent:SQLiteStorageName];
	NSURL * storeUrl = [NSURL fileURLWithPath:storePath];
	if ([FileManager fileExistsAtPath:storePath] && ![self isStoreAtURLCompatibleWithModel:storeUrl]) {
		[FileManager removeItemAtPath:storePath error:NULL];
	}
	NSError * error = nil;
	if (!_persistentStoreCoordinator) {
		_persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:self.managedObjectModel];
		NSPersistentStore * store = [_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
																			  configuration:nil
																						URL:storeUrl
																					options:nil
																					  error:&error];
		LogCE(!store, [error localizedDescription]);
		if (error) {
			[FileManager removeItemAtPath:storePath error:&error];
			store = [_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
															  configuration:nil
																		URL:storeUrl
																	options:nil
																	  error:&error];
			LogCE(!store, [error localizedDescription]);
		}
	}
}

- (BOOL)isStoreAtURLCompatibleWithModel:(NSURL *)url {
	BOOL result = NO;
	NSError * error = nil;
	NSDictionary * storeMetadata = [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:NSSQLiteStoreType
																							  URL:url
																							error:&error];
	if (storeMetadata)
		result = [self.managedObjectModel isConfiguration:nil compatibleWithStoreMetadata:storeMetadata];

	return result;
}

@end
