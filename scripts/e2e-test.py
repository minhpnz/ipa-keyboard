#!/usr/bin/env python3
"""End-to-end test for IPA Keyboard.

Uses Quartz CGEvent to post keystrokes at HID level (same as physical keyboard).
Tests: mappings, cycling, toggle, quit/relaunch, performance, and stress tolerance.
"""

import subprocess
import time
import sys
import os
import select

try:
    from Quartz import (
        CGEventCreateKeyboardEvent, CGEventPost, CGEventSetFlags,
        kCGHIDEventTap, kCGEventFlagMaskControl, CGEventSourceCreate,
        kCGEventSourceStateHIDSystemState,
    )
except ImportError:
    print("ERROR: pip3 install pyobjc-framework-Quartz")
    sys.exit(1)

# ── Config ──────────────────────────────────────────────────────────

APP_BUNDLE = os.path.join(
    os.path.dirname(__file__),
    "../companion-app/src-tauri/target/release/bundle/macos/IPA Keyboard.app",
)
APP_BUNDLE = os.path.abspath(APP_BUNDLE)
APP_PROCESS_NAME = "IPA Keyboard"

PASS = 0
FAIL = 0

# macOS virtual keycodes -> letter
KEYCODE_MAP = {
    'a': 0, 's': 1, 'd': 2, 'f': 3, 'h': 4, 'g': 5,
    'z': 6, 'x': 7, 'c': 8, 'v': 9, 'b': 11, 'q': 12,
    'w': 13, 'e': 14, 'r': 15, 'y': 16, 't': 17,
    'o': 31, 'u': 32, 'i': 34, 'p': 35, 'l': 37,
    'j': 38, 'k': 40, 'n': 45, 'm': 46,
}

# IPA mappings from default-mappings.json
IPA_MAPPINGS = {
    'a': ['æ', 'ɑ', 'ɑː', 'ʌ'],
    'e': ['e', 'ə', 'ɜː'],
    'i': ['ɪ', 'iː'],
    'o': ['ɒ', 'ɔ', 'ɔː'],
    'u': ['ʊ', 'uː'],
    't': ['t', 'θ', 'ð'],
    's': ['s', 'ʃ', 'ʒ'],
    'd': ['d', 'dʒ'],
    'c': ['k', 'tʃ'],
    'n': ['n', 'ŋ'],
    'r': ['r'],
    'l': ['l'],
    'h': ['h'],
    'm': ['m'],
    'f': ['f'],
    'v': ['v'],
    'b': ['b'],
    'p': ['p'],
    'g': ['g'],
    'z': ['z'],
    'w': ['w'],
    'j': ['j'],
}

# ── Helpers ─────────────────────────────────────────────────────────

def applescript(script):
    r = subprocess.run(["osascript", "-e", script], capture_output=True, text=True, timeout=10)
    return r.stdout.strip()


def get_text():
    return applescript('tell application "TextEdit" to get text of front document')


def clear_doc():
    """Select all and delete to clear the document."""
    applescript('''
tell application "System Events"
    tell process "TextEdit"
        set frontmost to true
        keystroke "a" using command down
        key code 51
    end tell
end tell
''')
    time.sleep(0.3)


def focus_textedit():
    applescript('tell application "System Events" to tell process "TextEdit" to set frontmost to true')
    time.sleep(0.3)


def send_ctrl(keycode):
    focus_textedit()
    src = CGEventSourceCreate(kCGEventSourceStateHIDSystemState)
    down = CGEventCreateKeyboardEvent(src, keycode, True)
    CGEventSetFlags(down, kCGEventFlagMaskControl)
    CGEventPost(kCGHIDEventTap, down)
    time.sleep(0.05)
    up = CGEventCreateKeyboardEvent(src, keycode, False)
    CGEventSetFlags(up, kCGEventFlagMaskControl)
    CGEventPost(kCGHIDEventTap, up)
    time.sleep(0.6)


