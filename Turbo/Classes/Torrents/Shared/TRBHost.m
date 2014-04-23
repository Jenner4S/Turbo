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

#import "TRBHost.h"
#import "TRBTorrentClient.h"
#import "TKAlertCenter.h"

NSString * const TRBActiveHostListKey = @"TRBActiveHostList";
NSString * const TRBInactiveHostListKey = @"TRBInactiveHostList";

static NSString * const HTTPProtocols[HTTPProtocolCount] = {
	@"http",
	@"https",
};

#define SanitizeProtocolIndex(index) ((index) >= 0 && (index) < HTTPProtocolCount ? (index) : 0)
#define TRBProtocolAtIndex(index) HTTPProtocols[SanitizeProtocolIndex(index)]

static NSString * const TRBHostDefaultPath = @"/transmission/rpc";

static NSString * const TRBHostNameKey = @"TRBHostName";
static NSString * const TRBHostDescriptionKey = @"TRBHostDescription";
static NSString * const TRBHostTypeKey = @"TRBHostType";
static NSString * const TRBHostProtocolKey = @"TRBHostProtocol";
static NSString * const TRBHostDomainKey = @"TRBHostDomain";
static NSString * const TRBHostPortKey = @"TRBHostPort";
static NSString * const TRBHostPathKey = @"TRBHostPath";

@implementation TRBHost {
	NSURLAuthenticationChallenge * _challenge;
}

#pragma mark - Initialization

- (id)init {
    self = [super init];
    if (self) {
        _protocol = HTTPProtocolHTTP;
		_domain = nil;
		_port = -1;
		_path = @"";
		_name = @"";
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
		_name = [coder decodeObjectForKey:TRBHostNameKey];
		_desc = [coder decodeObjectForKey:TRBHostDescriptionKey];
		_protocol = [coder decodeIntegerForKey:TRBHostProtocolKey];
		_domain = [coder decodeObjectForKey:TRBHostDomainKey];
		_port = [coder decodeIntegerForKey:TRBHostPortKey];
		_path = [coder decodeObjectForKey:TRBHostPathKey];
    }
    return self;
}


#pragma mark - Public Methods

- (NSURL *)URL {
	NSURLComponents * components = [NSURLComponents new];
	components.scheme = TRBProtocolAtIndex(self.protocol);
	components.host = _domain;
	if (_port > 0)
		components.port = @(_port);
	components.path = _path;
	return [components URL];
}

#pragma mark - Custom Getters

- (TRBTorrentClient *)client {
	[NSException raise:@"Method not implemented" format:@"%@ needs to be implemented by a concrete subclass", NSStringFromSelector(_cmd)];
	return nil;
}

#pragma mark - Custom Setters

- (void)setDomain:(NSString *)domain {
	if ([domain hasSuffix:@"/"])
		domain = [domain substringToIndex:([domain length] - 2)];
	_domain = domain;
	if (![_name length])
		_name = domain;
}

- (void)setPath:(NSString *)path {
	if ([path length] && ![path hasPrefix:@"/"])
		path = [@"/" stringByAppendingString:path];
	_path = path;
}

#pragma mark - NSCoding Implementation

- (void)encodeWithCoder:(NSCoder *)coder {
	[coder encodeObject:_name forKey:TRBHostNameKey];
	[coder encodeObject:_desc forKey:TRBHostDescriptionKey];
	[coder encodeInteger:_protocol forKey:TRBHostProtocolKey];
	[coder encodeObject:_domain forKey:TRBHostDomainKey];
	[coder encodeInteger:_port forKey:TRBHostPortKey];
	[coder encodeObject:_path forKey:TRBHostPathKey];
}

@end

@implementation TRBTransmissionHost {
	TRBTransmissionClient * _client;
}

