#import "TlFlutterPlugin.h"
#import "TlImage.h"
#import "PointerEvent.h"


@implementation TlFlutterPlugin {
    NSInteger _screenWidth;
    NSInteger _screenHeight;
    CGFloat   _scale;
    CGFloat   _adjustWidth;
    CGFloat   _adjustHeight;
    NSString  *_imageFormat;
    NSString  *_lastHash;
    BOOL      _isJpgFormat;
    NSString  *_mimeType;
    int _screenOffset;
    NSMutableDictionary *_basicConfig;
    NSDictionary *_layoutConfig;
    NSDictionary *_imageAttributes;
    PointerEvent *_firstMotionEvent;
    PointerEvent *_lastMotionUpEvent;
    NSString *_lastScreen;
    long _lastDown;
}

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FlutterMethodChannel* channel = [FlutterMethodChannel
      methodChannelWithName:@"tl_flutter_plugin" binaryMessenger:[registrar messenger]];
  TlFlutterPlugin* instance = [[TlFlutterPlugin alloc] init];
  [registrar addMethodCallDelegate:instance channel:channel];
}

- (id) init {
    self = [super init];
    _screenWidth  = -1;
    _screenHeight = -1;
    _scale   = [UIScreen mainScreen].scale;
    _fromWeb = false;
    
    [self resetScreenLoadTime];
    
    NSLog(@"Tealeaf Enabled: %@", [[TLFApplicationHelper sharedInstance] isTLFEnabled] ? @"Yes" : @"No");
    NSLog(@"Device Pixel Density (scale): %f", _scale);
    
    NSString *mainPath   = [[NSBundle mainBundle] pathForResource:@"TLFResources" ofType:@"bundle"];
    NSBundle *bundlePath = [[NSBundle alloc] initWithPath:mainPath];
    NSString *filePath   = [bundlePath pathForResource:@"TealeafBasicConfig" ofType:@"plist"];
    _basicConfig         = [NSMutableDictionary dictionaryWithContentsOfFile:filePath];
    _layoutConfig        = [self getLayoutConfig];
    
    _lastHash            = @"";
    _imageFormat         = [self getBasicConfig][@"ScreenshotFormat"];
    _isJpgFormat         = [_imageFormat caseInsensitiveCompare:@"JPG"] == NSOrderedSame ||
                           [_imageFormat caseInsensitiveCompare:@"JPEG"] == NSOrderedSame;
    _mimeType            = _isJpgFormat ? @"jpg" : @"png";
    
    _imageAttributes     = @{
                            @"format":      _imageFormat,
                            @"isJpg":       @(_isJpgFormat),
                            @"scale":       @(_scale),
                            @"@mimeType":   (_isJpgFormat ? @"jpg" : @"png"),
                            @"%screenSize": @([_basicConfig[@"PercentOfScreenshotsSize"] floatValue]),
                            @"%compress":   @([_basicConfig[@"PercentToCompressImage"] floatValue] / 100.0)
                            };
    
    _lastDown            = 0L;
    _lastScreen          = @"";
    
    return self;
}

-(int) getOrientation {
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;

    return (orientation == UIInterfaceOrientationLandscapeLeft) || (orientation == UIInterfaceOrientationLandscapeRight)
        ? 1 : 0;
}

-(void) resetScreenLoadTime {
    _screenLoadTime = [NSDate timeIntervalSinceReferenceDate];
}

- (NSNumber *) convertNSStringToNSNumber:(NSString *) stringNumber {
    NSNumber *number = [[[NSNumberFormatter alloc]init] numberFromString:stringNumber];
    return number;
}

- (long) checkParameterStringAsInteger:(NSDictionary *) map withKey:(NSString *) key {
    NSString *stringInteger = (NSString *) [self checkForParameter:map withKey:key];
    return [[self convertNSStringToNSNumber:stringInteger] longValue];
}

-(NSTimeInterval) getScreenViewOffset {
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    return (_screenOffset = (now - _screenLoadTime) * 1000);
}

