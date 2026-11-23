@interface CSCoverSheetViewController : UIViewController
@property (nonatomic, retain) CSCoverSheetView *view;
@property (nonatomic, getter=isAuthenticated) BOOL authenticated;
- (void)layoutSlide;
- (void)activateCameraViewAnimated:(BOOL)animated sendingActions:(id)actions completion:(void (^)(void))completion;
@end
