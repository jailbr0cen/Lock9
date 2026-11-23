// Lock9Manager.m
// Derived from SixLS by Skitty (GPLv3).

#import "Lock9Manager.h"
#import <UIKit/UIKit.h>
#import "Headers/SpringBoard/SBLockScreenManager.h"
#import "Headers/CoverSheet/CoverSheet.h"

@implementation Lock9Manager

+ (instancetype)sharedInstance {
	static Lock9Manager *sharedInstance = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedInstance = [[Lock9Manager alloc] init];
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