- (NSDictionary *) getAdvancedConfig {
    NSString *mainPath   = [[NSBundle mainBundle] pathForResource:@"TLFResources" ofType:@"bundle"];
    NSBundle *bundlePath = [[NSBundle alloc] initWithPath:mainPath];
    NSString *filePath   = [bundlePath pathForResource:@"TealeafAdvancedConfig" ofType:@"json"];
    NSLog(@"Tealeaf Advanced Config file: %@", filePath);
    NSData   *data       = [NSData dataWithContentsOfFile:filePath];
    return [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
}

- (NSDictionary *) getLayoutConfig {
    NSString *mainPath   = [[NSBundle mainBundle] pathForResource:@"TLFResources" ofType:@"bundle"];
    NSBundle *bundlePath = [[NSBundle alloc] initWithPath:mainPath];
    NSString *filePath   = [bundlePath pathForResource:@"TealeafLayoutConfig" ofType:@"json"];
    NSLog(@"Tealeaf Layout Config file: %@", filePath);
    NSData   *data       = [NSData dataWithContentsOfFile:filePath];
    return [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
}

- (NSMutableDictionary *) getBasicConfig {
    return _basicConfig;
}

- (NSString *) getBuildNumber {
    NSString * build = [[NSBundle mainBundle] objectForInfoDictionaryKey: (NSString *)kCFBundleVersionKey];
    return build;
}

- (NSString *) getBasicLayoutConfigurationString {
    NSDictionary *autoLayout = _layoutConfig[@"AutoLayout"];
    //NSDictionary *globalScreenSettings = autoLayout[@"GlobalScreenSettings"];
    //return [self getJSONString:globalScreenSettings];
    return [self getJSONString:autoLayout];
}

- (NSString *) getGlobalConfigurationString {
    return [self getJSONString:_basicConfig];
}

- (NSString *) getJSONString: (NSObject *) obj {
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:obj
                                            options:NSJSONWritingPrettyPrinted // Pass 0 if you don't care
                                            error:&error];
    if (!jsonData) {
        NSLog(@"JSON conversion error: %@", error);
        return @"";
    }
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    return jsonString;
}

- (NSObject *) checkForParameter:(NSDictionary *) map withKey:(NSString*) key withSubKey:(NSString *) subKey {
    NSObject *object = map[key];
    
    NSLog(@"Checking for primary key parameter %@, description: %@", key, [object description]);
    
    if (object == nil) {
        NSString *msg    = [NSString stringWithFormat:@"Parameter (Primary key) %@ not found in %@", key, map.description];
        NSString *reason = [NSString stringWithFormat:@"Flutter iOS native method call error: %@", msg];
        
        NSLog(@"%@", msg);
        
        NSException* parameterException = [NSException
            exceptionWithName:@"ParameterError"
            reason: reason
            userInfo:nil];
        @throw parameterException;
    }
    
    return [self checkForParameter:(NSDictionary *) object withKey:subKey];
}

- (NSObject *) checkForParameter:(NSDictionary *) map withKey:(NSString*) key {
    NSObject *object = map[key];
    
    NSLog(@"Checking for parameter %@, description: %@", key, [object description]);
    
    if (object == nil) {
        NSString *msg    = [NSString stringWithFormat:@"Parameter %@ not found in %@", key, map.description];
        NSString *reason = [NSString stringWithFormat:@"Flutter iOS native method call error: %@", msg];
        
        NSLog(@"%@", msg);
        
        NSException* parameterException = [NSException
            exceptionWithName:@"ParameterError"
            reason: reason
            userInfo:nil];
        @throw parameterException;
    }
    return object;
}

- (void) alternateCustomEvent:(NSString *) name addData:(NSDictionary *) data {
    NSDictionary *customEventData = @{@"customData": @{@"name": name, @"data": data}};
    
    [self tlLogMessage:customEventData addType: @5];
}

- (PointerEvent *) getPointerEvent:(NSDictionary *) map {
    NSString *event  = (NSString *) [self checkForParameter:map withKey:@"action"];
    CGFloat  dx = [(NSNumber *)[self checkForParameter:map withKey:@"position" withSubKey:@"dx"] floatValue];
    CGFloat  dy = [(NSNumber *)[self checkForParameter:map withKey:@"position" withSubKey:@"dy"] floatValue];
    float    pressure = (float) [(NSNumber *) [self checkForParameter:map withKey:@"pressure"] floatValue];
    int      device = (int) [(NSNumber *) [self checkForParameter:map withKey:@"kind"] intValue];
    NSString *tsString = (NSString *) [self checkForParameter:map withKey:@"timestamp"];
    long     timestamp = [[self convertNSStringToNSNumber:tsString] longValue];
    long     downTime  = timestamp - (_lastDown == 0L ? timestamp : _lastDown);
    
    PointerEvent *pe = [[PointerEvent alloc] initWith:event andX:dx andY:dy andTs:tsString andDown:downTime andPressure:pressure andKind:device];
    
    if (_firstMotionEvent == nil) {
        _firstMotionEvent = pe;
    }
    if ([event isEqualToString:@"DOWN"]) {
        _lastDown = timestamp;
    }
    else if ([event isEqualToString:@"UP"]) {
        _lastMotionUpEvent = pe;
    }
    return pe;
}

- (UIImage *) maskImageWithObjects: (UIImage *) bgImage withObjects: (NSArray *) maskObjects {
    CGFloat  fontScale = 0.72f;
    UIImage  *maskedUIImage = nil;
    CGSize   bgImageSize = bgImage.size;
    UIColor  *textColor  = [UIColor redColor]
    ;
    if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)]) {
        UIGraphicsBeginImageContextWithOptions(bgImageSize, NO, _scale);
    }
    else {
        UIGraphicsBeginImageContext(bgImageSize);
    }
    [bgImage drawInRect:CGRectMake(0, 0, bgImageSize.width, bgImageSize.height)];
    [[UIColor lightGrayColor] set];
    for (int i = 0; i < [maskObjects count]; i++) {
        NSDictionary *atts = maskObjects[i];
        NSString *text = (NSString *) atts[@"text"];
        NSDictionary *position = (NSDictionary *) atts[@"position"];
        CGFloat x = [position[@"x"] floatValue];
        CGFloat y = [position[@"y"] floatValue];
        CGFloat width = [position[@"width"] floatValue];
        CGFloat height = [position[@"height"] floatValue];
        CGRect  rect = CGRectMake(x, y, width, height);
       
        CGContextFillRect(UIGraphicsGetCurrentContext(), rect);
    
        NSArray *lines = [text componentsSeparatedByString:@"\n"];
        CGFloat lineCount = [lines count];
        CGFloat lineHeight = (float) round(height / lineCount);
        UIFont  *font = [UIFont systemFontOfSize:(lineHeight * fontScale)];
        NSDictionary *attrs = @{NSForegroundColorAttributeName: textColor, NSFontAttributeName: font};
        CGFloat yOffset = (float) round(lineHeight * (1 - fontScale) / 2);
        CGFloat xOffset = 2; // TBD: Should we try to center horizontally?
        
        rect.origin.x += xOffset;
        rect.origin.y += yOffset;
        
        for (int row = 0; row < [lines count]; row++) {
            [((NSString *) lines[row]) drawInRect:CGRectIntegral(rect) withAttributes: attrs];
            rect.origin.y += lineHeight;
        }
    }
    maskedUIImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return maskedUIImage;
}

