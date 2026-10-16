#ifndef CSHIMS_H
#define CSHIMS_H

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// ---- Spaces (SkyLight, read-only) ----

typedef struct {
    uint32_t index;     // zero-based index of the current space on the display under the cursor
    uint32_t count;     // spaces on that display (desktops and full-screen apps), in Dock order
    char display[128];  // display UUID
} ISSpaceInfo;

bool is_spaces_available(void);
/// Fills `out` for the display under the mouse cursor. Returns false on failure.
bool is_spaces_info(ISSpaceInfo *out);

// ---- Dock swipe (synthetic gesture + interception of the native one) ----

/// Called from the event tap (main run loop) when a native horizontal Dock swipe starts.
/// direction: +1 = towards the next space (right), -1 = towards the previous one (left).
typedef void (*ISSwipeHandler)(int direction);

/// Asks the Dock to switch one space instantly by posting a synthetic swipe with a tiny
/// progress and a huge fling velocity. Needs Accessibility permission.
bool is_ds_post_switch(int direction);

/// Installs the session event tap that swallows native horizontal Dock swipes and hands them to
/// the handler instead. Needs Accessibility permission; returns false if it cannot be created.
bool is_ds_tap_install(void);
bool is_ds_tap_installed(void);
/// When false, native swipes pass through untouched (normal animated switching).
void is_ds_set_intercept(bool enabled);
void is_ds_set_swipe_handler(ISSwipeHandler handler);

#ifdef __cplusplus
}
#endif
#endif
