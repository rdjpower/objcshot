#include <AppKit/AppKit.h>

CGWindowID getActiveWindow(void);
NSImage *_Nullable screenshotWindow(CGWindowID wId);
NSWindow *_Nonnull shortcutWindow(void);
NSString *_Nonnull getWindowName(CGWindowID wId, NSString*_Nonnull identifier);
NSData *_Nonnull getScreenshotPNG(NSImage *_Nonnull img);
void savePNG(NSString *_Nonnull name, NSImage *_Nonnull screenshot);
void reactivateApp(CGWindowID wId);