- (UIImage *) takeScreenShot {
    UIImage *screenImage = nil;
    UIViewController *rootController = [UIApplication sharedApplication].keyWindow.rootViewController;
    
    if (rootController && [rootController respondsToSelector:@selector(view)])
    {
        UIView *view = rootController.view;
                    
        if (view) {
            CGSize size = view.bounds.size;
            
            if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)]) {
                UIGraphicsBeginImageContextWithOptions(size, NO, _scale);
            }
            else {
                UIGraphicsBeginImageContext(size);
            }
            if ([view drawViewHierarchyInRect:view.frame afterScreenUpdates:NO])
            {
               screenImage = UIGraphicsGetImageFromCurrentImageContext();
            }
            //[view.layer renderInContext:UIGraphicsGetCurrentContext()];
            //screenImage = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            NSLog(@"Screen shot size: %@, scale: %f", [screenImage description], _scale);
        }
    }
    
    return screenImage;
}

- (NSMutableArray *) fixupLayoutEntries:(NSArray *) controls returnMaskArray: (NSMutableArray *) maskItems {
    NSMutableArray *newControls = [controls mutableCopy];
    
    @try {
        for (int i = 0; i < [newControls count]; i++) {
            NSObject *entry = newControls[i];
        
            if ([entry isKindOfClass:[NSDictionary class]]) {
                NSMutableDictionary *newEntry = [((NSDictionary *) entry) mutableCopy];
 
                NSString *isMasked = newEntry[@"masked"];
                
                if (isMasked != nil && [isMasked isEqualToString:@"true"]) {
                    NSDictionary *position = (NSDictionary *) newEntry[@"position"];
                
                    if (position != nil) {
                        NSDictionary *currentState = (NSDictionary *) newEntry[@"currState"];
                        NSString *text = @"";
                        
                        if (currentState != nil) {
                            NSString *currentStateText = currentState[@"text"];
                            if (currentStateText != nil) {
                                text = currentStateText;
                            }
                        }
                        [maskItems addObject:@{@"position": position, @"text": text}];
                    }
                }
                
                NSDictionary *image = newEntry[@"image"];
            
                if (image != nil) {
                    NSMutableDictionary *newImage = [image mutableCopy];
                    TlImage *tlImage = nil;
                
                    // Note: The incoming data is RAW byte data and needs to be converted to base64
                    FlutterStandardTypedData *rawData = (FlutterStandardTypedData *) image[@"base64Image"];
                    int imageWidth = [newImage[@"width"] intValue];
                    int imageHeight = [newImage[@"height"] intValue];
                    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
                    CGSize size = CGSizeMake(imageWidth, imageHeight);
                        
                    CGContextRef bitmapContext = CGBitmapContextCreate(
                        (void *) [rawData.data bytes],
                        imageWidth,
                        imageHeight,
                        8,              // bitsPerComponent
                        4*imageWidth,   // bytesPerRow
                        colorSpace,
                        kCGImageAlphaNoneSkipLast);

                    CFRelease(colorSpace);

                    CGImageRef cgImage = CGBitmapContextCreateImage(bitmapContext);
                        
                    if (cgImage != nil) {
                        UIImage *uiImage = [[UIImage alloc] initWithCGImage:cgImage];
                        if (uiImage != nil) {
                            tlImage = [[TlImage alloc] initWithImage:uiImage andSize:size andConfig:_imageAttributes];
                        }
                    }
                
                    if (tlImage != nil) {
                        newImage[@"mimeExtension"] = [tlImage getMimeType];
                        newImage[@"base64Image"] = [tlImage getBase64String];
                        newImage[@"value"] = [tlImage getHash];
            
                        newEntry[@"image"] = newImage;
                    }
                }
                newControls[i] = newEntry;
            }
        }
    }
    @catch (NSException *exception) {
        NSLog(@"Controls fixup caused an exception: %@", [exception reason]);
    }

    return newControls;
}