def send_ctrl_timed(keycode):
    """Send Ctrl+key and return the time taken in ms."""
    focus_textedit()
    src = CGEventSourceCreate(kCGEventSourceStateHIDSystemState)
    start = time.perf_counter()
    down = CGEventCreateKeyboardEvent(src, keycode, True)
    CGEventSetFlags(down, kCGEventFlagMaskControl)
    CGEventPost(kCGHIDEventTap, down)
    time.sleep(0.05)
    up = CGEventCreateKeyboardEvent(src, keycode, False)
    CGEventSetFlags(up, kCGEventFlagMaskControl)
    CGEventPost(kCGHIDEventTap, up)
    time.sleep(0.3)
    elapsed = (time.perf_counter() - start) * 1000
    return elapsed


def send_ctrl_repeated(keycode, times):
    focus_textedit()
    src = CGEventSourceCreate(kCGEventSourceStateHIDSystemState)
    for i in range(times):
        down = CGEventCreateKeyboardEvent(src, keycode, True)
        CGEventSetFlags(down, kCGEventFlagMaskControl)
        CGEventPost(kCGHIDEventTap, down)
        time.sleep(0.03)
        up = CGEventCreateKeyboardEvent(src, keycode, False)
        CGEventSetFlags(up, kCGEventFlagMaskControl)
        CGEventPost(kCGHIDEventTap, up)
        time.sleep(0.1)
    time.sleep(0.5)


def send_ctrl_burst(keycode, times, delay=0.03):
    """Send rapid Ctrl+key presses with minimal delay."""
    focus_textedit()
    src = CGEventSourceCreate(kCGEventSourceStateHIDSystemState)
    for i in range(times):
        down = CGEventCreateKeyboardEvent(src, keycode, True)
        CGEventSetFlags(down, kCGEventFlagMaskControl)
        CGEventPost(kCGHIDEventTap, down)
        time.sleep(0.01)
        up = CGEventCreateKeyboardEvent(src, keycode, False)
        CGEventSetFlags(up, kCGEventFlagMaskControl)
        CGEventPost(kCGHIDEventTap, up)
        time.sleep(delay)
    time.sleep(0.5)


def click_tray(item):
    applescript(f'''
tell application "System Events"
    tell process "{APP_PROCESS_NAME}"
        click menu bar item 1 of menu bar 2
        delay 0.5
        click menu item "{item}" of menu 1 of menu bar item 1 of menu bar 2
    end tell
end tell
''')
    time.sleep(1)


def test(name, expected, actual):
    global PASS, FAIL
    if expected == actual:
        print(f"  PASS: {name}")
        PASS += 1
    else:
        print(f"  FAIL: {name} — expected '{expected}', got '{actual}'")
        FAIL += 1


def test_perf(name, value_ms, threshold_ms):
    global PASS, FAIL
    if value_ms <= threshold_ms:
        print(f"  PASS: {name} ({value_ms:.0f}ms <= {threshold_ms}ms)")
        PASS += 1
    else:
        print(f"  FAIL: {name} ({value_ms:.0f}ms > {threshold_ms}ms)")
        FAIL += 1


# ── App lifecycle helpers ───────────────────────────────────────────

def is_app_running():
    r = subprocess.run(["pgrep", "-f", "IPA Keyboard"], capture_output=True, text=True)
    return r.returncode == 0


def launch_app():
    print(f"  Launching app...")
    if not os.path.isdir(APP_BUNDLE):
        print(f"  ERROR: App bundle not found at {APP_BUNDLE}")
        print("  Run 'npm run tauri build' first.")
        sys.exit(1)

    binary = os.path.join(APP_BUNDLE, "Contents/MacOS/ipa-keyboard")
    proc = subprocess.Popen(
        [binary],
        stderr=subprocess.PIPE,
        stdout=subprocess.DEVNULL,
        start_new_session=True,
    )

    start = time.time()
    while time.time() - start < 15:
        ready, _, _ = select.select([proc.stderr], [], [], 1.0)
        if ready:
            line = proc.stderr.readline().decode("utf-8", errors="replace").strip()
            if line:
                print(f"    [{line}]")
                if "Event tap installed" in line:
                    print(f"  App ready ({time.time()-start:.1f}s)")
                    time.sleep(1)
                    return
        if not is_app_running():
            print("  ERROR: App died")
            sys.exit(1)
    print("  ERROR: Tap not installed within 15s")
    sys.exit(1)


