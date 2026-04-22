import { useCallback, useState, useEffect } from "react";
import { VirtualKeyboard } from "./components/VirtualKeyboard";
import { getCurrentWebviewWindow } from "@tauri-apps/api/webviewWindow";
import "./App.css";

function App() {
  const [pinned, setPinned] = useState(false);

  const togglePin = useCallback(async () => {
    const win = getCurrentWebviewWindow();
    const next = !pinned;
    await win.setAlwaysOnTop(next);
    setPinned(next);
  }, [pinned]);

  // Set initial always-on-top state
  useEffect(() => {
    getCurrentWebviewWindow().setAlwaysOnTop(false);
  }, []);

  const handleSymbolClick = useCallback((_symbol: string) => {
    // Symbols are typed system-wide via the CGEvent tap
  }, []);

  return (
    <div className="app">
      <main className="app-main">
        <VirtualKeyboard
          onSymbolClick={handleSymbolClick}
          pinned={pinned}
          onTogglePin={togglePin}
        />
      </main>

      <footer className="app-footer">
        <span>
          Hold <kbd>Ctrl</kbd> + letter to cycle IPA symbols (e.g.
          Ctrl+A &rarr; &aelig; &rarr; &#593; &rarr; &#593;&#720; &rarr; &#652;)
        </span>
      </footer>
    </div>
  );
}

export default App;