- (void) tlScreenviewAndLayout:(NSString *) screenViewType addRef:(NSString *) referrer addLayouts:(NSArray *) layouts addTimestamp: (NSString *) timestamp {
    if (referrer == nil) {
        referrer = @"none";
    }
    UIImage *maskedScreenshot = nil;
    UIImage *screenshot       = [self takeScreenShot];
    
    NSMutableArray *maskObjects = [@[] mutableCopy];
    NSArray *updatedLayouts = [self fixupLayoutEntries:layouts returnMaskArray:maskObjects];
    
    if ([maskObjects count] > 0 && screenshot != nil) {
        maskedScreenshot = [self maskImageWithObjects:screenshot withObjects:maskObjects];
    }
    if (screenshot == nil) {
        screenshot = [UIImage imageNamed:@""];
    }
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    TlImage *tlImage  = [[TlImage alloc] initWithImage:screenshot andSize:screenSize andConfig:_basicConfig];
    
    if (maskedScreenshot != nil) {
        [tlImage updateWithImage:maskedScreenshot];
    }
    
    NSString *originalHash = [tlImage getOriginalHash];
    
    if ([_lastHash isEqualToString:originalHash]) {
        NSLog(@"Not logging screenview as unmasked screen has not updated, hash: %@", originalHash);
        return;
    }
    _lastHash = originalHash;
    
    NSString *hash = tlImage == nil ? @"" : [tlImage getHash];
    NSString *base64ImageString = tlImage == nil ? @"" : [tlImage getBase64String];
    NSString *screenName = [NSString stringWithFormat:@"FlutterViewController: %@", timestamp];
    
    NSMutableDictionary *screenContext = [@{
        @"screenview":@{
            @"type": screenViewType,
            @"name": screenName,
            @"class": screenName,
            @"referrer": referrer
        }
    } mutableCopy];
    /*
    if ([base64ImageString length] > 0) {
        screenContext[@"base64Representation"] = base64ImageString;
    }
    */
    [self tlLogMessage:screenContext addType: @2];
    
    _lastScreen = base64ImageString;
    
    // Now add the layout data
    NSString *name = [NSString stringWithFormat:@"FlutterWidgetLayout-%@", hash];
    int      orientation = [self getOrientation];
    int      width = round(_screenWidth / _scale);
    int      height = round(_screenHeight / _scale);
    //NSMutableArray *maskItems = [NSMutableArray alloc];
    //NSArray *updatedLayouts = [self fixupLayoutEntries:layouts returnMaskArray:maskItems];
    
    NSMutableDictionary *layout = [@{
        @"layout": @{
            @"name": name,
            @"class": name,
            @"controls": updatedLayouts   // aka controls
        },
        @"version": @"1.0",
        @"orientation": @(orientation),
        @"deviceWidth": @(width),
        @"deviceHeight": @(height),
    } mutableCopy];
    
    if ([base64ImageString length] > 0) {
        layout[@"backgroundImage"] = @{
            @"base64Image": base64ImageString,
            @"type": @"image",
            @"mimeExtension": _mimeType,
            //@"height": @(height),
            //@"width": @(width),
            @"value": hash
        };
    }

    [self tlLogMessage:layout addType: @10];
}

