#import <Playing/libplaying.h>
#import <Cephei/HBPreferences.h>
#import <MediaRemote/MediaRemote.h>

@interface SBMediaController : NSObject
-(void)setNowPlayingInfo:(id)arg1;
@end

static HBPreferences *preferences = NULL;
static NSString *previousTitle = @"";

BOOL enabled;
NSString *customText = @"";

void SendNotification(CFNotificationCenterRef center, void * observer, CFStringRef name, const void * object, CFDictionaryRef userInfo) {
	if([(__bridge NSString *)name isEqualToString:@"dev.hyper.playing/TestNotification"]) {
		[[PlayingNotificationHelper sharedInstance] submitTestNotification:customText];
	}
}

%hook SBMediaController

-(void)setNowPlayingInfo:(id)arg1 {
	%orig;
	if(enabled) {
		dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 1);
    	dispatch_after(delay, dispatch_get_main_queue(), ^(void){
			NSMutableDictionary *dict = [[self valueForKey:@"nowPlayingInfo"] mutableCopy]
			[dict setObject:customText forKey:@"customText"];
			[[PlayingManager sharedInstance] setMetadata:dict];
		});
	}	
}

%end

%hook BBServer
-(id)initWithQueue:(id)arg1 {
    [PlayingNotificationHelper sharedInstance].bbServer = %orig;
    return [PlayingNotificationHelper sharedInstance].bbServer;
}

-(id)initWithQueue:(id)arg1 dataProviderManager:(id)arg2 syncService:(id)arg3 dismissalSyncCache:(id)arg4 observerListener:(id)arg5 utilitiesListener:(id)arg6 conduitListener:(id)arg7 systemStateListener:(id)arg8 settingsListener:(id)arg9 {
    [PlayingNotificationHelper sharedInstance].bbServer = %orig;
    return [PlayingNotificationHelper sharedInstance].bbServer;
}

- (void)dealloc {
  if ([PlayingNotificationHelper sharedInstance].bbServer == self) {
    [PlayingNotificationHelper sharedInstance].bbServer = NULL;
  }

  %orig;
}
%end


static void UpdatePlayingPreferences() {
	preferences = [[HBPreferences alloc] initWithIdentifier:@"dev.hyper.playing.prefs"];
    [preferences registerDefaults:@{
        @"enabled": @YES,
		@"customText": @""
    }];

    [preferences registerBool:&enabled default:NO forKey:@"enabled"];
	[preferences registerObject:&customText default:@"" forKey:@"customText"];
}

%ctor {
	UpdatePlayingPreferences();
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)UpdatePlayingPreferences, CFSTR("dev.hyper.playing/ReloadPrefs"), NULL, kNilOptions);
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)SendNotification, CFSTR("dev.hyper.playing/TestNotification"), NULL, kNilOptions);
}

