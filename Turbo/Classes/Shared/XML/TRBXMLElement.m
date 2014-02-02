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

#import "TRBXMLElement.h"
#import <libxml/tree.h>

static NSString * const TRBPathSeparator = @".";
static NSString * const TRBXMLExtension = @".xml";

@interface TRBXMLParser : NSObject

@property (nonatomic, strong) NSError * error;

+ (TRBXMLElement *)parse:(NSData *)data error:(NSError **)error;
- (void)parse:(NSData *)data;
- (TRBXMLElement *)end;

@end

@interface _TRBXMLElement : TRBXMLElement
@end

@interface _TRBXMLLeaf : TRBXMLElement
@end

@interface _TRBXMLEmpty : TRBXMLElement
@end

@interface _TRBXMLList : TRBXMLElement
@end

@interface TRBXMLElement ()

@property (atomic, strong, readwrite) NSString * name;
@property (nonatomic, weak, readonly) NSMutableArray * mutableChildren;
@property (nonatomic, weak, readwrite) TRBXMLElement * parent;

+ (TRBXMLElement *)XMLElement;
+ (TRBXMLElement *)XMLElementWithName:(NSString *)name andAttributes:(NSDictionary *)attributes;
+ (TRBXMLElement *)XMLElementWithElement:(TRBXMLElement *)element;
- (instancetype)initWithName:(NSString *)name andAttributes:(NSDictionary *)attr;

- (void)setAttributes:(const char **)attributes count:(NSUInteger)count;
- (void)setTextFromData:(NSData *)text;
- (void)makeImmutable;

@end

typedef NS_ENUM(NSUInteger, TRBXMLElementMask) {
	TRBXMLElementMaskHasText = 1 << 0,
	TRBXMLElementMaskHasChildren = 1 << 1,
	TRBXMLElementMaskHasAttributes = 1 << 2,
};

@implementation TRBXMLElement

@dynamic text;
@dynamic attributes;
@dynamic mutableChildren;
@dynamic children;

#pragma mark - Class Methods

+ (TRBXMLElement *)XMLElement {
	return [self XMLElementWithName:nil andAttributes:nil];
}

+ (TRBXMLElement *)XMLElementWithName:(NSString *)name andAttributes:(NSDictionary *)attributes {
	return [[_TRBXMLElement alloc] initWithName:name andAttributes:attributes];
}

+ (TRBXMLElement *)XMLElementWithElement:(TRBXMLElement *)element {
	TRBXMLElement * result = element;
	TRBXMLElementMask mask = 0;
	mask |= [element.text length] > 0 ? TRBXMLElementMaskHasText : 0;
	mask |= [element.children count] > 0 ? TRBXMLElementMaskHasChildren : 0;
	mask |= [element.attributes count] > 0 ? TRBXMLElementMaskHasAttributes : 0;
	switch (mask) {
		case TRBXMLElementMaskHasText:
			result = [[_TRBXMLLeaf alloc] initWithElement:element];
			break;
		case TRBXMLElementMaskHasChildren:
			result = [[_TRBXMLList alloc] initWithElement:element];
			break;
		case TRBXMLElementMaskHasAttributes:
			result = [[_TRBXMLEmpty alloc] initWithElement:element];
			break;
		default:
			break;
	}
	return result;
}

+ (TRBXMLElement *)XMLElementWithContentsOfFile:(NSString *)path {
	TRBXMLElement * result = nil;
	NSData * xmlData = [NSData dataWithContentsOfFile:path];
	if ([xmlData length])
		result = [TRBXMLParser parse:xmlData error:NULL];
	return result;
}

+ (TRBXMLElement *)XMLElementWithData:(NSData *)data error:(NSError **)error {
	TRBXMLElement * result = nil;
	if ([data length])
		result = [TRBXMLParser parse:data error:error];
	return result;
}

#pragma mark - Initialization

- (instancetype)initWithName:(NSString *)name andAttributes:(NSDictionary *)attr {
    self = [super init];
	if ([self isMemberOfClass:[TRBXMLElement class]])
		self = [[self class] XMLElementWithName:name andAttributes:attr];
	else if (self) {
		_name = name;
		_parent = nil;
	}
	return self;
}

- (instancetype)initWithElement:(TRBXMLElement *)element {
	self = [super init];
	if (self) {
		_name = element.name;
		_parent = element.parent;
	}
	return self;
}

- (void)dealloc {
	_parent = nil;
}

#pragma mark - Custom Getters

- (NSMutableArray *)mutableChildren {
	NSMutableArray * result = nil;
	if ([self.children isKindOfClass:[NSMutableArray class]])
		result = (NSMutableArray *)self.children;
	return result;
}

#pragma mark - Public Interface