- (void) tlSetEnvironment: (NSDictionary *) args {
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    NSNumber *width = (NSNumber *) [self checkForParameter:args withKey:@"screenw"];
    NSNumber *height = (NSNumber *) [self checkForParameter:args withKey:@"screenh"];
    
    _screenWidth  = [(NSNumber *) width integerValue];
    _screenHeight = [(NSNumber *) height integerValue];
    _adjustWidth  = _screenWidth / screenSize.width;
    _adjustHeight = _screenHeight / screenSize.height;
    
    NSLog(@"Flutter screen dimensions, width: %@, height: %@", [width description], [height description]);
}

- (void) tlException: (NSDictionary *) args {
    NSString *name = (NSString *) [self checkForParameter:args withKey:@"name"];
    NSString *message = (NSString *) [self checkForParameter:args withKey:@"message"];
    NSString *stackTrace = (NSString *) [self checkForParameter:args withKey:@"stacktrace"];
    BOOL handled = [(NSNumber *) [self checkForParameter:args withKey:@"handled"] boolValue];
    
    NSDictionary *exceptionMessage = @{
        @"exception": @{
            @"name":        name,
            @"description": message,
            @"unhandled":   @(!handled),
            @"stacktrace":  stackTrace
        }
    };
    
    [self tlLogMessage:exceptionMessage addType:@6];
}

- (void) tlConnection: (NSDictionary *) args {
    NSString *url = (NSString *)[self checkForParameter:args withKey:@"url"];
    int statusCode = (int) [self checkParameterStringAsInteger:args withKey:@"statusCode"];
    long responseDataSize = (int) [self checkParameterStringAsInteger:args withKey:@"responseDataSize"];
    long initTime = [self checkParameterStringAsInteger:args withKey:@"initTime"];
    long loadTime = [self checkParameterStringAsInteger:args withKey:@"loadTime"];
    long responseTime = [self checkParameterStringAsInteger:args withKey:@"responseTime"];
    NSString *description = (NSString *) [self checkForParameter:args withKey:@"description"];
    
    // TBD: logLevel check?
    NSDictionary *connectionMessage = @{
        @"connection": @{
            @"url":              url,
            @"statusCode":       @(statusCode),
            @"responseDataSize": @(responseDataSize),
            @"initTime":         @(initTime),
            @"responseTime":     @(responseTime),
            @"loadTime":         @(loadTime),
            @"description":      description
        },
    };
    
    [self tlLogMessage:connectionMessage addType: @3];
}

