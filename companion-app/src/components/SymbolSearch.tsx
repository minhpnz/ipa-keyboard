import { useState, useMemo } from "react";
import { IPA_SYMBOL_NAMES, SymbolMeta } from "../data/ipa-names";
import "../styles/keyboard.css";

interface SymbolSearchProps {
  onSymbolClick: (symbol: string) => void;
}

interface SearchResult {
  meta: SymbolMeta;
  score: number;
}

/**
 * Fuzzy match: returns a score (lower = better) or -1 for no match.
 * Checks if all characters in the query appear in order in the target.
 */
function fuzzyMatch(query: string, target: string): number {
  let qi = 0;
  let score = 0;
  let lastMatch = -1;

  for (let ti = 0; ti < target.length && qi < query.length; ti++) {
    if (target[ti] === query[qi]) {
      // Bonus for consecutive matches
      score += ti - lastMatch === 1 ? 0 : ti - lastMatch;
      lastMatch = ti;
      qi++;
    }
  }

  return qi === query.length ? score : -1;
}

function searchSymbols(query: string): SearchResult[] {
  const q = query.toLowerCase().trim();
  if (!q) return [];

  const results: SearchResult[] = [];

  // Check if query looks like a codepoint (U+xxxx or just hex)
  const codepointMatch = q.match(/^u\+?([0-9a-f]{2,6})$/i);

  for (const meta of IPA_SYMBOL_NAMES) {
    let score = -1;

    // 1. Exact symbol match (highest priority)
    if (meta.symbol === query || meta.symbol.toLowerCase() === q) {
      score = 0;
    }
    // 2. Codepoint search
    else if (codepointMatch) {
      const hex = codepointMatch[1].toUpperCase();
      if (meta.codepoint.includes(hex)) {
        score = 5;
      }
    }
    // 3. Exact substring in name
    else if (meta.name.includes(q)) {
      score = 10 + meta.name.indexOf(q);
    }
    // 4. Keyword match
    else if (meta.keywords.some((kw) => kw.includes(q))) {
      score = 20;
    }
    // 5. Fuzzy match on name
    else {
      const f = fuzzyMatch(q, meta.name);
      if (f >= 0) {
        score = 50 + f;
      }
    }

    if (score >= 0) {
      results.push({ meta, score });
    }
  }

  results.sort((a, b) => a.score - b.score);
  return results.slice(0, 30);
}

export function SymbolSearch({ onSymbolClick }: SymbolSearchProps) {
  const [query, setQuery] = useState("");
  const results = useMemo(() => searchSymbols(query), [query]);

  return (
    <div className="symbol-search">
      <input
        type="text"
        className="search-input"
        placeholder="Search by name, keyword, or codepoint (e.g. schwa, bilabial, U+0259)..."
        value={query}
        onChange={(e) => setQuery(e.target.value)}
      />
      {results.length > 0 && (
        <div className="search-results">
          {results.map(({ meta }, i) => (
            <button
              key={`${meta.symbol}-${i}`}
              className="symbol-btn search-result-btn"
              onClick={() => {
                onSymbolClick(meta.symbol);
                setQuery("");
              }}
              title={`${meta.name}\n${meta.codepoint}`}
            >
              <span className="search-symbol">{meta.symbol}</span>
              <span className="search-name">{meta.name}</span>
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