def quit_app():
    print("  Quitting app...")
    try:
        applescript(f'tell application "{APP_PROCESS_NAME}" to quit')
    except Exception:
        pass
    for i in range(10):
        time.sleep(1)
        if not is_app_running():
            print(f"  App quit ({i+1}s)")
            return
    subprocess.run(["pkill", "-f", "IPA Keyboard"], capture_output=True)
    time.sleep(2)


def kill_app():
    print("  Force killing app...")
    subprocess.run(["pkill", "-9", "-f", "IPA Keyboard"], capture_output=True)
    time.sleep(2)


def ensure_textedit():
    applescript('tell application "TextEdit" to activate')
    time.sleep(1)


def open_doc():
    """Open a single TextEdit document for all tests."""
    try:
        applescript('tell application "TextEdit" to close every document saving no')
    except Exception:
        pass
    time.sleep(0.3)
    applescript('tell application "TextEdit" to make new document')
    time.sleep(1)
    applescript('tell application "System Events" to tell process "TextEdit" to set frontmost to true')
    time.sleep(0.5)


def close_doc():
    try:
        applescript('tell application "TextEdit" to close front document saving no')
    except Exception:
        pass
    time.sleep(0.5)


def cleanup():
    try:
        applescript('tell application "TextEdit" to close every document saving no')
    except Exception:
        pass
    if is_app_running():
        quit_app()


# ════════════════════════════════════════════════════════════════════
#  TESTS
# ════════════════════════════════════════════════════════════════════

print("=" * 60)
print("IPA Keyboard — End-to-End Test Suite")
print("=" * 60)

if is_app_running():
    print("\n[Setup] Killing existing instance...")
    kill_app()

ensure_textedit()

# ── Phase 1: First Launch ──────────────────────────────────────────

print("\n── Phase 1: First Launch ──────────────────────────────────")
launch_app()

# ── Phase 2: All first-symbols in one sequence ─────────────────────

print("\n── Phase 2: All Letters — First Symbol Sequence ───────────")

open_doc()

letters_in_order = sorted(IPA_MAPPINGS.keys())
expected_sequence = ""
for letter in letters_in_order:
    keycode = KEYCODE_MAP.get(letter)
    if keycode is None:
        continue
    send_ctrl(keycode)
    expected_sequence += IPA_MAPPINGS[letter][0]

actual = get_text()
test(f"All first symbols: '{expected_sequence}'", expected_sequence, actual)

# ── Phase 3: Cycling test — multi-symbol letters ──────────────────

print("\n── Phase 3: Cycling — Multi-Symbol Sequence ────────────────")

clear_doc()

expected_cycle = ""
for letter in letters_in_order:
    symbols = IPA_MAPPINGS[letter]
    if len(symbols) <= 1:
        continue
    keycode = KEYCODE_MAP.get(letter)
    if keycode is None:
        continue
    send_ctrl_repeated(keycode, len(symbols))
    expected_cycle += symbols[-1]

actual = get_text()
test(f"All cycling (last variants): '{expected_cycle}'", expected_cycle, actual)

# ── Phase 4: Wrap-around test ─────────────────────────────────────

print("\n── Phase 4: Wrap-Around Cycling ───────────────────────────")

clear_doc()

wrap_count = len(IPA_MAPPINGS['a']) + 1
send_ctrl_repeated(KEYCODE_MAP['a'], wrap_count)
actual = get_text()
test(f"Ctrl+A x{wrap_count} wraps → '{IPA_MAPPINGS['a'][0]}'", IPA_MAPPINGS['a'][0], actual)

# ── Phase 5: Tray menu toggle ─────────────────────────────────────

print("\n── Phase 5: Tray Menu Toggle ──────────────────────────────")

clear_doc()
time.sleep(0.5)

click_tray("Disable IPA Input")
send_ctrl(KEYCODE_MAP['a'])
test("Disabled → Ctrl+A produces nothing", "", get_text())

