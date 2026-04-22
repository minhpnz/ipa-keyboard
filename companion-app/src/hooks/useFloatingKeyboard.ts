import { useState, useCallback, useEffect } from "react";
import { WebviewWindow } from "@tauri-apps/api/webviewWindow";
import { listen } from "@tauri-apps/api/event";

export function useFloatingKeyboard(onSymbolFromFloat: (symbol: string) => void) {
  const [isFloating, setIsFloating] = useState(false);

  // Listen for symbols sent from the floating window
  useEffect(() => {
    const unlisten = listen<string>("insert-symbol", (event) => {
      onSymbolFromFloat(event.payload);
    });
    return () => {
      unlisten.then((fn) => fn());
    };
  }, [onSymbolFromFloat]);

  const toggleFloating = useCallback(async () => {
    if (isFloating) {
      const floatWin = await WebviewWindow.getByLabel("keyboard-float");
      if (floatWin) {
        try {
          await floatWin.close();
        } catch {
          // window may already be closed
        }
      }
      setIsFloating(false);
    } else {
      // Build URL from current origin so it works in both dev and production
      const baseUrl = window.location.origin;
      const floatUrl = `${baseUrl}/?floating=true`;

      const floatWin = new WebviewWindow("keyboard-float", {
        url: floatUrl,
        title: "IPA Keyboard",
        width: 900,
        height: 450,
        minWidth: 600,
        minHeight: 300,
        alwaysOnTop: true,
        decorations: true,
        resizable: true,
      });

      floatWin.once("tauri://error", (e) => {
        console.error("Failed to create floating window:", e);
        setIsFloating(false);
      });

      floatWin.once("tauri://destroyed", () => {
        setIsFloating(false);
      });

      setIsFloating(true);
    }
  }, [isFloating]);

  return { isFloating, toggleFloating };
}
