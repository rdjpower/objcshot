#include "delegate.h"
#include "preferences.h"
#include "util.h"
#include "shortcut.h"
#include <objc/runtime.h>
#include <objc/message.h>
#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

@implementation ObjCShotDelegate

- (void)applicationWillTerminate:(NSNotification *)notification {
  activeKeyDeinit();
  activeInactiveKeyDeinit();
  [state.defaults setObject:state.screenshot_location.absoluteString
                     forKey:@"ScreenshotURL"];
  [state.screenshot_location release];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
  @autoreleasepool {
  do_init();
  activeKeyInit();
  activeInactiveKeyInit();

  self.bar = [[NSStatusBar systemStatusBar]
      statusItemWithLength:NSVariableStatusItemLength];

  if (!@available(macOS 10.12, *)) {
      [self.bar setTitle:@"objcshot"];
  } else {
      self.bar.button.title = @"objcshot";
  }

  id NSMenuClass = objc_getClass("NSMenu");
  SEL alloc_sel = sel_registerName("alloc");

  NSMenu *menu = (NSMenu *)(((id (*)(id, SEL))objc_msgSend)(NSMenuClass, alloc_sel));
  menu = [[menu init] autorelease];

  [menu addItemWithTitle:@"About"
                  action:@selector(aboutWindow:)
           keyEquivalent:@""];
  [menu addItemWithTitle:@"View Screenshot Shortcuts"
                  action:@selector(shortcuts:)
           keyEquivalent:@""];
  [menu addItemWithTitle:@"Open Screenshot Folder"
                  action:@selector(open:)
           keyEquivalent:@"o"];
  [menu addItemWithTitle:@"Set Screenshot Folder"
                  action:@selector(setscrfolder:)
           keyEquivalent:@""];
  [menu addItemWithTitle:@"Quit"
                  action:@selector(quitApp:)
           keyEquivalent:@"q"];

  self.bar.menu = menu;
  }
}

- (void)aboutWindow:(id)sender {
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    [[NSApplication sharedApplication] orderFrontStandardAboutPanel:NULL];
}

- (void)windowWillClose:(NSNotification *)notification {
  if (notification.object != self.shortwnd)
    return;
  self.shortwnd = NULL;
}

- (void)shortcuts:(id)sender {
    if (self.shortwnd)
      return;
    self.shortwnd = shortcutWindow();
    self.shortwnd.delegate = self;
}

- (void)setscrfolder:(id)sender {
  @autoreleasepool {
    resolveLocation();

    id NSOpenPanelClass = objc_getClass("NSOpenPanel");
    SEL alloc_sel = sel_registerName("alloc");

    NSOpenPanel *panel = (NSOpenPanel *)(((id (*)(id, SEL))objc_msgSend)(NSOpenPanelClass, alloc_sel));
    panel = [[panel init] autorelease];

    panel.title = @"Set Screenshot Folder";
    panel.allowsMultipleSelection = NO;
    panel.canChooseDirectories = YES;
    panel.canCreateDirectories = YES;
    panel.canChooseFiles = NO;
    panel.directoryURL = state.screenshot_location;

    [panel runModal];

    if (panel.URL != NULL) {
        [state.screenshot_location release];
        state.screenshot_location = [panel.URL copy];
    }
  }
}

- (void)open:(id)sender {
    resolveLocation();
    [[NSWorkspace sharedWorkspace] openURL:state.screenshot_location];
}

- (void)quitApp:(id)sender {
    [[NSApplication sharedApplication] terminate:NULL];
}

@end

void activeScreenshot() {
  CGWindowID winId = getActiveWindow();
  NSString* name = getWindowName(winId, @"_0");

  NSImage *screenshot = screenshotWindow(winId);
  if (screenshot == NULL)
    return;

  savePNG(name, screenshot);
}

void activeInactiveScreenshot() {
  CGWindowID winId = getActiveWindow();

  NSString *name1 = getWindowName(winId, @"_b1");
  NSString *name2 = getWindowName(winId, @"_b2");

  NSImage *screenshot1 = screenshotWindow(winId);
  if (screenshot1 == NULL)
    return;

  savePNG(name1, screenshot1);

  [NSApp activateIgnoringOtherApps:YES];
  [NSThread sleepForTimeInterval:0.2];

  NSImage *screenshot2 = screenshotWindow(winId);
  if (screenshot2 == NULL)
    return;

  savePNG(name2, screenshot2);
  reactivateApp(winId);
}
