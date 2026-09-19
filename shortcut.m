#import <Carbon/Carbon.h>
#include "delegate.h"

OSStatus callback(EventHandlerCallRef _r, EventRef event, void *_d) {
  EventHotKeyID id;
  GetEventParameter(event, kEventParamDirectObject, typeEventHotKeyID, NULL,
                    sizeof(id), NULL, &id);

  switch (id.id) {
  case 1:
    activeScreenshot();
    break;
  case 2:
    activeInactiveScreenshot();
    break;
  }

  return noErr;
}

void do_init(void) {
  EventTypeSpec spec;
  spec.eventClass = kEventClassKeyboard;
  spec.eventKind = kEventHotKeyPressed;

  InstallApplicationEventHandler(callback, 1, &spec, NULL, NULL);
}

EventHotKeyRef a1;
EventHotKeyRef a2;

void activeKeyInit() {
  EventHotKeyID id;
  id.signature = 'akc1';
  id.id = 1;

  RegisterEventHotKey(kVK_ANSI_B, cmdKey, id, GetApplicationEventTarget(), 0, &a1);
}
void activeInactiveKeyInit() {
    EventHotKeyID id;
    id.signature = 'akc2';
    id.id = 2;

    RegisterEventHotKey(kVK_ANSI_B, cmdKey + shiftKey, id, GetApplicationEventTarget(), 0, &a2);
}

void activeKeyDeinit() {
    UnregisterEventHotKey(a1);
}
void activeInactiveKeyDeinit() {
    UnregisterEventHotKey(a2);
}
