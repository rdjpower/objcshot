#include <Cocoa/Cocoa.h>
#include <AppKit/AppKit.h>
#include "delegate.h"
#include "preferences.h"
#include <objc/runtime.h>
#include <objc/message.h>

int main(void) {
  @autoreleasepool {
    NSApplication *app = [NSApplication sharedApplication];
    ObjCShotDelegate* delegate = [[((ObjCShotDelegate *)(((id (*)(id, SEL))objc_msgSend)(
        objc_getClass("ObjCShotDelegate"), sel_registerName("alloc")))) init] autorelease];

    [app setDelegate:delegate];
    [app setActivationPolicy:NSApplicationActivationPolicyAccessory];

    loadState();
    [app run];
    }
    return 0;
}
