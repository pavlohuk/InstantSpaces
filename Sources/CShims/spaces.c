#include "CShims.h"
#include <CoreFoundation/CoreFoundation.h>
#include <CoreGraphics/CoreGraphics.h>
#include <dlfcn.h>
#include <string.h>

// Exported by CoreGraphics but only declared in ColorSync headers.
extern CFUUIDRef CGDisplayCreateUUIDFromDisplayID(uint32_t displayID);

typedef int (*f_cid)(void);
typedef CFArrayRef (*f_copyspaces)(int);
typedef uint64_t (*f_getcur)(int, CFStringRef);
typedef CFStringRef (*f_activedisp)(int);

static struct {
    int tried;
    void *handle;
    int conn;
    f_copyspaces copy_spaces;
    f_getcur get_current;
    f_activedisp active_display;
} S;

static bool load_sl(void) {
    if (S.tried) return S.handle != NULL;
    S.tried = 1;
    void *h = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW);
    if (!h) return false;
    f_cid cid = (f_cid)dlsym(h, "SLSMainConnectionID");
    S.copy_spaces    = (f_copyspaces)dlsym(h, "SLSCopyManagedDisplaySpaces");
    S.get_current    = (f_getcur)dlsym(h, "SLSManagedDisplayGetCurrentSpace");
    S.active_display = (f_activedisp)dlsym(h, "SLSCopyActiveMenuBarDisplayIdentifier");
    if (!cid || !S.copy_spaces || !S.get_current) { dlclose(h); return false; }
    S.conn = cid();
    S.handle = h;
    return true;
}

bool is_spaces_available(void) { return load_sl(); }

/// UUID string of the display under the mouse cursor, or NULL.
static CFStringRef copy_display_uuid_under_cursor(void) {
    CGEventRef e = CGEventCreate(NULL);
    if (!e) return NULL;
    CGPoint p = CGEventGetLocation(e);
    CFRelease(e);
    CGDirectDisplayID did = 0;
    uint32_t n = 0;
    if (CGGetDisplaysWithPoint(p, 1, &did, &n) != kCGErrorSuccess || n == 0) return NULL;
    CFUUIDRef uuid = CGDisplayCreateUUIDFromDisplayID(did);
    if (!uuid) return NULL;
    CFStringRef s = CFUUIDCreateString(NULL, uuid);
    CFRelease(uuid);
    return s;
}

/// Entry of SLSCopyManagedDisplaySpaces() for the display under the cursor, falling back to the
/// active menu-bar display and then to the first entry.
static CFDictionaryRef find_display(CFArrayRef displays) {
    CFIndex n = CFArrayGetCount(displays);
    if (n == 0) return NULL;
    if (n == 1) return CFArrayGetValueAtIndex(displays, 0);

    CFDictionaryRef found = NULL;
    CFStringRef wanted = copy_display_uuid_under_cursor();
    if (!wanted && S.active_display) wanted = S.active_display(S.conn);
    if (wanted) {
        for (CFIndex i = 0; i < n; i++) {
            CFDictionaryRef d = CFArrayGetValueAtIndex(displays, i);
            CFStringRef ident = CFDictionaryGetValue(d, CFSTR("Display Identifier"));
            if (ident && CFStringCompare(ident, wanted, kCFCompareCaseInsensitive) == kCFCompareEqualTo) { found = d; break; }
        }
        CFRelease(wanted);
    }
    return found ? found : CFArrayGetValueAtIndex(displays, 0);
}

bool is_spaces_info(ISSpaceInfo *out) {
    if (!out || !load_sl()) return false;
    memset(out, 0, sizeof(*out));
    CFArrayRef displays = S.copy_spaces(S.conn);
    if (!displays) return false;
    bool ok = false;

    CFDictionaryRef display = find_display(displays);
    CFStringRef ident = display ? CFDictionaryGetValue(display, CFSTR("Display Identifier")) : NULL;
    CFArrayRef spaces = display ? CFDictionaryGetValue(display, CFSTR("Spaces")) : NULL;
    if (ident && spaces && CFGetTypeID(spaces) == CFArrayGetTypeID()) {
        CFStringGetCString(ident, out->display, sizeof(out->display), kCFStringEncodingUTF8);
        uint64_t cur = S.get_current(S.conn, ident);
        CFIndex n = CFArrayGetCount(spaces);
        if (n > IS_MAX_SPACES) n = IS_MAX_SPACES;
        bool found = false;
        for (CFIndex i = 0; i < n; i++) {
            CFDictionaryRef s = CFArrayGetValueAtIndex(spaces, i);
            CFNumberRef idn = CFDictionaryGetValue(s, CFSTR("id64"));
            CFNumberRef tn = CFDictionaryGetValue(s, CFSTR("type"));
            uint64_t id = 0;
            int32_t type = 0;
            if (idn) CFNumberGetValue(idn, kCFNumberSInt64Type, &id);
            if (tn) CFNumberGetValue(tn, kCFNumberSInt32Type, &type);
            out->types[i] = type;
            if (id == cur && !found) { out->index = (uint32_t)i; found = true; }
        }
        out->count = (uint32_t)n;
        ok = found && n > 0;
    }
    CFRelease(displays);
    return ok;
}
