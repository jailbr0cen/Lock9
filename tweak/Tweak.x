// Lock9: iOS 7-9 style "slide to unlock" for rootless iOS 15.
//
// Based on SixLS by Skitty (GPLv3), with the slide-to-unlock look from
// NineUnlock by Minh Ton (MIT, see LICENSE-NineUnlock-MIT).

#import <UIKit/UIKit.h>
#import <AudioToolbox/AudioServices.h>
#import <CoverSheet/CoverSheet.h>
#import "Headers/SpringBoard/SpringBoard.h"
#import "Lock9Manager.h"
#import "Lock9-Swift.h"

#define LOCK9_PATH(p) @"/var/jb/Library/Application Support/Lock9/" p

static BOOL isLocked = YES;
static BOOL enabled = YES;
static BOOL lockSoundOn = YES;
static BOOL unlockSoundOn = YES;
#define ACTIVE (enabled && isLocked)

static NSMutableArray *objectsToUpdate;
static CSMainPageContentViewController *mainPageController;

static void playSound(NSString *file) {
	SystemSoundID sound = 0;
	AudioServicesCreateSystemSoundID((CFURLRef) CFBridgingRetain([NSURL fileURLWithPath:file]), &sound);
	AudioServicesPlaySystemSound(sound);
}

static void setIsLocked(BOOL locked);

static void refreshPrefs() {
	CFPreferencesAppSynchronize(CFSTR("local.lock9"));
	NSDictionary *d = nil;
	CFArrayRef keys = CFPreferencesCopyKeyList(CFSTR("local.lock9"), kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
	if (keys) {
		d = (NSDictionary *)CFBridgingRelease(CFPreferencesCopyMultiple(keys, CFSTR("local.lock9"), kCFPreferencesCurrentUser, kCFPreferencesAnyHost));
		CFRelease(keys);
	}
	BOOL wasEnabled = enabled;
	enabled = [(d[@"enabled"] ?: @YES) boolValue];
	lockSoundOn = [(d[@"lockSound"] ?: @YES) boolValue];
	unlockSoundOn = [(d[@"unlockSound"] ?: @YES) boolValue];
	NSString *text = d[@"slideText"];
	Lock9Manager *mgr = [Lock9Manager sharedInstance];
	mgr.enabled = enabled;
	mgr.slideText = text.length ? text : @"slide to unlock";
	mgr.textColorHex = [d[@"textColor"] length] ? d[@"textColor"] : @"#FFFFFF";
	mgr.textSize = d[@"textSize"] ? [d[@"textSize"] doubleValue] : 24.0;
	mgr.showCamera = [(d[@"showCamera"] ?: @YES) boolValue];
	dispatch_async(dispatch_get_main_queue(), ^{
		[[NSNotificationCenter defaultCenter] postNotificationName:@"Lock9PrefsChanged" object:nil];
		if (wasEnabled != enabled) setIsLocked(isLocked);
	});
}

static void prefsChangedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
	refreshPrefs();
}

static void setIsLocked(BOOL locked) {
	isLocked = locked;
	for (NSObject *object in objectsToUpdate) {
		if ([object respondsToSelector:@selector(layoutSlide)]) {
			[(CSMainPageContentViewController *)object layoutSlide];
		}
	}
}

// Add the slide view to the main lock screen page
%hook CSMainPageContentViewController
%property (nonatomic, retain) LockScreenView *sixView;

- (void)viewDidLoad {
	%orig;

	CSMainPageContentViewController *telf = self;
	mainPageController = self;

	telf.sixView = [[LockScreenView alloc] initWithFrame:telf.view.bounds];
	telf.sixView.translatesAutoresizingMaskIntoConstraints = NO;
	[telf.view addSubview:telf.sixView];
	[telf.sixView.widthAnchor constraintEqualToAnchor:telf.view.widthAnchor].active = YES;
	[telf.sixView.heightAnchor constraintEqualToAnchor:telf.view.heightAnchor].active = YES;

	if (!objectsToUpdate) objectsToUpdate = [NSMutableArray new];
	[objectsToUpdate addObject:self];
	[self layoutSlide];
}