- (instancetype)init {
    self = [super init];
    if (self) {
		self.path = TRBHostDefaultPath;
		self.icon = [UIImage imageNamed:@"transmission"];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
	self = [super initWithCoder:aDecoder];
	if (self) {
		self.path = TRBHostDefaultPath;
		self.icon = [UIImage imageNamed:@"transmission"];
	}
	return self;
}

- (void)setDomain:(NSString *)domain {
	if (![self.domain isEqualToString:domain]) {
		[super setDomain:domain];
		if (_client)
			_client = [[TRBTransmissionClient alloc] initWithURL:[self URL]];
	}
}

- (void)setPath:(NSString *)path {
	if (![self.path isEqualToString:path]) {
		[super setPath:path];
		if (_client)
			_client = [[TRBTransmissionClient alloc] initWithURL:[self URL]];
	}
}

- (TRBTorrentClient *)client {
	if (!_client)
		_client = [[TRBTransmissionClient alloc] initWithURL:[self URL]];
	return _client;
}

@end

@implementation TRBHostList {
	NSMutableArray * _inactiveHosts;
	NSMutableArray * _activeHosts;
}

- (id)init {
    self = [super init];
    if (self) {
		NSUserDefaults * ud = [NSUserDefaults standardUserDefaults];
		NSData * activeData = [ud dataForKey:TRBActiveHostListKey];
		if (activeData)
			_activeHosts = [NSKeyedUnarchiver unarchiveObjectWithData:activeData];
		else
			_activeHosts = [NSMutableArray new];

		NSData * inactiveData = [ud dataForKey:TRBInactiveHostListKey];
		if (inactiveData)
			_inactiveHosts = [NSKeyedUnarchiver unarchiveObjectWithData:inactiveData];
		else
			_inactiveHosts = [NSMutableArray new];
    }
    return self;
}

- (void)addHost:(TRBHost *)host {
	[_inactiveHosts addObject:host];
	[self save];
}

- (void)removeHost:(TRBHost *)host {
	[_inactiveHosts removeObject:host];
	[self save];
}

- (void)removeHostAtIndex:(NSUInteger)index {
	if (index < [_inactiveHosts count]) {
		[_inactiveHosts removeObjectAtIndex:index];
		[self save];
	}
}

- (NSUInteger)inactiveHostCount {
	return [_inactiveHosts count];
}

- (NSUInteger)activeHostCount {
	return [_activeHosts count];
}

- (TRBHost *)activeHostAtIndex:(NSInteger)index {
	return _activeHosts[index];
}

- (TRBHost *)inactiveHostAtIndex:(NSInteger)index {
	return _inactiveHosts[index];
}

- (void)activateHost:(TRBHost *)host {
	NSUInteger index = [_inactiveHosts indexOfObject:host];
	if (index != NSNotFound) {
		[_inactiveHosts removeObjectAtIndex:index];
		[_activeHosts addObject:host];
		[self save];
		[_delegate hostListDidChangeActiveHosts:self];
	}
}

- (void)deactivateHost:(TRBHost *)host {
	NSUInteger index = [_activeHosts indexOfObject:host];
	if (index != NSNotFound) {
		[_activeHosts removeObjectAtIndex:index];
		[_inactiveHosts addObject:host];
		[self save];
		[_delegate hostListDidChangeActiveHosts:self];
	}
}

- (NSArray *)activeHosts {
	return [_activeHosts copy];
}

- (NSArray *)inactiveHosts {
	return [_inactiveHosts copy];
}

- (void)save {
	NSData * activeHosts = [NSKeyedArchiver archivedDataWithRootObject:_activeHosts];
	NSData * inactiveHosts = [NSKeyedArchiver archivedDataWithRootObject:_inactiveHosts];
	NSUserDefaults * ud = [NSUserDefaults standardUserDefaults];
	[ud setObject:activeHosts forKey:TRBActiveHostListKey];
	[ud setObject:inactiveHosts forKey:TRBInactiveHostListKey];
	[ud synchronize];
}

@end
