import "../styles/keyboard.css";

interface SymbolGroupProps {
  letter: string;
  symbols: string[];
  onSymbolClick: (symbol: string) => void;
}

export function SymbolGroup({
  letter,
  symbols,
  onSymbolClick,
}: SymbolGroupProps) {
  return (
    <div className="symbol-group">
      <span className="symbol-group-trigger">{letter}</span>
      {symbols.map((symbol, i) => (
        <button
          key={`${symbol}-${i}`}
          className="symbol-btn"
          onClick={() => onSymbolClick(symbol)}
          title={symbol}
        >
          {symbol}
        </button>
      ))}
    </div>
  );
}
