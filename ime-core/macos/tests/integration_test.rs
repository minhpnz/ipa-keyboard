//! Integration tests for the IPA Keyboard daemon.
//!
//! Covers three layers:
//!   1. Mapping engine — which symbols each key cycles through.
//!   2. Keycode ↔ letter — macOS virtual-keycode translation.
//!   3. `decide_key_action` — the full event-handling decision table
//!      (IPA state × modifiers × keycode → action).
//!
//! Run with: cargo test -p ipa-keyboard-daemon

use ipa_keyboard_daemon::event_tap::{
    decide_key_action, is_printable_character_key, keycode_to_letter, KeyAction,
};
use ipa_mapping_engine::MappingEngine;

// macOS virtual keycodes (documented subset, referenced throughout tests)
const KC_A: u16 = 0;
const KC_S: u16 = 1;
const KC_D: u16 = 2;
const KC_F: u16 = 3;
const KC_H: u16 = 4;
const KC_G: u16 = 5;
const KC_Z: u16 = 6;
const KC_X: u16 = 7;
const KC_C: u16 = 8;
const KC_V: u16 = 9;
const KC_B: u16 = 11;
const KC_Q: u16 = 12;
const KC_W: u16 = 13;
const KC_E: u16 = 14;
const KC_R: u16 = 15;
const KC_Y: u16 = 16;
const KC_T: u16 = 17;
const KC_1: u16 = 18;
const KC_0: u16 = 29;
const KC_EQ: u16 = 24;
const KC_MINUS: u16 = 27;
const KC_RBRACK: u16 = 30;
const KC_O: u16 = 31;
const KC_U: u16 = 32;
const KC_LBRACK: u16 = 33;
const KC_I: u16 = 34;
const KC_P: u16 = 35;
const KC_RETURN: u16 = 36;
const KC_L: u16 = 37;
const KC_J: u16 = 38;
const KC_QUOTE: u16 = 39;
const KC_K: u16 = 40;
const KC_SEMI: u16 = 41;
const KC_BACKSLASH: u16 = 42;
const KC_COMMA: u16 = 43;
const KC_SLASH: u16 = 44;
const KC_N: u16 = 45;
const KC_M: u16 = 46;
const KC_DOT: u16 = 47;
const KC_TAB: u16 = 48;
const KC_SPACE: u16 = 49;
const KC_GRAVE: u16 = 50;
const KC_BACKSPACE: u16 = 51;
const KC_ESCAPE: u16 = 53;
const KC_F1: u16 = 122;
const KC_F5: u16 = 96;
const KC_F12: u16 = 111;
const KC_LEFT: u16 = 123;
const KC_RIGHT: u16 = 124;
const KC_DOWN: u16 = 125;
const KC_UP: u16 = 126;

fn default_engine() -> MappingEngine {
    let json = include_str!("../../../shared-config/default-mappings.json");
    MappingEngine::from_json(json).expect("default-mappings.json should parse")
}

// ============================================================================
// LAYER 1 — Mapping engine (what each key cycles through)
// ============================================================================

/// The 11 keys the handwritten notes specify.
const MAPPED_LETTERS: &[&str] = &["a", "e", "i", "o", "u", "t", "s", "d", "c", "n", "z"];

/// Letters that should NOT have IPA mappings (normal typing on those keys).
const UNMAPPED_LETTERS: &[&str] = &[
    "b", "f", "g", "h", "j", "k", "l", "m", "p", "q", "r", "v", "w", "x", "y",
];

#[test]
fn engine_covers_all_mapped_letters() {
    let mut engine = default_engine();
    for letter in MAPPED_LETTERS {
        engine.reset();
        let r = engine.cycle_next(letter);
        assert!(r.is_some(), "mapped letter '{letter}' must produce a symbol");
    }
}

#[test]
fn engine_rejects_unmapped_letters() {
    let mut engine = default_engine();
    for letter in UNMAPPED_LETTERS {
        engine.reset();
        let r = engine.cycle_next(letter);
        assert!(r.is_none(), "letter '{letter}' must not be mapped");
    }
}

