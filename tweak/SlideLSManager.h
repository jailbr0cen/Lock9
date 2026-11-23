// SlideLSManager.h
// Derived from SixLS by Skitty (GPLv3).

#import <Foundation/Foundation.h>
#import "Headers/CoverSheet/CSScrollView.h"

@interface SlideLSManager : NSObject

@property (nonatomic, retain) CSScrollView *csScrollView;

+ (instancetype)sharedInstance;
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, copy) NSString *slideText;
@property (nonatomic, copy) NSString *textColorHex;
@property (nonatomic, assign) CGFloat textSize;
@property (nonatomic, assign) BOOL showCamera;

@property (nonatomic, assign) id coverSheetViewController;

- (void)openCameraWithCompletion:(void (^)(void))completion;
- (void)unlock;

@end
