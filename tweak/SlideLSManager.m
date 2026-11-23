// SlideLSManager.m
// Derived from SixLS by Skitty (GPLv3).

#import "SlideLSManager.h"
#import <UIKit/UIKit.h>
#import "Headers/SpringBoard/SBLockScreenManager.h"
#import "Headers/CoverSheet/CoverSheet.h"

@implementation SlideLSManager

+ (instancetype)sharedInstance {
	static SlideLSManager *sharedInstance = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedInstance = [[SlideLSManager alloc] init];
	});
	return sharedInstance;
}

- (void)unlock {
	[[NSClassFromString(@"SBLockScreenManager") sharedInstance] lockScreenViewControllerRequestsUnlock];
}

- (void)openCameraWithCompletion:(void (^)(void))completion {
	// a real animated scroll to the camera page, so the cover sheet runs its normal
	// page-change flow and actually starts the camera app
	self.csScrollView.scrollEnabled = YES;
	[self.csScrollView scrollToPageAtIndex:1 animated:YES withCompletion:^{
		if (completion) completion();
	}];
}

@end