#[test]
fn first_symbol_matches_spec() {
    let mut engine = default_engine();
    let expected: &[(&str, &str)] = &[
        ("a", "æ"),
        ("e", "ə"),
        ("i", "ɪ"),
        ("o", "ɒ"),
        ("u", "ʊ"),
        ("t", "θ"),
        ("s", "ʃ"),
        ("d", "dʒ"),
        ("c", "tʃ"),
        ("n", "ŋ"),
        ("z", "ʒ"),
    ];
    for (key, sym) in expected {
        engine.reset();
        let r = engine.cycle_next(key).unwrap();
        assert_eq!(&r.symbol, sym, "first symbol for '{key}'");
        assert!(!r.is_replace, "first press must not be a replacement");
    }
}

#[test]
fn cycle_a_four_variants() {
    let mut engine = default_engine();
    let cycle: &[&str] = &["æ", "ʌ", "ɑː", "ɑ", "æ"];
    for (idx, expected) in cycle.iter().enumerate() {
        let r = engine.cycle_next("a").unwrap();
        assert_eq!(&r.symbol, expected, "cycle position {idx}");
        assert_eq!(r.is_replace, idx > 0);
    }
}

#[test]
fn cycle_e_two_variants() {
    let mut engine = default_engine();
    for (idx, expected) in ["ə", "ɜː", "ə"].iter().enumerate() {
        let r = engine.cycle_next("e").unwrap();
        assert_eq!(&r.symbol, *expected, "cycle position {idx}");
    }
}

#[test]
fn cycle_i_three_variants() {
    let mut engine = default_engine();
    for (idx, expected) in ["ɪ", "iː", "i", "ɪ"].iter().enumerate() {
        let r = engine.cycle_next("i").unwrap();
        assert_eq!(&r.symbol, *expected, "cycle position {idx}");
    }
}

#[test]
fn cycle_o_two_variants() {
    let mut engine = default_engine();
    for (idx, expected) in ["ɒ", "ɔː", "ɒ"].iter().enumerate() {
        let r = engine.cycle_next("o").unwrap();
        assert_eq!(&r.symbol, *expected, "cycle position {idx}");
    }
}

#[test]
fn cycle_u_two_variants() {
    let mut engine = default_engine();
    for (idx, expected) in ["ʊ", "uː", "ʊ"].iter().enumerate() {
        let r = engine.cycle_next("u").unwrap();
        assert_eq!(&r.symbol, *expected, "cycle position {idx}");
    }
}

#[test]
fn cycle_t_two_variants() {
    let mut engine = default_engine();
    for (idx, expected) in ["θ", "ð", "θ"].iter().enumerate() {
        let r = engine.cycle_next("t").unwrap();
        assert_eq!(&r.symbol, *expected, "cycle position {idx}");
    }
}

#[test]
fn single_symbol_keys_wrap_to_self() {
    let mut engine = default_engine();
    for (key, sym) in [("s", "ʃ"), ("d", "dʒ"), ("c", "tʃ"), ("n", "ŋ"), ("z", "ʒ")] {
        engine.reset();
        let r1 = engine.cycle_next(key).unwrap();
        assert_eq!(r1.symbol, sym);
        let r2 = engine.cycle_next(key).unwrap();
        assert_eq!(r2.symbol, sym, "wrap for '{key}'");
        assert!(r2.is_replace);
    }
}

#[test]
fn switching_keys_resets_cycle() {
    let mut engine = default_engine();
    let r1 = engine.cycle_next("a").unwrap();
    assert_eq!(r1.symbol, "æ");
    // Switch to 'e' — first press on new key must not be a replacement.
    let r2 = engine.cycle_next("e").unwrap();
    assert_eq!(r2.symbol, "ə");
    assert!(!r2.is_replace);
    // Back to 'a' — also not a replacement (fresh start).
    let r3 = engine.cycle_next("a").unwrap();
    assert_eq!(r3.symbol, "æ");
    assert!(!r3.is_replace);
}

#[test]
fn case_insensitive_lookup() {
    let mut engine = default_engine();
    let lower = engine.cycle_next("a").unwrap().symbol.clone();
    engine.reset();
    let upper = engine.cycle_next("A").unwrap().symbol;
    assert_eq!(lower, upper);
}

