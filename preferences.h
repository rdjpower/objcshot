#pragma once
#include <Cocoa/Cocoa.h>

typedef struct Preferences {
    NSURL* screenshot_location;
    NSUserDefaults* defaults;
} Preferences;

extern Preferences state;

void resolveLocation(void);
void loadState(void);
