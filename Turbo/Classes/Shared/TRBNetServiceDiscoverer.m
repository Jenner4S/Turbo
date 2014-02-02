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

#import "TRBNetServiceDiscoverer.h"
#import "TRBHTTPSession.h"

@interface TRBNetServiceDiscoverer ()<NSNetServiceBrowserDelegate, NSNetServiceDelegate>

@end

@implementation TRBNetServiceDiscoverer {
	TRBHTTPSession * _session;
	NSNetServiceBrowser * _serviceBrowser;
	NSMutableArray * _toResolve;
	NSMutableArray * _resolved;
	NSNetService * _active;
	BOOL _notifyUpdate;
}

- (id)init {
    self = [super init];
    if (self) {
		_session.acceptedHTTPStatusCodes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(200, 100)];
		_serviceBrowser = [[NSNetServiceBrowser alloc] init];
		_serviceBrowser.delegate = self;
		_toResolve = [NSMutableArray new];
		_resolved = [NSMutableArray new];
    }
    return self;
}

- (void)dealloc {
    for (NSNetService * service in _toResolve) {
		if (service.delegate == self)
			service.delegate = nil;
	}
}

#pragma mark - Public Methods

- (void)startServiceSearch {
	[_serviceBrowser searchForServicesOfType:@"_http._tcp." inDomain:@"local."];
}

- (void)stopServiceSearch {
	[_serviceBrowser stop];
}

#pragma mark - NSNetServiceBrowserDelegate Implementation

- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser didFindDomain:(NSString *)domainName moreComing:(BOOL)moreDomainsComing {
	LogV(@"found domain: %@ more coming: %i", domainName, moreDomainsComing);
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser didFindService:(NSNetService *)netService moreComing:(BOOL)moreServicesComing {
	LogV(@"found service: %@ more coming: %i", netService, moreServicesComing);
	LogV(@"Service name: %@", netService.name);
	LogV(@"Service type: %@", netService.type);
	LogV(@"Service domain: %@", netService.domain);
	if ([_delegate netServiceDiscoverer:self shouldResolveService:netService]) {
		[_toResolve addObject:netService];
		[netService setDelegate:self];
	}
	if (!moreServicesComing) {
		for (NSNetService * service in _toResolve)
			[service resolveWithTimeout:10.0];
	}
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser didRemoveService:(NSNetService *)netService moreComing:(BOOL)moreServicesComing {
	netService.delegate = nil;
	NSUInteger index = [_toResolve indexOfObject:netService];
	if (index != NSNotFound)
		[_toResolve removeObjectAtIndex:index];
	else if ((index = [_resolved indexOfObject:netService]) != NSNotFound) {
		_notifyUpdate = YES;
		[_resolved removeObjectAtIndex:index];
	}
	if (!moreServicesComing && _notifyUpdate) {
		_notifyUpdate = NO;
		[_delegate netServiceDiscoverer:self didUpdateServiceList:[_resolved copy]];
	}
}

#pragma mark - NSNetServiceDelegate Implementation

- (void)netServiceDidResolveAddress:(NSNetService *)sender {
	LogV(@"Resolved: %@", sender);
	LogV(@"Host name: %@", sender.hostName);
	LogV(@"Port: %i", sender.port);
	sender.delegate = nil;
	[_toResolve removeObject:sender];
	if ([_delegate netServiceDiscoverer:self shouldKeepResolvedService:sender]) {
		_notifyUpdate = YES;
		[_resolved addObject:sender];
	}
	if (![_toResolve count] && _notifyUpdate) {
		_notifyUpdate = NO;
		[_delegate netServiceDiscoverer:self didUpdateServiceList:[_resolved copy]];
	}
}

- (void)netService:(NSNetService *)sender didNotResolve:(NSDictionary *)errorDict {
	sender.delegate = nil;
	[_toResolve removeObject:sender];
}

@end