- (TRBXMLElement *)elementAtPath:(NSString *)path {
	TRBXMLElement * result = nil;
	NSArray * pathComponents = [path componentsSeparatedByString:TRBPathSeparator];
	NSUInteger count = [pathComponents count];
	NSUInteger current = 0;
	NSString * first = pathComponents[current];
	if ([first length] == 0 || [first isEqualToString:self.name])
		current++;
	if (current < count) {
		TRBXMLElement * match = nil;
		do {
			for (TRBXMLElement * element in self.children) {
				if ([element.name isEqualToString:pathComponents[current]]) {
					match = element;
					break;
				}
			}
			current++;
		} while (match && current < count);
		result = match;
	}
	return result;
}

- (NSArray *)elementsAtPath:(NSString *)path {
	NSArray * result = nil;
	NSArray * pathComponents = [path componentsSeparatedByString:TRBPathSeparator];
	NSUInteger count = [pathComponents count];
	NSUInteger current = 0;
	NSString * first = pathComponents[current];
	if ([first length] == 0 || [first isEqualToString:self.name])
		current++;
	if (current < count) {
		NSArray * matches = @[self];
		do {
			NSPredicate * predicate = [NSPredicate predicateWithBlock:^BOOL(TRBXMLElement * element, NSDictionary * bindings) {
				return [element.name isEqualToString:pathComponents[current]];
			}];
			NSMutableArray * tmp = [NSMutableArray new];
			for (TRBXMLElement * element in matches)
				[tmp addObjectsFromArray:[element.children filteredArrayUsingPredicate:predicate]];
			matches = tmp;
			current++;
		} while ([matches count] && current < count);
		result = [matches copy];
	}
	return result;
}

- (id)objectAtIndexedSubscript:(NSUInteger)idx {
	TRBXMLElement * result = nil;
	if (idx < [self.children count])
		result = self.children[idx];
	return result;
}

- (id)objectForKeyedSubscript:(id)key {
	id result = nil;
	if ([key isKindOfClass:[NSString class]])
		result = [[self elementAtPath:(NSString *)key] text];
	return result;
}

#pragma mark - Project Methods

- (void)setAttributes:(const char **)attributes count:(NSUInteger)count {
	[NSException raise:@"Method not implemented" format:@"%@ needs to be implemented by a concrete subclass", NSStringFromSelector(_cmd)];
}

- (void)setTextFromData:(NSData *)text {
	[NSException raise:@"Method not implemented" format:@"%@ needs to be implemented by a concrete subclass", NSStringFromSelector(_cmd)];
}

- (void)makeImmutable {
	[NSException raise:@"Method not implemented" format:@"%@ needs to be implemented by a concrete subclass", NSStringFromSelector(_cmd)];
}

#pragma mark - Private Methods

- (void)addChild:(TRBXMLElement *)element {
	[NSException raise:@"Method not implemented" format:@"%@ needs to be implemented by a concrete subclass", NSStringFromSelector(_cmd)];
}

@end

@implementation _TRBXMLElement

@synthesize text = _text;
@synthesize attributes = _attributes;
@synthesize children = _children;

#pragma mark - Initialization

- (instancetype)initWithName:(NSString *)name andAttributes:(NSDictionary *)attr {
    self = [super initWithName:name andAttributes:attr];
	if (self) {
		_attributes = [attr count] ? attr : nil;
		_text = nil;
		_children = nil;
	}
	return self;
}

- (instancetype)initWithElement:(TRBXMLElement *)element {
	self = [super initWithElement:element];
	if (self) {
		_attributes = element.attributes;
		_text = element.text;
		_children = element.children;
		[_children makeObjectsPerformSelector:@selector(setParent:) withObject:self];
	}
	return self;
}

#pragma mark - TRBXMLElement Overrides

- (void)setAttributes:(const char **)attributes count:(NSUInteger)count {
	if (count) {
		NSMutableDictionary * mutableAttributes = [[NSMutableDictionary alloc] initWithCapacity:count];
		for (NSUInteger i = 0; i < count; i++, attributes += 5) {
			NSString * key = [[NSString alloc] initWithCString:attributes[0] encoding:NSUTF8StringEncoding];
			NSString * val = [[NSString alloc] initWithBytes:(const void *)attributes[3] length:(attributes[4] - attributes[3]) encoding:NSUTF8StringEncoding];
			[mutableAttributes setValue:[val stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] forKey:key];
		}
		_attributes = [mutableAttributes copy];
	}
}

