#include "preferences.h"
#import <Cocoa/Cocoa.h>

#define DEFAULT_LOCATION ([@"file://" stringByAppendingString: [@"~/Pictures/" stringByExpandingTildeInPath]])
#define DEFAULT_URL [[NSURL alloc] initWithString:DEFAULT_LOCATION]

Preferences state = (Preferences){0};

void resolveLocation(void) {
  if (![state.screenshot_location checkResourceIsReachableAndReturnError:NULL]) {
    [state.screenshot_location release];
    state.screenshot_location = DEFAULT_URL;
  }
}

void loadState(void) {
  state.screenshot_location = DEFAULT_URL;
  state.defaults = [NSUserDefaults standardUserDefaults];

  NSString *screenshot_location = [state.defaults stringForKey:@"ScreenshotURL"];
  if (screenshot_location == NULL) {
      [state.defaults registerDefaults:@{
          @"ScreenshotURL": state.screenshot_location.absoluteString
      }];
  } else {
      [state.screenshot_location release];
      state.screenshot_location = [[NSURL alloc] initWithString: screenshot_location];
  }

  resolveLocation();
}
