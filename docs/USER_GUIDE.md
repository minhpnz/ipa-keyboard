# IPA Keyboard — User Guide

Type IPA (International Phonetic Alphabet) symbols into any app on your Mac using simple keyboard shortcuts. 22 keys cover all 44 English phonemes.

## Installation

1. Download **IPA-Keyboard.dmg**
2. Open the DMG and drag **IPA Keyboard** to Applications
3. Launch IPA Keyboard
4. **Grant Accessibility permission** when prompted:
   - Click "Open System Settings"
   - In **Privacy & Security > Accessibility**, toggle on **IPA Keyboard**
   - The app detects the permission automatically and starts working
5. The IPA tray icon appears in your menu bar

## How It Works

- Hold **Ctrl** + press a letter → types an IPA symbol
- Press the same letter again (still holding Ctrl) → cycles to next variant
- Release Ctrl → cycle resets after ~800ms
- Press **Ctrl + Space** → toggle IPA mode on/off

When IPA mode is off, your keyboard works completely normally.

## Quick Reference

### Vowels

| Shortcut | 1st | 2nd | 3rd | 4th |
|----------|-----|-----|-----|-----|
| Ctrl+A | **æ** (cat) | **ɑ** (father) | **ɑː** (far) | **ʌ** (cup) |
| Ctrl+E | **e** (bed) | **ə** (about) | **ɜː** (bird) | |
| Ctrl+I | **ɪ** (sit) | **iː** (see) | | |
| Ctrl+O | **ɒ** (hot) | **ɔ** (law) | **ɔː** (door) | |
| Ctrl+U | **ʊ** (put) | **uː** (too) | | |

### Consonants with Variants

| Shortcut | 1st | 2nd | 3rd |
|----------|-----|-----|-----|
| Ctrl+T | **t** | **θ** (think) | **ð** (this) |
| Ctrl+S | **s** | **ʃ** (ship) | **ʒ** (measure) |
| Ctrl+D | **d** | **dʒ** (judge) | |
| Ctrl+C | **k** | **tʃ** (chip) | |
| Ctrl+N | **n** | **ŋ** (sing) | |

### Single Consonants

| Shortcut | Symbol | | Shortcut | Symbol |
|----------|--------|-|----------|--------|
| Ctrl+R | **r** | | Ctrl+B | **b** |
| Ctrl+L | **l** | | Ctrl+P | **p** |
| Ctrl+H | **h** | | Ctrl+G | **g** |
| Ctrl+M | **m** | | Ctrl+Z | **z** |
| Ctrl+F | **f** | | Ctrl+W | **w** |
| Ctrl+V | **v** | | Ctrl+J | **j** |

## Example Transcriptions

| Word | IPA | How to type |
|------|-----|-------------|
| cat | /kæt/ | Ctrl+C Ctrl+A Ctrl+T |
| think | /θɪŋk/ | Ctrl+T×2 Ctrl+I Ctrl+N×2 Ctrl+C |
| ship | /ʃɪp/ | Ctrl+S×2 Ctrl+I Ctrl+P |
| measure | /meʒə/ | Ctrl+M Ctrl+E Ctrl+S×3 Ctrl+E×2 |
| church | /tʃɜːtʃ/ | Ctrl+C×2 Ctrl+E×3 Ctrl+C×2 |

(×2 means press twice to cycle to the 2nd symbol, ×3 for 3rd)

## Menu Bar

The **IPA** icon in your menu bar provides:
- **Disable/Enable IPA Input** — toggle without Ctrl+Space
- **Show IPA Keyboard** — bring the companion app window to front
- **Uninstall** — removes the app, daemon, and settings
- **Quit** — stops everything

## Companion App Features

- **Phonetic Chart** — click any symbol to insert into the editor
- **All Symbols** — browse all 22 key groups and their IPA variants
- **Diacritics** — tone marks, stress, length, and other modifiers
- **Favorites** — right-click any symbol to add to your favorites bar
- **Document editor** — write and save IPA transcriptions (Ctrl+S to save)
- **Dark/Light mode** — toggle in the toolbar
- **Detachable keyboard** — float the symbol keyboard in a separate window

## Tips

- Cycling wraps around: pressing past the last variant returns to the first
- Cmd+C, Cmd+V, Option+key are never intercepted — only Ctrl+letter
- Works in every app: Chrome, Safari, Word, VSCode, Notes, Terminal, Messages
- Custom mappings: place a `config.json` in `~/Library/Application Support/ipa-keyboard/`

## Troubleshooting

### Ctrl+letter doesn't produce IPA symbols
1. Check Accessibility permission: **System Settings > Privacy & Security > Accessibility** — IPA Keyboard must be toggled on
2. If you updated the app, you may need to re-grant permission (the binary hash changed)
3. Toggle IPA mode: press **Ctrl+Space** (it might be off)
4. Restart: click tray icon > Quit, then reopen the app

### Permission not being detected
- Remove IPA Keyboard from the Accessibility list, then re-add it
- Make sure you're adding the correct app (from Applications, not Downloads)

### App doesn't appear in menu bar
- Check Activity Monitor for "ipa-keyboard" processes
- Relaunch from Applications

### Symbols appear as boxes or question marks
- Your font doesn't support IPA characters
- Recommended fonts: Lucida Grande, Arial, Times New Roman, Charis SIL

## Uninstalling

From the menu bar icon: click **Uninstall**. This stops the daemon, removes settings, and moves the app to Trash.

Or manually:
1. Click tray icon > **Quit**
2. Delete IPA Keyboard from Applications
3. Remove settings: `rm -rf ~/Library/Application\ Support/ipa-keyboard`