- (void)viewWillAppear:(BOOL)animated {
	%orig;
	[self layoutSlide];
}

%new
- (void)layoutSlide {
	CSMainPageContentViewController *telf = self;
	if (telf.sixView) {
		[telf.view bringSubviewToFront:telf.sixView];
		if (ACTIVE) {
			[telf.sixView present];
			telf.sixView.hidden = NO;
		} else {
			telf.sixView.hidden = YES;
		}
	}
}

%end

// Lock sound (iOS 9 style)
%hook SBSleepWakeHardwareButtonInteraction

- (void)_playLockSound {
	if (enabled && lockSoundOn) {
		playSound(LOCK9_PATH(@"lock.caf"));
	} else {
		%orig;
	}
}

%end

// Re-show the slide view after the passcode screen goes away (Cancel)
%hook CSPasscodeViewController

- (void)viewWillDisappear:(BOOL)arg1 {
	%orig;
	[mainPageController.sixView presentAnimated];
}

%end

// Unlock sound
%hook SBLockScreenManager

- (void)lockScreenViewControllerRequestsUnlock {
	if (enabled && unlockSoundOn) playSound(LOCK9_PATH(@"unlock.caf"));
	%orig;
}

%end

// Disable page scrolling while locked: no widgets page, no camera page
%hook CSCoverSheetViewController

- (void)viewDidLoad {
	%orig;
	if (!objectsToUpdate) objectsToUpdate = [NSMutableArray new];
	[objectsToUpdate addObject:self];
	[self layoutSlide];
}

- (void)viewWillAppear:(BOOL)arg1 {
	%orig;
	CSCoverSheetViewController *telf = self;
	setIsLocked(!telf.authenticated);
}

%new
- (void)layoutSlide {
	CSCoverSheetViewController *telf = self;
	[Lock9Manager sharedInstance].csScrollView = telf.view.scrollView;
	[Lock9Manager sharedInstance].coverSheetViewController = telf;
	telf.view.scrollView.scrollEnabled = !ACTIVE;
	if (ACTIVE) [telf.view.scrollView scrollToPageAtIndex:0 animated:NO withCompletion:nil];

	// hide camera / flashlight quick actions
	UIView *quickActions = [telf.view respondsToSelector:@selector(quickActionsView)] ? [telf.view valueForKey:@"quickActionsView"] : nil;
	quickActions.hidden = ACTIVE;
}

%end

// Hide the footer ("Press home to unlock", page dots, home bar)
%hook CSFixedFooterViewController

- (void)viewDidLoad {
	%orig;
	if (!objectsToUpdate) objectsToUpdate = [NSMutableArray new];
	[objectsToUpdate addObject:self];
	[self layoutSlide];
}

%new
- (void)layoutSlide {
	CSFixedFooterViewController *telf = self;
	telf.view.hidden = ACTIVE;
}

%end

%hook CSTeachableMomentsContainerViewController

- (void)viewDidLoad {
	%orig;
	if (!objectsToUpdate) objectsToUpdate = [NSMutableArray new];
	[objectsToUpdate addObject:self];
	[self layoutSlide];
}

%new
- (void)layoutSlide {
	CSTeachableMomentsContainerViewController *telf = self;
	telf.view.hidden = ACTIVE;
}

%end

// Blank the "Press home to unlock" label
%hook SBUICallToActionLabel

- (void)setText:(id)arg1 forLanguage:(id)arg2 animated:(bool)arg3 {
	%orig(enabled ? @"" : arg1, arg2, arg3);
}

%end

static void displayStatusChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
	setIsLocked(YES);
}

%ctor {
	objectsToUpdate = [NSMutableArray new];
	refreshPrefs();
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, prefsChangedCallback, CFSTR("local.lock9/prefschanged"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, displayStatusChanged, CFSTR("com.apple.iokit.hid.displayStatus"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
	%init;
}
