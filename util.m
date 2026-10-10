#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <Cocoa/Cocoa.h>
#import <ScreenCaptureKit/ScreenCaptureKit.h>
#include <CoreMedia/CoreMedia.h>
#include <objc/runtime.h>
#include <objc/message.h>
#include <dlfcn.h>
#include "preferences.h"

NSWindow *_Nonnull shortcutWindow(void) {
  NSRect rect = NSMakeRect(0, 0, 300, 150);

  id NSWindowClass = objc_getClass("NSWindow");
  SEL alloc_sel = sel_registerName("alloc");
  NSWindow *win = (NSWindow *)(((id (*)(id, SEL))objc_msgSend)(NSWindowClass, alloc_sel));
  win = [win autorelease];

  win =
      [[NSWindow alloc] initWithContentRect:rect
                                  styleMask:NSWindowStyleMaskClosable |
                                            NSWindowStyleMaskMiniaturizable |
                                            NSWindowStyleMaskResizable |
                                            NSWindowStyleMaskTitled
                                    backing:NSBackingStoreBuffered
                                      defer:NO];
  win.releasedWhenClosed = YES;
  win.title = @"Shortcuts";
  win.minSize = rect.size;

  NSTextField *field = [NSTextField labelWithString:@"Screenshot: ⌘+B\nScreenshot with inactive: ⌘+⇧+B"];
  field.alignment = NSTextAlignmentCenter;

  [win.contentView addSubview:field];
  field.translatesAutoresizingMaskIntoConstraints = NO;

  [NSLayoutConstraint activateConstraints:@[
    [field.centerXAnchor constraintEqualToAnchor:win.contentView.centerXAnchor],
    [field.centerYAnchor constraintEqualToAnchor:win.contentView.centerYAnchor]
  ]];

  [NSApp activateIgnoringOtherApps:YES];
  [win center];
  [win makeKeyAndOrderFront:NULL];

  return win;
}

NSString *_Nonnull getWindowName(CGWindowID wId, NSString*_Nonnull identifier) {
    CFArrayRef windowList =
        CGWindowListCopyWindowInfo(kCGWindowListOptionIncludingWindow, wId);
    NSArray *nsArrayWindowList = (__bridge NSArray *)windowList;
    NSString* name = @"Window";

    for (NSDictionary *w in nsArrayWindowList) {
      if ([[w objectForKey:(id)kCGWindowNumber] unsignedIntValue] != wId)
        continue;
      name = (__bridge NSString *)[w objectForKey:(id)kCGWindowName];
      break;
    }

    name = [name stringByReplacingOccurrencesOfString:@"/" withString:@""];
    name = [[NSString stringWithFormat:@"%u_", wId] stringByAppendingString:name];
    name = [name stringByAppendingString:identifier];
    name = [name stringByAppendingString:@".png"];

    CFRelease(windowList);
    return name;
}

