import { useState, useCallback, useEffect } from "react";

const STORAGE_KEY = "ipa-keyboard-frequency";
const MAX_FAVORITES = 20;

interface FrequencyData {
  counts: Record<string, number>;
  favorites: string[];
}

function loadData(): FrequencyData {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (raw) return JSON.parse(raw);
  } catch {
    // ignore
  }
  return { counts: {}, favorites: [] };
}

function saveData(data: FrequencyData) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(data));
}

export function useFrequencyTracker() {
  const [data, setData] = useState<FrequencyData>(loadData);

  useEffect(() => {
    saveData(data);
  }, [data]);

  const trackSymbol = useCallback((symbol: string) => {
    setData((prev) => ({
      ...prev,
      counts: {
        ...prev.counts,
        [symbol]: (prev.counts[symbol] ?? 0) + 1,
      },
    }));
  }, []);

  const toggleFavorite = useCallback((symbol: string) => {
    setData((prev) => {
      const isFav = prev.favorites.includes(symbol);
      return {
        ...prev,
        favorites: isFav
          ? prev.favorites.filter((s) => s !== symbol)
          : prev.favorites.length < MAX_FAVORITES
            ? [...prev.favorites, symbol]
            : prev.favorites,
      };
    });
  }, []);

  const isFavorite = useCallback(
    (symbol: string) => data.favorites.includes(symbol),
    [data.favorites]
  );

  const topSymbols = Object.entries(data.counts)
    .sort(([, a], [, b]) => b - a)
    .slice(0, MAX_FAVORITES)
    .map(([symbol]) => symbol);

  return {
    favorites: data.favorites,
    topSymbols,
    trackSymbol,
    toggleFavorite,
    isFavorite,
  };
}