- (void) tlCustomEvent: (NSDictionary *) args {
    NSString *eventName = (NSString *) [self checkForParameter:args withKey:@"eventname"];
    NSDictionary *data  = (NSDictionary *)[self checkForParameter:args withKey:@"data"];
    NSNumber *logLevel  = args[@"loglevel"];
    
    if (logLevel == (NSNumber *) [NSNull null]) {
        [self alternateCustomEvent:eventName addData:data];
        //[[TLFCustomEvent sharedInstance] logEvent:eventName values:data];
    }
    else {
        kTLFMonitoringLevelType level = (kTLFMonitoringLevelType) [logLevel intValue];
        [[TLFCustomEvent sharedInstance] logEvent:eventName values:data level:level];
    }
}

- (void) tlLogMessage: (NSDictionary *) message addType: (NSNumber *) tlType {
    [self getScreenViewOffset];
    NSMutableDictionary *baseMessage = [@{@"fromWeb": @(_fromWeb), @"offset": @47, @"screenviewOffset": @(_screenOffset), @"type": @0} mutableCopy];
    
    baseMessage[@"type"] = tlType;
    [baseMessage addEntriesFromDictionary:message];
    
    NSString *logMessageString = [self getJSONString:baseMessage];
    
    NSLog(@"Logging Messsage: %@", logMessageString);
    
    [[TLFCustomEvent sharedInstance] logJSONMessagePayloadStr:logMessageString];
}

- (void) tlScreenview: (NSDictionary *) args {
    NSString *tlType = (NSString *) [self checkForParameter:args withKey:@"tlType"];
    NSString *timestamp = (NSString *) [self checkForParameter:args withKey:@"timeStamp"];
    NSObject *layouts   = args[@"layoutParameters"];
    
    if (layouts != nil) {
        if ([layouts isKindOfClass:[NSArray class]]) {
            NSLog(@"layoutParameters: %@", [layouts class]);
        }
        else {
            NSLog(@"Error in layout type");
            layouts = nil;
        }
    }
    /*
    TLFScreenViewType tlScreenViewType = ([tlType caseInsensitiveCompare:@"load"] == NSOrderedSame)
        ? TLFScreenViewTypeLoad
        : (([tlType caseInsensitiveCompare:@"unload"] == NSOrderedSame)
           ? TLFScreenViewTypeUnload
           : TLFScreenViewTypeVisit);
    NSString *pageName  = [NSString stringWithFormat:@"Screenview pagename: %@", timestamp];
     
    [[TLFCustomEvent sharedInstance] logScreenViewContext:pageName applicationContext:tlScreenViewType referrer:nil];
    [[TLFCustomEvent sharedInstance] logPrintScreenEvent];
    */
    [self tlScreenviewAndLayout:tlType addRef:nil addLayouts:(NSArray *)layouts addTimestamp:timestamp];
    
    /*
    NSDictionary *data = @{@"item1": @"Data1", @"item2": @"Data2"};
  
    [[TLFCustomEvent sharedInstance] logEvent:@"My test Event!" values:data level:kTLFMonitoringLevelCellularAndWiFi];
    
    NSString *testJson = @"{\
        \"fromWeb\": false,\
        \"offset\": 1249,\
        \"type\": 5,\
        \"screenviewOffset\": 1222,\
        \"customEvent\": {\
            \"name\": \"My second test Event!\",\
            \"data\": {\
                \"value\": {\
                    \"item1\": \"Data3\",\
                    \"item2\": \"Data4\"\
                }\
            }\
        }\
    }";
    [[TLFCustomEvent sharedInstance] logJSONMessagePayloadStr:testJson];
    
    [self alternateCustomEvent:@"A TEST custom event!" addData:data];
    */
    
    NSLog(@"Screenview, tlType: %@", tlType);
}

