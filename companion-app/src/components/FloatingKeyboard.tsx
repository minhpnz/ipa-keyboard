import { useCallback, useState } from "react";
import { emit } from "@tauri-apps/api/event";
import { getCurrentWebviewWindow } from "@tauri-apps/api/webviewWindow";
import { VirtualKeyboard } from "./VirtualKeyboard";
import { useFrequencyTracker } from "../hooks/useFrequencyTracker";
import "../App.css";
import "../styles/floating.css";

export function FloatingKeyboard() {
  const { trackSymbol } = useFrequencyTracker();
  const [pinned, setPinned] = useState(true);

  const handleSymbolClick = useCallback(
    (symbol: string) => {
      emit("insert-symbol", symbol);
      trackSymbol(symbol);
    },
    [trackSymbol]
  );

  const togglePin = useCallback(async () => {
    try {
      const win = getCurrentWebviewWindow();
      const newPinned = !pinned;
      await win.setAlwaysOnTop(newPinned);
      setPinned(newPinned);
    } catch (e) {
      console.error("Failed to toggle always-on-top:", e);
    }
  }, [pinned]);

  return (
    <div className="floating-container">
      <div className="floating-header">
        <span className="floating-title">IPA Keyboard</span>
        <button
          className={`pin-btn${pinned ? " pinned" : ""}`}
          onClick={togglePin}
          title={pinned ? "Unpin from top" : "Pin to always stay on top"}
        >
          {pinned ? "Pinned" : "Unpinned"}
        </button>
      </div>
      <VirtualKeyboard
        onSymbolClick={handleSymbolClick}
      />
    </div>
  );
}
