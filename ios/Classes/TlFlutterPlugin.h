#import <Flutter/Flutter.h>
#import <Tealeaf/Tealeaf.h>

@interface TlFlutterPlugin : NSObject<FlutterPlugin>

@property (nonatomic) BOOL fromWeb;
@property (nonatomic) int  screenLoadTime;

@end
