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

@interface NSString (TRBUnits)
+ (NSString *)stringWithByteCount:(long long)size;
+ (NSString *)stringWithTransferRate:(long long)rate;
+ (NSString *)stringWithDate:(NSDate *)date andOutputStyle:(NSDateFormatterStyle)style;
+ (NSString *)stringWithDate:(NSDate *)date dateOutputStyle:(NSDateFormatterStyle)style1 andTimeOutputStyle:(NSDateFormatterStyle)style2;
- (NSDate *)dateFromInputFormat:(NSString *)format;
- (NSDate *)dateFromInputFormat:(NSString *)format withLocale:(NSLocale *)locale;
- (NSDate *)dateFromInputFormat:(NSString *)format withLocale:(NSLocale *)locale andTimezone:(NSTimeZone *)timezone;
- (NSString *)dateStringFromInputFormat:(NSString *)format andOutputStyle:(NSDateFormatterStyle)style;
- (NSString *)dateStringFromInputFormat:(NSString *)format outputStyle:(NSDateFormatterStyle)style inLocale:(NSLocale *)inLocale andOutLocale:(NSLocale *)outLocale;
- (NSString *)shortDateFromInputFormat:(NSString *)format;
@end
