import { useState, useEffect, useCallback, useRef } from "react";
import "../styles/candidate.css";

interface CandidatePopupProps {
  /** The list of candidate symbols to display. Empty = hidden. */
  candidates: string[];
  /** Called when a candidate is selected (clicked or Enter). */
  onSelect: (symbol: string) => void;
  /** Called when the popup is dismissed (Escape or blur). */
  onDismiss: () => void;
  /** Position hint — pixel coordinates relative to the editor. */
  position?: { x: number; y: number };
}

/**
 * A floating candidate selection popup, similar to Chinese/Japanese IME.
 * Supports arrow key navigation and Enter to commit.
 */
export function CandidatePopup({
  candidates,
  onSelect,
  onDismiss,
  position,
}: CandidatePopupProps) {
  const [selectedIndex, setSelectedIndex] = useState(0);
  const popupRef = useRef<HTMLDivElement>(null);

  // Reset selection when candidates change
  useEffect(() => {
    setSelectedIndex(0);
  }, [candidates]);

  const handleKeyDown = useCallback(
    (e: KeyboardEvent) => {
      if (candidates.length === 0) return;

      switch (e.key) {
        case "ArrowDown":
          e.preventDefault();
          setSelectedIndex((i) => (i + 1) % candidates.length);
          break;
        case "ArrowUp":
          e.preventDefault();
          setSelectedIndex((i) => (i - 1 + candidates.length) % candidates.length);
          break;
        case "Enter":
          e.preventDefault();
          onSelect(candidates[selectedIndex]);
          break;
        case "Escape":
          e.preventDefault();
          onDismiss();
          break;
        case "1": case "2": case "3": case "4": case "5":
        case "6": case "7": case "8": case "9": {
          const num = parseInt(e.key) - 1;
          if (num < candidates.length) {
            e.preventDefault();
            onSelect(candidates[num]);
          }
          break;
        }
      }
    },
    [candidates, selectedIndex, onSelect, onDismiss]
  );

  useEffect(() => {
    if (candidates.length === 0) return;
    window.addEventListener("keydown", handleKeyDown, true);
    return () => window.removeEventListener("keydown", handleKeyDown, true);
  }, [candidates, handleKeyDown]);

  if (candidates.length === 0) return null;

  const style: React.CSSProperties = position
    ? { left: position.x, top: position.y }
    : {};

  return (
    <div ref={popupRef} className="candidate-popup" style={style}>
      {candidates.map((symbol, i) => (
        <button
          key={`${symbol}-${i}`}
          className={`candidate-item ${i === selectedIndex ? "selected" : ""}`}
          onClick={() => onSelect(symbol)}
          onMouseEnter={() => setSelectedIndex(i)}
        >
          <span className="candidate-number">{i + 1}</span>
          <span className="candidate-symbol">{symbol}</span>
        </button>
      ))}
    </div>
  );
}