#[test]
fn symbol_char_counts_for_backspace_math() {
    let mut engine = default_engine();
    // Single-codepoint symbols
    assert_eq!(engine.cycle_next("a").unwrap().symbol.chars().count(), 1); // æ
    engine.reset();
    assert_eq!(engine.cycle_next("n").unwrap().symbol.chars().count(), 1); // ŋ
    engine.reset();
    // Long vowels: 2 codepoints
    assert_eq!(engine.cycle_next("i").unwrap().symbol.chars().count(), 1); // ɪ
    let iː = engine.cycle_next("i").unwrap();
    assert_eq!(iː.symbol.chars().count(), 2); // iː
    assert!(iː.is_replace);
    engine.reset();
    // Affricate
    assert_eq!(engine.cycle_next("d").unwrap().symbol.chars().count(), 2); // dʒ
    engine.reset();
    assert_eq!(engine.cycle_next("c").unwrap().symbol.chars().count(), 2); // tʃ
}

#[test]
fn all_symbols_utf16_roundtrip() {
    let mut engine = default_engine();
    for letter in MAPPED_LETTERS {
        engine.reset();
        let first = engine.cycle_next(letter).unwrap().symbol;
        let utf16: Vec<u16> = first.encode_utf16().collect();
        let back = String::from_utf16(&utf16).expect("round-trip must succeed");
        assert_eq!(back, first);
        // Walk the rest of the cycle
        loop {
            let r = engine.cycle_next(letter).unwrap();
            let back = String::from_utf16(&r.symbol.encode_utf16().collect::<Vec<_>>()).unwrap();
            assert_eq!(back, r.symbol);
            if r.symbol == first {
                break;
            }
        }
    }
}

#[test]
fn all_expected_symbols_reachable_exactly() {
    let mut engine = default_engine();
    let mut seen: Vec<String> = Vec::new();
    for letter in MAPPED_LETTERS {
        engine.reset();
        let first = engine.cycle_next(letter).unwrap().symbol.clone();
        seen.push(first.clone());
        loop {
            let r = engine.cycle_next(letter).unwrap();
            if r.symbol == first {
                break;
            }
            seen.push(r.symbol);
        }
    }
    seen.sort();
    seen.dedup();

    let mut expected: Vec<&str> = vec![
        "æ", "ʌ", "ɑː", "ɑ", // a
        "ə", "ɜː", // e
        "ɪ", "iː", "i", // i
        "ɒ", "ɔː", // o
        "ʊ", "uː", // u
        "θ", "ð", // t
        "ʃ", // s
        "dʒ", // d
        "tʃ", // c
        "ŋ", // n
        "ʒ", // z
    ];
    expected.sort();
    expected.dedup();
    assert_eq!(
        seen,
        expected.iter().map(|s| s.to_string()).collect::<Vec<_>>(),
        "reachable symbols must match the handwritten spec exactly"
    );
}

// ============================================================================
// LAYER 2 — keycode_to_letter / is_printable_character_key
// ============================================================================

#[test]
fn keycode_to_letter_known_mappings() {
    let pairs: &[(u16, char)] = &[
        (KC_A, 'a'),
        (KC_S, 's'),
        (KC_D, 'd'),
        (KC_F, 'f'),
        (KC_H, 'h'),
        (KC_G, 'g'),
        (KC_Z, 'z'),
        (KC_X, 'x'),
        (KC_C, 'c'),
        (KC_V, 'v'),
        (KC_B, 'b'),
        (KC_Q, 'q'),
        (KC_W, 'w'),
        (KC_E, 'e'),
        (KC_R, 'r'),
        (KC_Y, 'y'),
        (KC_T, 't'),
        (KC_O, 'o'),
        (KC_U, 'u'),
        (KC_I, 'i'),
        (KC_P, 'p'),
        (KC_L, 'l'),
        (KC_J, 'j'),
        (KC_K, 'k'),
        (KC_N, 'n'),
        (KC_M, 'm'),
        (KC_1, '1'),
        (KC_0, '0'),
    ];
    for (kc, ch) in pairs {
        assert_eq!(
            keycode_to_letter(*kc),
            Some(*ch),
            "keycode {kc} should be '{ch}'"
        );
    }
}

#[test]
fn keycode_to_letter_rejects_navigation_and_symbols() {
    let non_letter: &[u16] = &[
        KC_RETURN,
        KC_TAB,
        KC_SPACE,
        KC_BACKSPACE,
        KC_ESCAPE,
        KC_LEFT,
        KC_RIGHT,
        KC_UP,
        KC_DOWN,
        KC_F1,
        KC_F12,
        KC_QUOTE,
        KC_SEMI,
        KC_COMMA,
        KC_SLASH,
        KC_DOT,
        KC_MINUS,
        KC_EQ,
        KC_LBRACK,
        KC_RBRACK,
        KC_BACKSLASH,
        KC_GRAVE,
    ];
    for kc in non_letter {
        assert_eq!(
            keycode_to_letter(*kc),
            None,
            "keycode {kc} must not map to a letter"
        );
    }
}