NSData *_Nonnull getScreenshotPNG(NSImage *_Nonnull img) {
    NSData *data = [img TIFFRepresentation];
    NSBitmapImageRep *rep = [NSBitmapImageRep imageRepWithData:data];

    return [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
}

void savePNG(NSString *_Nonnull name, NSImage *_Nonnull screenshot) {
    NSURL *saveTo = [state.screenshot_location URLByAppendingPathComponent:name];
    NSError *error = NULL;

    NSData* pngData = getScreenshotPNG(screenshot);
    BOOL success = [pngData writeToURL:saveTo options:NSDataWritingAtomic error:&error];

    if (!success || error != NULL) {
      [[NSAlert alertWithError:error] runModal];
      return;
    }
}

CGWindowID getActiveWindow(void) {
  CGWindowID result = 0;

  CFArrayRef _win = CGWindowListCopyWindowInfo(
      kCGWindowListExcludeDesktopElements | kCGWindowListOptionOnScreenOnly,
      kCGNullWindowID);
  NSArray* windows = (__bridge NSArray*)_win;

  NSRunningApplication *frontMostApp = [[[[NSWorkspace sharedWorkspace]
      runningApplications]
      filteredArrayUsingPredicate:[NSPredicate
                                      predicateWithFormat:@"active == YES"]] objectAtIndex:0];
  pid_t process = [frontMostApp processIdentifier];

  for (NSDictionary *info in windows) {
    pid_t winpId = [[info objectForKey:(id)kCGWindowOwnerPID] intValue];
    if (process != winpId)
      continue;

    result = (CGWindowID)[[info objectForKey:(id)kCGWindowNumber] unsignedIntValue];
    break;
  }

  CFRelease(windows);
  return result;
}

NSImage *_Nullable screenshotWindowSequoia(CGWindowID wId) {
  if (@available(macOS 15.0.0, *)) {
      dispatch_semaphore_t waitForImageSemaphor = dispatch_semaphore_create(0);
      __block NSImage *_Nullable final = NULL;

      #define DO_DISPATCH(semaphor) (dispatch_semaphore_signal(semaphor))

      void (^handler)(SCShareableContent *, NSError *) =
          ^(SCShareableContent *shareableContent, NSError *error) {
              @autoreleasepool {
              if (!shareableContent || error) {
                  DO_DISPATCH(waitForImageSemaphor);
                  return;
              }

              SCWindow *win = NULL;
              for (SCWindow *w in shareableContent.windows) {
                  if (w.windowID != wId)
                      continue;
                  win = w;
                  break;
              }

              if (!win) {
                  DO_DISPATCH(waitForImageSemaphor);
                  return;
              }

              SCContentFilter *filter = [[[SCContentFilter alloc]
                  initWithDesktopIndependentWindow:win] autorelease];
              SCStreamConfiguration *config =
                  [[[SCStreamConfiguration alloc] init] autorelease];

              config.showsCursor = NO;
              config.ignoreShadowsDisplay = NO;
              config.ignoreShadowsSingleWindow = NO;
              config.minimumFrameInterval = CMTimeMake(1, 60);
              config.scalesToFit = YES;
              config.width = win.frame.size.width*2;
              config.height = win.frame.size.height*2;

              void (^captureHandler)(CGImageRef, NSError *) =
                  ^(CGImageRef ref,
                      NSError *_Nullable error) {
                      if (error ||!ref) {
                        DO_DISPATCH(waitForImageSemaphor);
                        return;
                      }

                      final = [[NSImage alloc] initWithCGImage:ref
                                                          size:win.frame.size];
                      DO_DISPATCH(waitForImageSemaphor);
                  };

              [SCScreenshotManager captureImageWithFilter:filter
                                                  configuration:config
                                              completionHandler:captureHandler];
              }
      };

      [SCShareableContent getShareableContentExcludingDesktopWindows:YES
                                                  onScreenWindowsOnly:YES
                                                  completionHandler:handler];

      dispatch_semaphore_wait(waitForImageSemaphor, DISPATCH_TIME_FOREVER);
      #undef DO_DISPATCH
      return final;
  } else {
      return NULL;
  }
}

NSImage *_Nullable screenshotWindowModern(CGWindowID wId) {
  if (@available(macOS 26.0.0, *)) {
    dispatch_semaphore_t waitForImageSemaphor = dispatch_semaphore_create(0);
    __block NSImage *_Nullable final = NULL;

    #define DO_DISPATCH(semaphor) (dispatch_semaphore_signal(semaphor))

    void (^handler)(SCShareableContent *, NSError *) =
        ^(SCShareableContent *shareableContent, NSError *error) {
            @autoreleasepool {
            if (!shareableContent || error) {
                DO_DISPATCH(waitForImageSemaphor);
                return;
            }

            SCWindow *win = NULL;
            for (SCWindow *w in shareableContent.windows) {
                if (w.windowID != wId)
                    continue;
                win = w;
                break;
            }

            if (!win) {
                DO_DISPATCH(waitForImageSemaphor);
                return;
            }

            SCContentFilter *filter = [[[SCContentFilter alloc]
                initWithDesktopIndependentWindow:win] autorelease];
            SCScreenshotConfiguration *config =
                [[[SCScreenshotConfiguration alloc] init] autorelease];

            config.ignoreClipping = YES;
            config.showsCursor = NO;
            config.ignoreShadows = NO;

            void (^captureHandler)(SCScreenshotOutput *_Nullable,
                                    NSError *_Nullable) =
                ^(SCScreenshotOutput *_Nullable output,
                    NSError *_Nullable error) {
                    if (error || !output || !output.sdrImage) {
                    DO_DISPATCH(waitForImageSemaphor);
                    return;
                    }

                    final = [[NSImage alloc]
                        initWithCGImage:output.sdrImage
                                size:CGSizeMake(
                                            CGImageGetWidth(output.sdrImage),
                                            CGImageGetHeight(output.sdrImage))];
                    DO_DISPATCH(waitForImageSemaphor);
                };

            [SCScreenshotManager captureScreenshotWithFilter:filter
                                                configuration:config
                                            completionHandler:captureHandler];
            }
    };

    [SCShareableContent getShareableContentExcludingDesktopWindows:YES
                                                onScreenWindowsOnly:YES
                                                completionHandler:handler];

    dispatch_semaphore_wait(waitForImageSemaphor, DISPATCH_TIME_FOREVER);
    #undef DO_DISPATCH
    return final;
  } else {
    return NULL;
  }
}

typedef CGImageRef _Nullable (*func)(CGRect, CGWindowListOption, CGWindowID, CGWindowImageOption);

NSImage *screenshotWindowLegacy(CGWindowID wId) {
  const char *loc;
  if (@available(macOS 10.8.0, *)) {
    loc = "/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics";
  } else {
    loc = "/System/Library/Frameworks/ApplicationServices.framework/Versions/A/"
          "Frameworks/CoreGraphics.framework/CoreGraphics";
  }

  void *handle =
      dlopen(loc, RTLD_LAZY);
  func f = (func)dlsym(handle, "CGWindowListCreateImage");

  CGImageRef ref = f(CGRectNull, kCGWindowListOptionIncludingWindow,
                                           wId, kCGWindowImageDefault);

  dlclose(handle);

  return [((NSImage *)(((id (*)(id, SEL))objc_msgSend)(
      objc_getClass("NSImage"), sel_registerName("alloc"))))
      initWithCGImage:ref
                 size:CGSizeMake(
                          CGImageGetWidth(ref),
                          CGImageGetHeight(ref))];
}

NSImage *_Nullable screenshotWindow(CGWindowID wId) {
  if (@available(macOS 26.0.0, *)) {
      return screenshotWindowModern(wId);
  } else if (@available(macOS 15.0.0, *)) {
      return screenshotWindowSequoia(wId);
  } else {
      return screenshotWindowLegacy(wId);
  }
}

void reactivateApp(CGWindowID wId) {
    CFArrayRef windowList =
        CGWindowListCopyWindowInfo(kCGWindowListOptionIncludingWindow, wId);
    NSArray *nsArrayWindowList = (__bridge NSArray *)windowList;
    pid_t processId;

    for (NSDictionary *w in nsArrayWindowList) {
      if ([[w objectForKey:(id)kCGWindowNumber] unsignedIntValue] != wId)
        continue;
      processId = [[w objectForKey:(id)kCGWindowOwnerPID] intValue];
      break;
    }

    CFRelease(windowList);

    NSRunningApplication *app = [NSRunningApplication
        runningApplicationWithProcessIdentifier:processId];
    [app activateWithOptions:NSApplicationActivateAllWindows];
}
