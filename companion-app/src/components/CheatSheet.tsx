import { useEffect } from "react";
import "../styles/cheatsheet.css";

interface CheatSheetProps {
  visible: boolean;
  onClose: () => void;
}

const SHORTCUTS = [
  { keys: ["Ctrl", "Letter"], desc: "Cycle IPA symbols for that letter" },
  { keys: ["Ctrl", "Space"], desc: "Toggle IPA input mode (IME)" },
  { keys: ["Ctrl", "S"], desc: "Save document" },
  { keys: ["Ctrl", "N"], desc: "New document" },
  { keys: ["Ctrl", "Z"], desc: "Undo" },
  { keys: ["Ctrl", "Shift", "Z"], desc: "Redo" },
  { keys: ["?"], desc: "Show/hide this cheat sheet" },
];

const KEY_MAPPINGS = [
  { key: "A", symbols: "æ → ʌ → ɑː" },
  { key: "E", symbols: "ə → ɜː" },
  { key: "I", symbols: "ɪ → iː" },
  { key: "O", symbols: "ɒ → ɔː" },
  { key: "U", symbols: "ʊ → uː" },
  { key: "T", symbols: "θ → ð" },
  { key: "S", symbols: "ʃ" },
  { key: "D", symbols: "dʒ" },
  { key: "C", symbols: "tʃ" },
  { key: "N", symbols: "ŋ" },
  { key: "Z", symbols: "ʒ" },
];

export function CheatSheet({ visible, onClose }: CheatSheetProps) {
  useEffect(() => {
    if (!visible) return;
    const handler = (e: KeyboardEvent) => {
      if (e.key === "Escape" || e.key === "?") {
        e.preventDefault();
        onClose();
      }
    };
    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, [visible, onClose]);

  if (!visible) return null;

  return (
    <div className="cheatsheet-overlay" onClick={onClose}>
      <div className="cheatsheet-modal" onClick={(e) => e.stopPropagation()}>
        <div className="cheatsheet-header">
          <h2>Keyboard Shortcuts</h2>
          <button className="cheatsheet-close" onClick={onClose}>
            &times;
          </button>
        </div>

        <div className="cheatsheet-body">
          <section className="cheatsheet-section">
            <h3>General</h3>
            <table className="cheatsheet-table">
              <tbody>
                {SHORTCUTS.map((s, i) => (
                  <tr key={i}>
                    <td className="cheatsheet-keys">
                      {s.keys.map((k, j) => (
                        <span key={j}>
                          <kbd>{k}</kbd>
                          {j < s.keys.length - 1 && " + "}
                        </span>
                      ))}
                    </td>
                    <td className="cheatsheet-desc">{s.desc}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </section>

          <section className="cheatsheet-section">
            <h3>Ctrl + Key Mappings</h3>
            <p className="cheatsheet-hint">
              Hold Ctrl and press the key repeatedly to cycle through symbols:
            </p>
            <table className="cheatsheet-table">
              <tbody>
                {KEY_MAPPINGS.map((m, i) => (
                  <tr key={i}>
                    <td className="cheatsheet-keys">
                      <kbd>Ctrl + {m.key}</kbd>
                    </td>
                    <td className="cheatsheet-desc">{m.symbols}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </section>
        </div>
      </div>
    </div>
  );
}