- (void)setTextFromData:(NSData *)text {
	if ([text length]) {
		NSString * tmp = [[NSString alloc] initWithBytes:[text bytes] length:[text length] encoding:NSUTF8StringEncoding];
		_text = [tmp stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	}
}

- (void)makeImmutable {
	if (![_text length])
		_text = nil;
	if ([_children isKindOfClass:[NSMutableArray class]] && [self.children count])
		_children = [_children copy];
	else if (![self.children count])
		_children = nil;
}

- (void)addChild:(TRBXMLElement *)element {
	if (!self.mutableChildren)
		_children = [[NSMutableArray alloc] init];
	[self.mutableChildren addObject:element];
}

@end

@implementation _TRBXMLLeaf

@synthesize text = _text;

- (instancetype)initWithElement:(TRBXMLElement *)element {
	self = [super initWithElement:element];
	if (self) {
		_text = element.text;
	}
	return self;
}

#pragma mark - Dynamic Properties

- (NSArray *)children {
	return nil;
}

- (NSDictionary *)attributes {
	return nil;
}

#pragma mark - TRBXMLElement Overrides

- (void)setTextFromData:(NSData *)text {
	if ([text length]) {
		NSString * tmp = [[NSString alloc] initWithBytes:[text bytes] length:[text length] encoding:NSUTF8StringEncoding];
		_text = [tmp stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	}
}

- (void)makeImmutable {
	if (![_text length])
		_text = nil;
}

@end

@implementation _TRBXMLEmpty

@synthesize attributes = _attributes;

- (instancetype)initWithName:(NSString *)name andAttributes:(NSDictionary *)attr {
    self = [super initWithName:name andAttributes:attr];
	if (self) {
		_attributes = [attr count] ? attr : nil;
	}
	return self;
}

- (instancetype)initWithElement:(TRBXMLElement *)element {
	self = [super initWithElement:element];
	if (self) {
		_attributes = element.attributes;
	}
	return self;
}

#pragma mark - Dynamic Properties

- (NSString *)text {
	return @"";
}

- (NSArray *)children {
	return nil;
}

#pragma mark - TRBXMLElement Overrides

- (void)setAttributes:(const char **)attributes count:(NSUInteger)count {
	if (count) {
		NSMutableDictionary * mutableAttributes = [[NSMutableDictionary alloc] initWithCapacity:count];
		for (NSUInteger i = 0; i < count; i++, attributes += 5) {
			NSString * key = [[NSString alloc] initWithCString:attributes[0] encoding:NSUTF8StringEncoding];
			NSString * val = [[NSString alloc] initWithBytes:(const void *)attributes[3] length:(attributes[4] - attributes[3]) encoding:NSUTF8StringEncoding];
			[mutableAttributes setValue:[val stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] forKey:key];
		}
		_attributes = [mutableAttributes copy];
	}
}

- (void)makeImmutable {
}

@end

@implementation _TRBXMLList

@synthesize children = _children;

#pragma mark - Initialization

- (instancetype)initWithElement:(TRBXMLElement *)element {
	self = [super initWithElement:element];
	if (self) {
		_children = element.children;
		[_children enumerateObjectsUsingBlock:^(TRBXMLElement * element, NSUInteger idx, BOOL *stop) {
			element.parent = self;
		}];
	}
	return self;
}

#pragma mark - Dynamic Properties

- (NSString *)text {
	return @"";
}

- (NSDictionary *)attributes {
	return nil;
}

#pragma mark - TRBXMLElement Overrides

- (void)makeImmutable {
	if ([_children isKindOfClass:[NSMutableArray class]] && [_children count])
		_children = [self.children copy];
	else if (![_children count])
		_children = nil;
}

- (void)addChild:(TRBXMLElement *)element {
	if (!self.mutableChildren)
		_children = [[NSMutableArray alloc] init];
	[self.mutableChildren addObject:element];
}

@end

static void SAXStartElement(void * ctx, const xmlChar * localname, const xmlChar * prefix, const xmlChar * URI, int nb_namespaces, const xmlChar ** namespaces, int nb_attributes, int nb_defaulted, const xmlChar ** attributes);
static void	SAXEndElement(void * ctx, const xmlChar * localname, const xmlChar * prefix, const xmlChar * URI);
static void	SAXCharactersFound(void * ctx, const xmlChar * ch, int len);
static void SAXErrorEncountered(void * ctx, const char * msg, ...);

static xmlSAXHandler SAXHandlerStruct;

@implementation TRBXMLParser {
@package
	xmlParserCtxtPtr _context;
	TRBXMLElement * _root;
	TRBXMLElement * _current;
	NSMutableData * _chars;
	NSMutableSet * _nameSet;
	NSMutableSet * _parentSet;
}

+ (TRBXMLElement *)parse:(NSData *)data error:(NSError **)error {
	TRBXMLParser * parser = [self new];
	[parser parse:data];
	TRBXMLElement * result = [parser end];
	NSError * parserError = parser.error;
	if (error)
		*error = parserError;
	return parserError ? nil : result;
}

#pragma mark - Initialization

- (instancetype)init {
    self = [super init];
    if (self) {
        _context = xmlCreatePushParserCtxt(&SAXHandlerStruct, (__bridge void *)(self), NULL, 0, NULL);
		_root = nil;
		_current = nil;
		_chars = [[NSMutableData alloc] init];
		_nameSet = [[NSMutableSet alloc] init];
		_parentSet = [[NSMutableSet alloc] init];
    }
    return self;
}

- (void)dealloc {
	xmlFreeParserCtxt(_context);
}

#pragma mark - Public Methods

- (void)parse:(NSData *)data {
	@autoreleasepool {
		xmlParseChunk(_context, (const char *)[data bytes], (int)[data length], 0);
	}
}

- (TRBXMLElement *)end {
	xmlParseChunk(_context, NULL, 0, 1);
	return _root;
}

@end

#pragma mark - LibXML SAX Callbacks

static void SAXStartElement(void * ctx, const xmlChar * localname, const xmlChar * prefix, const xmlChar * URI, int nb_namespaces, const xmlChar ** namespaces, int nb_attributes, int nb_defaulted, const xmlChar ** attributes) {
	TRBXMLParser * parser = (__bridge TRBXMLParser *)ctx;
	TRBXMLElement * current = [TRBXMLElement XMLElement];
	if (!parser->_root) {
		parser->_root = current;
		parser->_current = current;
	} else {
		if (parser->_current)
			[parser->_parentSet addObject:parser->_current];
		current.parent = parser->_current;
		parser->_current = current;
	}
	NSString * name = @((const char *)localname);
	NSString * usedName = [parser->_nameSet member:name];
	if (usedName)
		name = usedName;
	else
		[parser->_nameSet addObject:name];
	[current setName:name];
	[current setAttributes:(const char **)attributes count:(NSUInteger)nb_attributes];
}

static void	SAXEndElement(void * ctx, const xmlChar * localname, const xmlChar * prefix, const xmlChar * URI) {
	TRBXMLParser * parser = (__bridge TRBXMLParser *)ctx;
	[parser->_current setTextFromData:parser->_chars];
	[parser->_current makeImmutable];
	parser->_current = [TRBXMLElement XMLElementWithElement:parser->_current];
	if (parser->_current.parent)
		[parser->_current.parent addChild:parser->_current];
	[parser->_chars setLength:0];
	parser->_current = parser->_current.parent;
	if (parser->_current)
		[parser->_parentSet removeObject:parser->_current];
}

static void	SAXCharactersFound(void * ctx, const xmlChar * ch, int len) {
	TRBXMLParser * parser = (__bridge TRBXMLParser *)ctx;
	[parser->_chars appendBytes:(const void *)ch length:(NSUInteger)len];
}

static void SAXErrorEncountered(void * ctx, const char * msg, ...) {
	TRBXMLParser * parser = (__bridge TRBXMLParser *)ctx;
	va_list arguments;
	va_start(arguments, msg);
	NSString * message = [[NSString alloc] initWithFormat:@(msg) arguments:arguments];
	va_end(arguments);
	NSString * finalMessage = [NSString stringWithFormat:@"%@ error: %@", NSStringFromClass([parser class]), message];
	NSDictionary * userInfo = @{NSLocalizedDescriptionKey: finalMessage};
	NSError * error = [NSError errorWithDomain:NSStringFromClass([parser class]) code:666 userInfo:userInfo];
	parser.error = error;
}

// The handler struct has positions for a large number of callback functions. If NULL is supplied at a given position,
// that callback functionality won't be used. Refer to libxml documentation at http://www.xmlsoft.org for more information
// about the SAX callbacks.
static xmlSAXHandler SAXHandlerStruct = {
    NULL,                       /* internalSubset */
    NULL,                       /* isStandalone   */
    NULL,                       /* hasInternalSubset */
    NULL,                       /* hasExternalSubset */
    NULL,                       /* resolveEntity */
    NULL,                       /* getEntity */
    NULL,                       /* entityDecl */
    NULL,                       /* notationDecl */
    NULL,                       /* attributeDecl */
    NULL,                       /* elementDecl */
    NULL,                       /* unparsedEntityDecl */
    NULL,                       /* setDocumentLocator */
    NULL,                       /* startDocument */
    NULL,                       /* endDocument */
    NULL,                       /* startElement*/
    NULL,                       /* endElement */
    NULL,                       /* reference */
    SAXCharactersFound,         /* characters */
    NULL,                       /* ignorableWhitespace */
    NULL,                       /* processingInstruction */
    NULL,                       /* comment */
    NULL,                       /* warning */
    SAXErrorEncountered,        /* error */
    NULL,                       /* fatalError //: unused error() get all the errors */
    NULL,                       /* getParameterEntity */
    NULL,                       /* cdataBlock */
    NULL,                       /* externalSubset */
    XML_SAX2_MAGIC,             //
    NULL,
    SAXStartElement,            /* startElementNs */
    SAXEndElement,              /* endElementNs */
    NULL,                       /* serror */
};
