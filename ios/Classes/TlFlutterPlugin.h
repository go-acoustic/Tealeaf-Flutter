#import <Flutter/Flutter.h>
#import <Tealeaf/Tealeaf.h>
//#import <Tealeaf/TLFUIEventsLogger.h>

@interface TlFlutterPlugin : NSObject<FlutterPlugin>

@property (nonatomic) BOOL fromWeb;
@property (nonatomic) int  screenLoadTime;

@end