#[test]
fn is_printable_character_key_classification() {
    // Printable: letters, digits, punctuation on the typing area
    let printable: &[u16] = &[
        KC_A,
        KC_Z,
        KC_M,
        KC_P,
        KC_L,
        KC_Q,
        KC_W,
        KC_E,
        KC_R,
        KC_T,
        KC_Y,
        KC_U,
        KC_I,
        KC_O,
        KC_1,
        KC_0,
        KC_EQ,
        KC_MINUS,
        KC_LBRACK,
        KC_RBRACK,
        KC_QUOTE,
        KC_SEMI,
        KC_BACKSLASH,
        KC_COMMA,
        KC_SLASH,
        KC_DOT,
        KC_GRAVE,
    ];
    for kc in printable {
        assert!(
            is_printable_character_key(*kc),
            "keycode {kc} should be printable"
        );
    }

    // Non-printable: navigation / editing keys
    let non_printable: &[u16] = &[
        KC_RETURN,
        KC_TAB,
        KC_SPACE,
        KC_BACKSPACE,
        KC_ESCAPE,
        KC_LEFT,
        KC_RIGHT,
        KC_UP,
        KC_DOWN,
        KC_F1,
        KC_F5,
        KC_F12,
    ];
    for kc in non_printable {
        assert!(
            !is_printable_character_key(*kc),
            "keycode {kc} must NOT be classified printable"
        );
    }
}

// ============================================================================
// LAYER 3 — decide_key_action: the full decision table
// ============================================================================

// --- Cmd always passes through (system clipboard/undo/app shortcuts) ---

#[test]
fn cmd_shortcuts_always_pass_through() {
    // These are the sacred macOS shortcuts users rely on everywhere.
    let cmd_keys: &[u16] = &[
        KC_C, KC_V, KC_X, KC_Z, KC_A, KC_S, KC_N, KC_W, KC_T, KC_Q, KC_F, KC_R, KC_P,
    ];
    for ipa_on in [true, false] {
        for kc in cmd_keys {
            assert_eq!(
                decide_key_action(ipa_on, false, true, false, *kc),
                KeyAction::PassThrough,
                "Cmd+keycode {kc} must pass through (ipa_enabled={ipa_on})"
            );
        }
    }
}

#[test]
fn cmd_plus_ctrl_still_passes_through() {
    // Cmd+Ctrl combos (e.g. Cmd+Ctrl+Space = emoji picker) must reach the OS.
    for kc in [KC_SPACE, KC_A, KC_F] {
        assert_eq!(
            decide_key_action(true, true, true, false, kc),
            KeyAction::PassThrough,
        );
    }
}

// --- Option always passes through (accented chars on macOS) ---

#[test]
fn option_combos_always_pass_through() {
    // Option+letter produces alternate chars (é, ø, etc.). Must pass through.
    for kc in [KC_A, KC_E, KC_U, KC_O, KC_N] {
        for ipa_on in [true, false] {
            assert_eq!(
                decide_key_action(ipa_on, false, false, true, kc),
                KeyAction::PassThrough,
                "Option+keycode {kc} must pass (ipa_enabled={ipa_on})"
            );
        }
    }
}

// --- Plain typing (no modifier) ---

#[test]
fn plain_typing_resets_and_passes_through() {
    for kc in [KC_A, KC_H, KC_E, KC_L, KC_1, KC_SPACE, KC_COMMA] {
        assert_eq!(
            decide_key_action(true, false, false, false, kc),
            KeyAction::ResetAndPassThrough,
            "plain keycode {kc} must pass through (IPA on)"
        );
        assert_eq!(
            decide_key_action(false, false, false, false, kc),
            KeyAction::ResetAndPassThrough,
            "plain keycode {kc} must pass through (IPA off)"
        );
    }
}

// --- Ctrl+Space = toggle IPA ---