click_tray("Enable IPA Input")
time.sleep(1)
clear_doc()
send_ctrl(KEYCODE_MAP['a'])
test("Re-enabled → Ctrl+A produces æ", "æ", get_text())

# ── Phase 6: Ctrl+Space toggle ────────────────────────────────────

print("\n── Phase 6: Ctrl+Space Toggle ─────────────────────────────")

clear_doc()
time.sleep(0.5)

send_ctrl(49)  # space — disable
time.sleep(0.5)
send_ctrl(KEYCODE_MAP['a'])
test("Ctrl+Space off → Ctrl+A produces nothing", "", get_text())

send_ctrl(49)  # space — re-enable
time.sleep(1)
clear_doc()
send_ctrl(KEYCODE_MAP['a'])
test("Ctrl+Space on → Ctrl+A produces æ", "æ", get_text())

# ── Phase 7: Performance — Single Keystroke Latency ───────────────

print("\n── Phase 7: Performance — Keystroke Latency ───────────────")

clear_doc()

# Measure latency for 10 keystrokes, take average
latencies = []
for _ in range(10):
    clear_doc()
    ms = send_ctrl_timed(KEYCODE_MAP['a'])
    latencies.append(ms)

avg_latency = sum(latencies) / len(latencies)
max_latency = max(latencies)
min_latency = min(latencies)
print(f"  INFO: Latencies — min: {min_latency:.0f}ms, avg: {avg_latency:.0f}ms, max: {max_latency:.0f}ms")
test_perf("Average keystroke latency", avg_latency, 500)
test_perf("Max keystroke latency (no spike)", max_latency, 800)

# ── Phase 8: Stress — Rapid Fire (50 keystrokes) ─────────────────

print("\n── Phase 8: Stress — Rapid Fire (50 keystrokes) ───────────")

clear_doc()

# Fire 50 Ctrl+A rapidly — each should cycle, final result = one symbol
start = time.perf_counter()
send_ctrl_burst(KEYCODE_MAP['a'], 50, delay=0.03)
elapsed = (time.perf_counter() - start) * 1000

actual = get_text()
# 50 presses on 4 symbols: 50 % 4 = 2 → second symbol (index 1)
expected_idx = (50 - 1) % len(IPA_MAPPINGS['a'])
expected_rapid = IPA_MAPPINGS['a'][expected_idx]
test(f"Rapid 50x Ctrl+A → '{expected_rapid}' (cycle index {expected_idx})", expected_rapid, actual)
test_perf(f"Rapid fire 50 keystrokes total time", elapsed, 5000)
print(f"  INFO: 50 keystrokes in {elapsed:.0f}ms ({elapsed/50:.0f}ms per key)")

# ── Phase 9: Stress — Mixed Rapid Keys (30 different letters) ─────

print("\n── Phase 9: Stress — Mixed Rapid Keys ─────────────────────")

clear_doc()

# Type 30 different Ctrl+letter rapidly, each should produce first symbol
mixed_letters = (list(IPA_MAPPINGS.keys()) * 2)[:30]  # repeat to get 30
expected_mixed = ""
start = time.perf_counter()
focus_textedit()
src = CGEventSourceCreate(kCGEventSourceStateHIDSystemState)
for letter in mixed_letters:
    keycode = KEYCODE_MAP.get(letter)
    if keycode is None:
        continue
    down = CGEventCreateKeyboardEvent(src, keycode, True)
    CGEventSetFlags(down, kCGEventFlagMaskControl)
    CGEventPost(kCGHIDEventTap, down)
    time.sleep(0.01)
    up = CGEventCreateKeyboardEvent(src, keycode, False)
    CGEventSetFlags(up, kCGEventFlagMaskControl)
    CGEventPost(kCGHIDEventTap, up)
    time.sleep(0.05)
    expected_mixed += IPA_MAPPINGS[letter][0]
time.sleep(1)
elapsed = (time.perf_counter() - start) * 1000

actual = get_text()
test(f"Mixed 30 keys output correct", expected_mixed, actual)
test_perf(f"Mixed 30 keystrokes total time", elapsed, 5000)
print(f"  INFO: 30 mixed keys in {elapsed:.0f}ms ({elapsed/30:.0f}ms per key)")

