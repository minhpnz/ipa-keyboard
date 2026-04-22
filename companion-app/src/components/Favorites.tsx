import "../styles/keyboard.css";

interface FavoritesProps {
  favorites: string[];
  topSymbols: string[];
  onSymbolClick: (symbol: string) => void;
  onRemoveFavorite: (symbol: string) => void;
}

export function Favorites({
  favorites,
  topSymbols,
  onSymbolClick,
  onRemoveFavorite,
}: FavoritesProps) {
  // Merge: favorites first, then top symbols not already in favorites
  const combined = [
    ...favorites,
    ...topSymbols.filter((s) => !favorites.includes(s)),
  ].slice(0, 20);

  if (combined.length === 0) return null;

  return (
    <div className="favorites-bar">
      <span className="favorites-label">Favorites:</span>
      {combined.map((symbol, i) => (
        <button
          key={`${symbol}-${i}`}
          className={`symbol-btn favorite-btn${favorites.includes(symbol) ? " pinned" : ""}`}
          onClick={() => onSymbolClick(symbol)}
          onContextMenu={(e) => {
            e.preventDefault();
            onRemoveFavorite(symbol);
          }}
          title={`${symbol} — right-click to ${favorites.includes(symbol) ? "unpin" : "pin"}`}
        >
          {symbol}
        </button>
      ))}
    </div>
  );
}