#[test]
fn ctrl_space_toggles_ipa_in_both_states() {
    assert_eq!(
        decide_key_action(true, true, false, false, KC_SPACE),
        KeyAction::ToggleIpa,
    );
    assert_eq!(
        decide_key_action(false, true, false, false, KC_SPACE),
        KeyAction::ToggleIpa,
    );
}

// --- IPA OFF: Ctrl+anything passes through ---

#[test]
fn ipa_off_ctrl_letters_pass_through() {
    // When IPA is off, the daemon must not interfere with the user's keyboard.
    // Ctrl+/ then does whatever macOS does by default (usually nothing).
    let ctrl_keys: &[u16] = &[
        KC_A,
        KC_B,
        KC_F,
        KC_K,
        KC_W,
        KC_SLASH,
        KC_TAB,
        KC_RETURN,
        KC_LEFT,
        KC_1,
    ];
    for kc in ctrl_keys {
        assert_eq!(
            decide_key_action(false, true, false, false, *kc),
            KeyAction::PassThrough,
            "IPA off: Ctrl+keycode {kc} must pass through"
        );
    }
}

// --- IPA ON: Ctrl+mapped-letter → TryCycle ---

#[test]
fn ipa_on_ctrl_mapped_letters_try_cycle() {
    // Ctrl+{a,e,i,o,u,t,s,d,c,n,z} all produce TryCycle(<letter>).
    let expected: &[(u16, char)] = &[
        (KC_A, 'a'),
        (KC_E, 'e'),
        (KC_I, 'i'),
        (KC_O, 'o'),
        (KC_U, 'u'),
        (KC_T, 't'),
        (KC_S, 's'),
        (KC_D, 'd'),
        (KC_C, 'c'),
        (KC_N, 'n'),
        (KC_Z, 'z'),
    ];
    for (kc, letter) in expected {
        assert_eq!(
            decide_key_action(true, true, false, false, *kc),
            KeyAction::TryCycle(*letter),
            "Ctrl+{} must cycle '{}'",
            letter.to_uppercase().next().unwrap(),
            letter
        );
    }
}

// --- IPA ON: Ctrl+printable-with-no-letter-mapping → SUPPRESS at decide stage ---

#[test]
fn ipa_on_printable_without_letter_mapping_is_suppressed() {
    // These keycodes don't translate to a letter at all (punctuation, symbols,
    // digits). When IPA is on, they're suppressed directly by decide_key_action
    // to block Emacs-style bindings like Ctrl+/ (undo).
    // Digits (KC_1..KC_0) ARE mapped to letter chars '1'..'0' by
    // keycode_to_letter, so they hit TryCycle → engine-None → Suppress at
    // runtime. Not listed here because they're Suppress end-to-end, not at
    // decide level. See `ipa_on_ctrl_letter_without_ipa_mapping_is_suppressed_end_to_end`.
    let suppressed: &[u16] = &[
        KC_SLASH,
        KC_COMMA,
        KC_DOT,
        KC_SEMI,
        KC_QUOTE,
        KC_LBRACK,
        KC_RBRACK,
        KC_BACKSLASH,
        KC_MINUS,
        KC_EQ,
        KC_GRAVE,
    ];
    for kc in suppressed {
        assert_eq!(
            decide_key_action(true, true, false, false, *kc),
            KeyAction::Suppress,
            "IPA on: Ctrl+keycode {kc} must be suppressed"
        );
    }
}

// --- IPA ON: Ctrl+letter-with-no-IPA → TryCycle, then engine returns None ---

/// End-to-end resolution: runs `decide_key_action` and, if it said TryCycle,
/// consults the engine. Mirrors what `tap_callback` does in production.
#[derive(Debug, PartialEq, Eq)]
enum Observable {
    PassThrough,
    Suppress,
    ToggleIpa,
    InjectSymbol(String),
}

fn resolve(engine: &mut MappingEngine, ipa_on: bool, has_ctrl: bool, kc: u16) -> Observable {
    match decide_key_action(ipa_on, has_ctrl, false, false, kc) {
        KeyAction::PassThrough | KeyAction::ResetAndPassThrough => Observable::PassThrough,
        KeyAction::Suppress => Observable::Suppress,
        KeyAction::ToggleIpa => Observable::ToggleIpa,
        KeyAction::TryCycle(letter) => match engine.cycle_next(&letter.to_string()) {
            Some(r) => Observable::InjectSymbol(r.symbol),
            None => Observable::Suppress,
        },
    }
}