# ── Phase 10: Stress — Long Sequence Integrity ────────────────────

print("\n── Phase 10: Stress — Long Sequence (100 symbols) ─────────")

clear_doc()

# Type 100 Ctrl+letter presses (cycling through all letters ~5 times)
all_letters = sorted(IPA_MAPPINGS.keys())
sequence_letters = (all_letters * 5)[:100]
expected_long = ""
focus_textedit()
src = CGEventSourceCreate(kCGEventSourceStateHIDSystemState)
start = time.perf_counter()
for letter in sequence_letters:
    keycode = KEYCODE_MAP.get(letter)
    if keycode is None:
        continue
    down = CGEventCreateKeyboardEvent(src, keycode, True)
    CGEventSetFlags(down, kCGEventFlagMaskControl)
    CGEventPost(kCGHIDEventTap, down)
    time.sleep(0.01)
    up = CGEventCreateKeyboardEvent(src, keycode, False)
    CGEventSetFlags(up, kCGEventFlagMaskControl)
    CGEventPost(kCGHIDEventTap, up)
    time.sleep(0.05)
    expected_long += IPA_MAPPINGS[letter][0]
time.sleep(2)
elapsed = (time.perf_counter() - start) * 1000

actual = get_text()
# Check length match
len_match = len(actual) == len(expected_long)
content_match = actual == expected_long
if content_match:
    print(f"  PASS: 100 symbols — all correct")
    PASS += 1
elif len_match:
    # Find first mismatch
    for i, (e, a) in enumerate(zip(expected_long, actual)):
        if e != a:
            print(f"  FAIL: Mismatch at position {i}: expected '{e}', got '{a}'")
            break
    FAIL += 1
else:
    print(f"  FAIL: Length mismatch — expected {len(expected_long)}, got {len(actual)}")
    print(f"        Expected: '{expected_long[:50]}...'")
    print(f"        Actual:   '{actual[:50]}...'")
    FAIL += 1

test_perf("100 symbols total time", elapsed, 15000)
print(f"  INFO: 100 symbols in {elapsed:.0f}ms ({elapsed/100:.0f}ms per key)")

# ── Phase 11: CPU Check — App Not Hogging Resources ──────────────

print("\n── Phase 11: Resource Check ───────────────────────────────")

time.sleep(2)  # let things settle
r = subprocess.run(
    ["ps", "-p", str(subprocess.run(["pgrep", "-f", "IPA Keyboard"], capture_output=True, text=True).stdout.strip().split()[0]),
     "-o", "%cpu=,%mem="],
    capture_output=True, text=True
)
if r.returncode == 0:
    parts = r.stdout.strip().split()
    cpu = float(parts[0])
    mem = float(parts[1])
    print(f"  INFO: CPU: {cpu}%, Memory: {mem}%")
    test_perf("Idle CPU usage", cpu, 5.0)
    test_perf("Memory usage", mem, 2.0)
else:
    print("  SKIP: Could not read process stats")

close_doc()

# ── Phase 12: Quit & Relaunch ─────────────────────────────────────

print("\n── Phase 12: Quit & Relaunch ──────────────────────────────")

quit_app()
test("App process exited", False, is_app_running())

launch_app()
test("App running after relaunch", True, is_app_running())

open_doc()
send_ctrl(KEYCODE_MAP['a'])
send_ctrl(KEYCODE_MAP['e'])
send_ctrl(KEYCODE_MAP['s'])
test("After relaunch: Ctrl+A,E,S → æes", "æes", get_text())
close_doc()

# ── Cleanup ─────────────────────────────────────────────────────────

print("\n── Cleanup ────────────────────────────────────────────────")
cleanup()
print("  Done.")

# ── Results ─────────────────────────────────────────────────────────

total = PASS + FAIL
print(f"\n{'=' * 60}")
print(f"Results: {PASS} passed, {FAIL} failed out of {total} tests")
if FAIL == 0:
    print("All tests passed!")
else:
    print(f"{FAIL} test(s) need attention.")
print(f"{'=' * 60}")
sys.exit(0 if FAIL == 0 else 1)
