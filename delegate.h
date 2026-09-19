#pragma once
#include <AppKit/AppKit.h>
#include <Cocoa/Cocoa.h>

void activeScreenshot();
void activeInactiveScreenshot();

@interface ObjCShotDelegate : NSObject<NSApplicationDelegate, NSWindowDelegate>
@property(strong, nonatomic) NSWindow *shortwnd;
@property(strong, nonatomic) NSStatusItem *bar;
@end