#[test]
fn ipa_on_ctrl_letter_without_ipa_mapping_is_suppressed_end_to_end() {
    // Ctrl+K, Ctrl+W, Ctrl+F, Ctrl+H, Ctrl+X, Ctrl+Q, Ctrl+R, Ctrl+L, Ctrl+M,
    // Ctrl+J, Ctrl+G, Ctrl+V, Ctrl+B, Ctrl+P, Ctrl+Y — all real Emacs bindings
    // on macOS that would delete/reorder text. Must be end-to-end suppressed.
    let mut engine = default_engine();
    let dangerous: &[(u16, &str)] = &[
        (KC_K, "Ctrl+K kill-line"),
        (KC_W, "Ctrl+W delete-word"),
        (KC_F, "Ctrl+F forward-char"),
        (KC_H, "Ctrl+H backspace"),
        (KC_B, "Ctrl+B backward-char"),
        (KC_P, "Ctrl+P previous-line"),
        (KC_Y, "Ctrl+Y yank"),
        (KC_X, "Ctrl+X (unused letter)"),
        (KC_Q, "Ctrl+Q (unused letter)"),
        (KC_R, "Ctrl+R (unused letter)"),
        (KC_L, "Ctrl+L center-line"),
        (KC_M, "Ctrl+M newline"),
        (KC_J, "Ctrl+J newline"),
        (KC_G, "Ctrl+G abort"),
        (KC_V, "Ctrl+V page-down"),
    ];
    for (kc, label) in dangerous {
        engine.reset();
        assert_eq!(
            resolve(&mut engine, true, true, *kc),
            Observable::Suppress,
            "end-to-end: {label} (keycode {kc}) must be suppressed"
        );
    }
}

#[test]
fn ipa_on_ctrl_mapped_letter_injects_ipa_end_to_end() {
    let mut engine = default_engine();
    let cases: &[(u16, &str)] = &[
        (KC_A, "æ"),
        (KC_E, "ə"),
        (KC_I, "ɪ"),
        (KC_O, "ɒ"),
        (KC_U, "ʊ"),
        (KC_T, "θ"),
        (KC_S, "ʃ"),
        (KC_D, "dʒ"),
        (KC_C, "tʃ"),
        (KC_N, "ŋ"),
        (KC_Z, "ʒ"),
    ];
    for (kc, expected) in cases {
        engine.reset();
        assert_eq!(
            resolve(&mut engine, true, true, *kc),
            Observable::InjectSymbol(expected.to_string()),
            "Ctrl+keycode {kc} must inject first IPA symbol"
        );
    }
}

#[test]
fn ctrl_slash_end_to_end_is_suppressed_when_ipa_on() {
    // The exact bug the user reported.
    let mut engine = default_engine();
    assert_eq!(
        resolve(&mut engine, true, true, KC_SLASH),
        Observable::Suppress,
    );
    assert_eq!(
        resolve(&mut engine, false, true, KC_SLASH),
        Observable::PassThrough,
    );
}

// --- IPA ON: Ctrl+navigation-key → still pass through ---

#[test]
fn ipa_on_navigation_keys_pass_through_under_ctrl() {
    // Ctrl+Tab switches browser tabs; Ctrl+arrow jumps word; etc.
    // These must NOT be swallowed even when IPA is on.
    let nav: &[u16] = &[
        KC_TAB,
        KC_RETURN,
        KC_BACKSPACE,
        KC_ESCAPE,
        KC_LEFT,
        KC_RIGHT,
        KC_UP,
        KC_DOWN,
        KC_F1,
        KC_F5,
        KC_F12,
    ];
    for kc in nav {
        assert_eq!(
            decide_key_action(true, true, false, false, *kc),
            KeyAction::PassThrough,
            "Ctrl+navigation-keycode {kc} must pass through"
        );
    }
}

// --- Regression: the Ctrl+/ issue that triggered this whole refactor ---

#[test]
fn ctrl_slash_does_not_trigger_undo_when_ipa_on() {
    // Before the fix: Ctrl+/ passed through → macOS Emacs binding fired → undo
    // wiped the last-injected IPA symbol. After the fix: Suppress, so the
    // user sees nothing happen instead of losing their text.
    assert_eq!(
        decide_key_action(true, true, false, false, KC_SLASH),
        KeyAction::Suppress,
    );
    // With IPA off we don't interfere — macOS does whatever it does.
    assert_eq!(
        decide_key_action(false, true, false, false, KC_SLASH),
        KeyAction::PassThrough,
    );
}

