# IPA Keyboard — Project Instructions

## What This Project Is

A **system-wide IPA (International Phonetic Alphabet) Input Method Editor** with a **companion desktop app**.

Two components:
1. **IME Core** — Native OS input method (TSF on Windows, InputMethodKit on macOS) that intercepts keystrokes and transforms them into IPA symbols. Works in all apps (Chrome, Word, VSCode, etc.)
2. **Companion App** — Tauri + React desktop app providing a visual on-screen keyboard, settings UI, symbol browser, and document management.

## Architecture

```
┌─────────────────────┐
│   Companion App     │
│ (React + Tauri)     │
│  - Visual keyboard  │
│  - Settings/config  │
│  - Document mgmt    │
│  - Favorites        │
└────────┬────────────┘
         │ (IPC: shared config JSON file)
         ▼
┌─────────────────────┐
│      IME Core       │
│  (TSF / IMK)        │
│  - Key interception │
│  - Mapping engine   │
│  - Cycle engine     │
│  - Composition buf  │
└────────┬────────────┘
         ▼
   All apps (Chrome, Word, VSCode…)
```

## Target Platforms

| Component | Windows | macOS |
|-----------|---------|-------|
| IME Core | Rust + COM (TSF) | Swift (InputMethodKit) |
| Companion App | Tauri (.msi) | Tauri (.app) |
| IPC | Shared JSON config file | Shared JSON config file |

## Core Behavior

- **Ctrl+Space** toggles IPA input mode on/off (standard IME toggle)
- **Ctrl+letter** cycles IPA variants (e.g. Ctrl+B → β → ɓ → ʙ)
- Normal keyboard works normally when IME is active (only Ctrl+key triggers IPA)
- Visual keyboard in companion app allows clicking to insert rare symbols
- Composition buffer for multi-key sequences (v2: e.g. t+h → θ)

## Constraints (Non-Negotiable)

- **OS-approved APIs only** — TSF (Windows), IMK (macOS). No raw hooks.
- **Offline-first** — No network calls, no telemetry, no external dependencies
- **Code signing required** — Windows EV cert + macOS Developer ID + notarization
- **No dynamic code execution** — No eval, no remote code loading
- **Free distribution** — No monetization, no accounts, no cloud sync

## Data

- IPA symbol dataset: ~600 symbols, bundled as static JSON
- Documents saved as **UTF-8 .txt files**
- Config and favorites stored in local JSON (OS app data directory)
- Rich text formatting (B/I/U) is editor-only, not persisted in saved files

## Target Users

- Linguistics students, professional linguists, language learners
- Progressive disclosure: simple defaults, full IPA chart accessible

## Recommended Fonts

- **Windows**: Segoe UI, Cambria, Calibri, Arial, Times New Roman
- **macOS**: Lucida Grande, Arial, Times New Roman

## Development Conventions

- Rust for shared logic (mapping engine, symbol data)
- React + TypeScript for companion app frontend
- Swift for macOS IME
- All config files are JSON
- Use `shared-config/` for schemas shared between IME and companion app