- (void) tlPointerEvent: (NSDictionary *) args {
    [self getPointerEvent:args];
}

- (void) tlGestureEvent: (NSDictionary *) args {
    NSString *tlType = (NSString *) [self checkForParameter:args withKey:@"tlType"];
    NSString *wid    = (NSString *) [self checkForParameter:args withKey:@"id"];
    NSString *target = (NSString *) [self checkForParameter:args withKey:@"target"];
    BOOL     isSwipe = [tlType isEqualToString:@"swipe"];
    BOOL     isPinch = [tlType isEqualToString:@"pinch"];
    
    CGFloat        vdx = 0, vdy = 0;
    NSString       *direction = nil;
    NSMutableArray *pointerEvents = [[NSMutableArray alloc] init];
    
    if (isPinch || isSwipe) {
        PointerEvent *pointerEvent1, *pointerEvent2;

        NSDictionary *data = (NSDictionary *) [self checkForParameter:args withKey:@"data"];
     
        CGFloat  x1   = [(NSNumber *) [self checkForParameter:data withKey:@"pointer1" withSubKey:@"dx"] floatValue];
        CGFloat  y1   = [(NSNumber *) [self checkForParameter:data withKey:@"pointer1" withSubKey:@"dy"] floatValue];
        NSString *ts1 = isPinch ? @"0" : (NSString *)[self checkForParameter:data withKey:@"pointer1" withSubKey:@"ts"];
        
        pointerEvent1 = [[PointerEvent alloc] initWith:@"DOWN" andX:x1 andY:y1 andTs:ts1 andDown:0 andPressure:0 andKind:0];
        
        CGFloat  x2   = [(NSNumber *) [self checkForParameter:data withKey:@"pointer2" withSubKey:@"dx"] floatValue];
        CGFloat  y2   = [(NSNumber *) [self checkForParameter:data withKey:@"pointer2" withSubKey:@"dy"] floatValue];
        NSString *ts2 = isPinch ? @"0" : (NSString *)[self checkForParameter:data withKey:@"pointer2" withSubKey:@"ts"];
            
        pointerEvent2 = [[PointerEvent alloc] initWith:@"DOWN" andX:x2 andY:y2 andTs:ts2 andDown:0 andPressure:0 andKind:0];
        
        vdx       = [(NSNumber *) [self checkForParameter:data withKey:@"velocity" withSubKey:@"dx"] floatValue];
        vdy       = [(NSNumber *) [self checkForParameter:data withKey:@"velocity" withSubKey:@"dy"] floatValue];
        direction = (NSString *)  [self checkForParameter:data withKey:@"direction"];
        
        int times = isPinch ? 2 : 1;
        
        for (int i = 0; i < times; i++) {
            [pointerEvents addObject:pointerEvent1];
            [pointerEvents addObject:pointerEvent2];
        }
    }
    else {
        [pointerEvents addObject:_lastMotionUpEvent];
    }
    
    NSMutableArray *touches = [[NSMutableArray alloc] init];
    NSMutableArray *touch   = nil;
    int touchCount = (int) [pointerEvents count];
    
    for (int i = 0; i < touchCount; /* inc at bottom of loop for test */) {
        PointerEvent *pointerEvent = pointerEvents[i];
        
        if (touch == nil) {
            touch = [[NSMutableArray alloc] init];
        }
        
        CGFloat x      = pointerEvent.x * _scale;
        CGFloat y      = pointerEvent.y * _scale;
        CGFloat relX   = x / _screenWidth;
        CGFloat relY   = y / _screenHeight;
        NSString *xy   = [NSString stringWithFormat:@"%f,%f", relX, relY];

        [touch addObject: @{
            @"position": @{
                @"x": @(pointerEvent.x),
                @"y": @(pointerEvent.y)
            },
            @"control":  @{
                @"position": @{
                    @"height": @(_screenHeight),
                    @"width":  @(_screenWidth),
                    @"relXY":  xy,
                },
                @"id":       wid,
                @"idType":   @(-4),
                @"type":     @"FlutterSurfaceView",
                @"subType":  @"SurfaceView",
                @"tlType":   target
            },
        }];
        // After two 'touch' entries, move to next element in touches arrays (for pinch and swipe)
        i += 1;
        if ((i % 2) == 0 || i >= touchCount) {
            [touches addObject:touch];
            touch = nil;
        }
    }
    
    NSMutableDictionary *gestureMessage =[@{
        @"event": [@{
            // TBD: Need to check: Should this mimic Android version? Verify correctness for Pinch "type"
            @"type":    isPinch ? @"onScale" : _lastMotionUpEvent.action,
            @"tlEvent": tlType
        } mutableCopy],
        @"touches": touches,
        @"base64Representation": _lastScreen
    } mutableCopy];
    
    if (direction != nil) {
        gestureMessage[@"direction"] = direction;
        gestureMessage[@"velocityX"] = @(vdx);
        gestureMessage[@"velocityY"] = @(vdy);
    }
    
    [self tlLogMessage:gestureMessage addType: @11];
    
    _lastDown = 0L;
    _lastMotionUpEvent = _firstMotionEvent = nil;
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    @try {
        if ([@"getPlatformVersion" caseInsensitiveCompare:call.method] == NSOrderedSame) {
            NSString *platformVersion = [[UIDevice currentDevice] systemVersion];
            NSLog(@"Platform Version: %@", platformVersion);
            result([@"iOS " stringByAppendingString: platformVersion]);
        }
        else if ([@"getTealeafVersion" caseInsensitiveCompare:call.method] == NSOrderedSame) {
            NSDictionary *dict = [self getAdvancedConfig];
            NSLog(@"Lib version: %@", dict[@"LibraryVersion"]);
            result(dict[@"LibraryVersion"]);
        }
        else if ([@"getTealeafSessionId" caseInsensitiveCompare:call.method] == NSOrderedSame) {
            NSString *sessionId = [[TLFApplicationHelper sharedInstance] currentSessionId];
            NSLog(@"Session ID: %@", sessionId);
            result(sessionId);
        }
        else if ([@"getAppKey" caseInsensitiveCompare:call.method] == NSOrderedSame) {
            NSMutableDictionary *dict = [self getBasicConfig];
            result(dict[@"AppKey"]);
        }
        else if ([@"setEnv" caseInsensitiveCompare:call.method] == NSOrderedSame) {
            [self tlSetEnvironment:call.arguments];
            result(nil);
        }
        else if ([@"getGlobalConfiguration" caseInsensitiveCompare:call.method] == NSOrderedSame) {
            result([self getBasicLayoutConfigurationString]);
        }
        else if ([@"pointerEvent" caseInsensitiveCompare:call.method] == NSOrderedSame) {
            [self tlPointerEvent:call.arguments];
            result(nil);
        }
        else if ([@"gesture" caseInsensitiveCompare:call.method] == NSOrderedSame) {
            [self tlGestureEvent:call.arguments];
            result(nil);
        }
        else if ([@"screenView" caseInsensitiveCompare:call.method] == NSOrderedSame) {
            [self tlScreenview:call.arguments];
            result(nil);
        }
        else if ([@"exception" caseInsensitiveCompare:call.method] == NSOrderedSame) {
            [self tlException:call.arguments];
            result(nil);
        }
        else if ([@"connection" caseInsensitiveCompare:call.method] == NSOrderedSame) {
            [self tlConnection:call.arguments];
            result(nil);
        }
        else if ([@"customEvent" caseInsensitiveCompare:call.method] == NSOrderedSame) {
            [self tlCustomEvent:call.arguments];
            result(nil);
        }
        else {
            result(FlutterMethodNotImplemented);
        }
    }
    @catch (NSException *exception) {
        NSLog(@"Exception in methodcall, request: %@, name: %@, reason: %@", call.method, exception.name, exception.reason);
        
        NSArray *stackTrace = exception.callStackSymbols;
        NSString *stackTraceAsString = [stackTrace componentsJoinedByString:@"\n"];
        
        result([FlutterError errorWithCode:exception.name message:exception.reason details:stackTraceAsString]);
    }
    @finally {
        NSLog(@"MethodChannel handler, method: %@, args: %@", call.method, [call.arguments description]);
    }
}

@end
