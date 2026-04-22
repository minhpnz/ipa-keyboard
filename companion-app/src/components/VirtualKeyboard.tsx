import { useState } from "react";
import { SymbolGroup } from "./SymbolGroup";
import ipaSymbols from "../data/ipa-symbols.json";
import "../styles/keyboard.css";

type ViewMode = "keyboard" | "chart";

interface PhoneticSymbol {
  symbol: string;
  example: string;
  number: number;
}

interface VirtualKeyboardProps {
  onSymbolClick: (symbol: string) => void;
  pinned?: boolean;
  onTogglePin?: () => void;
}

function PhoneticCell({ item, onClick }: { item: PhoneticSymbol; onClick: (s: string) => void }) {
  return (
    <button
      className="phonetic-cell"
      onClick={() => onClick(item.symbol)}
      title={`${item.symbol} — ${item.example}`}
    >
      <span className="phonetic-number">{item.number}</span>
      <span className="phonetic-symbol">{item.symbol}</span>
      <span className="phonetic-example">{item.example}</span>
    </button>
  );
}

export function VirtualKeyboard({
  onSymbolClick,
  pinned,
  onTogglePin,
}: VirtualKeyboardProps) {
  const [view, setView] = useState<ViewMode>("keyboard");

  const vowels = ipaSymbols.vowels as {
    monophthongs: PhoneticSymbol[];
    diphthongs: PhoneticSymbol[];
  };
  const consonants = ipaSymbols.consonants as Record<string, PhoneticSymbol[]>;
  const letterGroups = ipaSymbols.letterGroups as Record<string, string[]>;
  return (
    <div className="virtual-keyboard">
      {/* Navigation tabs */}
      <div className="keyboard-nav">
        <span className="keyboard-nav-label">IPA chart:</span>
        {(["keyboard", "chart"] as ViewMode[]).map((v) => (
          <button
            key={v}
            className={`nav-btn${view === v ? " active" : ""}`}
            onClick={() => setView(v)}
          >
            {v === "keyboard" ? "Keyboard" : "Phonetic Chart"}
          </button>
        ))}
        {onTogglePin && (
          <button
            className={`pin-btn${pinned ? " pinned" : ""}`}
            onClick={onTogglePin}
            title={pinned ? "Unpin from always on top" : "Pin to always stay on top"}
          >
            {pinned ? "Pinned" : "Pin"}
          </button>
        )}
      </div>

      {/* Phonetic Chart View */}
      {view === "chart" && (
        <div className="phonetic-chart">
          {/* Vowels */}
          <div className="chart-section">
            <div className="chart-section-header">
              <span className="chart-section-label">Vowels</span>
            </div>
            <div className="chart-subsection">
              <span className="chart-subsection-label">Monophthongs</span>
              <div className="phonetic-grid">
                {vowels.monophthongs.map((item) => (
                  <PhoneticCell key={item.number} item={item} onClick={onSymbolClick} />
                ))}
              </div>
            </div>
            <div className="chart-subsection">
              <span className="chart-subsection-label">Diphthongs</span>
              <div className="phonetic-grid">
                {vowels.diphthongs.map((item) => (
                  <PhoneticCell key={item.number} item={item} onClick={onSymbolClick} />
                ))}
              </div>
            </div>
          </div>

          {/* Consonants */}
          <div className="chart-section">
            <div className="chart-section-header">
              <span className="chart-section-label">Consonants</span>
            </div>
            {Object.entries(consonants).map(([category, items]) => (
              <div key={category} className="chart-subsection">
                <span className="chart-subsection-label">
                  {category.charAt(0).toUpperCase() + category.slice(1)}
                </span>
                <div className="phonetic-grid">
                  {items.map((item) => (
                    <PhoneticCell key={item.number} item={item} onClick={onSymbolClick} />
                  ))}
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Keyboard (letter groups) */}
      {view === "keyboard" && (
        <div className="keyboard-grid">
          {Object.entries(letterGroups).map(([letter, symbols]) => (
            <SymbolGroup
              key={letter}
              letter={letter}
              symbols={symbols}
              onSymbolClick={onSymbolClick}
            />
          ))}
        </div>
      )}
    </div>
  );
}
