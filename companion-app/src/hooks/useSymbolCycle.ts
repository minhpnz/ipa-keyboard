import { useCallback, useRef } from "react";
import { MAPPINGS, CYCLE_TIMEOUT_MS, SEQUENCES } from "../data/default-mappings";

interface CycleState {
  key: string;
  index: number;
  timestamp: number;
}

interface CompositionState {
  buffer: string;
  timestamp: number;
}

const MAX_SEQ_LEN = Math.max(...Object.keys(SEQUENCES).map((k) => k.length), 0);
const COMPOSITION_TIMEOUT_MS = 1500;

/**
 * Hook for Ctrl+key IPA symbol cycling and multi-key sequence composition.
 *
 * Cycling: Ctrl+B pressed once → β, twice quickly → ɓ, three times → ʙ, etc.
 * Sequences: Typing "th" quickly (without Ctrl) while in composition mode → θ.
 *
 * @param onSymbol - callback receiving (symbol, isReplace).
 *   isReplace=true means the previous symbol should be replaced (cycling).
 *   isReplace=false means this is a fresh insertion.
 * @param onCompositionChange - optional callback for composition preview text.
 */
export function useSymbolCycle(
  onSymbol: (symbol: string, isReplace: boolean) => void,
  onCompositionChange?: (preview: string) => void
) {
  const cycleRef = useRef<CycleState | null>(null);
  const compRef = useRef<CompositionState | null>(null);

  const handleKeyDown = useCallback(
    (e: React.KeyboardEvent<HTMLElement> | KeyboardEvent) => {
      // --- Ctrl+key cycling ---
      if (e.ctrlKey || e.metaKey) {
        const key = e.key.toLowerCase();
        const symbols = MAPPINGS[key];
        if (!symbols || symbols.length === 0) return;

        e.preventDefault();
        // Clear composition state when using Ctrl cycling
        compRef.current = null;
        onCompositionChange?.("");

        const now = Date.now();
        const prev = cycleRef.current;

        let index: number;
        let isReplace: boolean;

        if (prev && prev.key === key && now - prev.timestamp < CYCLE_TIMEOUT_MS) {
          index = (prev.index + 1) % symbols.length;
          isReplace = true;
        } else {
          index = 0;
          isReplace = false;
        }

        cycleRef.current = { key, index, timestamp: now };
        onSymbol(symbols[index], isReplace);
        return;
      }

      // --- Multi-key sequence composition (no modifier) ---
      if (MAX_SEQ_LEN === 0) return;
      if (e.key.length !== 1 || e.altKey) return;

      const ch = e.key.toLowerCase();
      // Only compose alphabetic characters
      if (!/^[a-z]$/.test(ch)) {
        // Non-alpha key: flush composition
        if (compRef.current) {
          compRef.current = null;
          onCompositionChange?.("");
        }
        return;
      }

      const now = Date.now();
      const prev = compRef.current;

      // Reset composition if timed out
      let buffer: string;
      if (prev && now - prev.timestamp < COMPOSITION_TIMEOUT_MS) {
        buffer = prev.buffer + ch;
      } else {
        buffer = ch;
      }

      // Trim to max sequence length
      if (buffer.length > MAX_SEQ_LEN) {
        buffer = buffer.slice(buffer.length - MAX_SEQ_LEN);
      }

      // Try longest match
      for (let len = Math.min(buffer.length, MAX_SEQ_LEN); len >= 2; len--) {
        const suffix = buffer.slice(buffer.length - len);
        const symbol = SEQUENCES[suffix];
        if (symbol) {
          e.preventDefault();
          // Replace the previously typed characters with the symbol.
          // consumed = len - 1 because current char hasn't been inserted yet.
          // We need to delete len-1 chars already in the editor, then insert symbol.
          onSymbol(symbol, false);
          compRef.current = null;
          onCompositionChange?.("");
          // Clear cycle state too
          cycleRef.current = null;
          return;
        }
      }

      // Check if buffer is a prefix of any sequence
      const isPrefix = Object.keys(SEQUENCES).some((seq) => seq.startsWith(buffer));
      if (isPrefix) {
        compRef.current = { buffer, timestamp: now };
        onCompositionChange?.(buffer);
      } else {
        compRef.current = null;
        onCompositionChange?.("");
      }
    },
    [onSymbol, onCompositionChange]
  );

  const reset = useCallback(() => {
    cycleRef.current = null;
    compRef.current = null;
    onCompositionChange?.("");
  }, [onCompositionChange]);

  return { handleKeyDown, reset };
}