// --- Exhaustive sweep: every keycode 0..=130 under IPA-on, Ctrl-only ---

#[test]
fn exhaustive_ctrl_keycode_sweep_ipa_on() {
    // Invariants under (IPA on, Ctrl held):
    //   - kc=49 (Space) → ToggleIpa
    //   - kc maps to a letter → TryCycle (engine decides if that injects or suppresses)
    //   - kc is printable but no letter → Suppress
    //   - kc is non-printable (navigation/function) → PassThrough
    for kc in 0u16..=130 {
        let action = decide_key_action(true, true, false, false, kc);
        match action {
            KeyAction::ToggleIpa => assert_eq!(kc, KC_SPACE),
            KeyAction::TryCycle(letter) => {
                assert_eq!(
                    keycode_to_letter(kc),
                    Some(letter),
                    "TryCycle('{letter}') but keycode_to_letter(kc={kc}) disagrees"
                );
            }
            KeyAction::Suppress => {
                assert!(
                    is_printable_character_key(kc),
                    "Suppress at non-printable keycode {kc}"
                );
                assert!(
                    keycode_to_letter(kc).is_none(),
                    "Suppress at keycode {kc} that maps to a letter — should be TryCycle"
                );
            }
            KeyAction::PassThrough => {
                assert!(
                    !is_printable_character_key(kc) && kc != KC_SPACE,
                    "keycode {kc} is printable but PassThrough under Ctrl"
                );
            }
            KeyAction::ResetAndPassThrough => {
                panic!("ResetAndPassThrough should only fire without Ctrl, got at kc={kc}");
            }
        }
    }
}

#[test]
fn exhaustive_end_to_end_sweep_ipa_on_ctrl() {
    // Stronger guarantee: for EVERY keycode under Ctrl while IPA is on,
    // the final observable must be one of:
    //   - PassThrough (navigation keys only)
    //   - ToggleIpa (Ctrl+Space only)
    //   - InjectSymbol (Ctrl+{a,e,i,o,u,t,s,d,c,n,z})
    //   - Suppress (everything else — never a spurious text mutation)
    let mut engine = default_engine();
    for kc in 0u16..=130 {
        engine.reset();
        let obs = resolve(&mut engine, true, true, kc);
        match obs {
            Observable::ToggleIpa => assert_eq!(kc, KC_SPACE),
            Observable::PassThrough => assert!(
                !is_printable_character_key(kc) && kc != KC_SPACE,
                "printable keycode {kc} leaked through under Ctrl+IPA-on"
            ),
            Observable::InjectSymbol(_) => {
                // Must be one of the 11 mapped keycodes.
                let letter = keycode_to_letter(kc).expect("inject implies letter mapping");
                assert!(
                    MAPPED_LETTERS.contains(&letter.to_string().as_str()),
                    "InjectSymbol at keycode {kc} (letter '{letter}') not in spec"
                );
            }
            Observable::Suppress => {
                // Suppress is always safe — no text mutation visible to user.
            }
        }
    }
}

// --- Exhaustive sweep: every keycode 0..=130 under IPA-off, Ctrl-only ---

#[test]
fn exhaustive_ctrl_keycode_sweep_ipa_off() {
    // IPA off: only Ctrl+Space is special; everything else passes through.
    for kc in 0u16..=130 {
        let action = decide_key_action(false, true, false, false, kc);
        let expected = if kc == KC_SPACE {
            KeyAction::ToggleIpa
        } else {
            KeyAction::PassThrough
        };
        assert_eq!(action, expected, "IPA off, Ctrl+keycode {kc}");
    }
}

// --- Shift is transparent — it doesn't alter the decision ---

#[test]
fn shift_state_does_not_affect_decision() {
    // decide_key_action takes no shift flag; capital vs lowercase letters
    // share a keycode and are handled the same way. Verify the assumption.
    assert_eq!(
        decide_key_action(true, true, false, false, KC_A),
        KeyAction::TryCycle('a'),
    );
    // Shift+A would arrive as same keycode with a shift flag (not tracked
    // by the decision function). The engine's case_insensitive_lookup test
    // above covers the letter-case handling.
}
