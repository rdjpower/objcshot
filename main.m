#include <Cocoa/Cocoa.h>
#include <AppKit/AppKit.h>
#include "delegate.h"
#include "preferences.h"

int main(void) {
  @autoreleasepool {
    NSApplication *app = [NSApplication sharedApplication];
    ObjCShotDelegate* delegate = [[[ObjCShotDelegate alloc] init] autorelease];

    [app setDelegate:delegate];
    [app setActivationPolicy:NSApplicationActivationPolicyAccessory];

    loadState();
    [app run];
    }
    return 0;
}
