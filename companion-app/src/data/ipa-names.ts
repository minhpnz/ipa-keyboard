/**
 * IPA symbol metadata for search.
 * Maps each symbol to its official IPA name(s) and descriptive keywords.
 */
export interface SymbolMeta {
  symbol: string;
  name: string;
  keywords: string[];
  codepoint: string; // e.g. "U+0259"
}

export const IPA_SYMBOL_NAMES: SymbolMeta[] = [
  // Vowels
  { symbol: "i", name: "close front unrounded vowel", keywords: ["high", "front"], codepoint: "U+0069" },
  { symbol: "iː", name: "long close front unrounded vowel", keywords: ["high", "front", "long"], codepoint: "U+0069 U+02D0" },
  { symbol: "ɪ", name: "near-close near-front unrounded vowel", keywords: ["lax", "high"], codepoint: "U+026A" },
  { symbol: "e", name: "close-mid front unrounded vowel", keywords: ["mid", "front"], codepoint: "U+0065" },
  { symbol: "ɛ", name: "open-mid front unrounded vowel", keywords: ["mid", "front"], codepoint: "U+025B" },
  { symbol: "æ", name: "near-open front unrounded vowel", keywords: ["low", "front", "ash"], codepoint: "U+00E6" },
  { symbol: "a", name: "open front unrounded vowel", keywords: ["low", "front"], codepoint: "U+0061" },
  { symbol: "ɑ", name: "open back unrounded vowel", keywords: ["low", "back", "script a"], codepoint: "U+0251" },
  { symbol: "ɑː", name: "long open back unrounded vowel", keywords: ["low", "back", "long"], codepoint: "U+0251 U+02D0" },
  { symbol: "ɒ", name: "open back rounded vowel", keywords: ["low", "back", "rounded"], codepoint: "U+0252" },
  { symbol: "ɔ", name: "open-mid back rounded vowel", keywords: ["mid", "back", "rounded"], codepoint: "U+0254" },
  { symbol: "ɔː", name: "long open-mid back rounded vowel", keywords: ["mid", "back", "rounded", "long"], codepoint: "U+0254 U+02D0" },
  { symbol: "o", name: "close-mid back rounded vowel", keywords: ["mid", "back", "rounded"], codepoint: "U+006F" },
  { symbol: "ʊ", name: "near-close near-back rounded vowel", keywords: ["lax", "high", "rounded"], codepoint: "U+028A" },
  { symbol: "u", name: "close back rounded vowel", keywords: ["high", "back", "rounded"], codepoint: "U+0075" },
  { symbol: "uː", name: "long close back rounded vowel", keywords: ["high", "back", "rounded", "long"], codepoint: "U+0075 U+02D0" },
  { symbol: "ʌ", name: "open-mid back unrounded vowel", keywords: ["mid", "back", "caret", "strut"], codepoint: "U+028C" },
  { symbol: "ə", name: "schwa", keywords: ["mid", "central", "reduced", "unstressed"], codepoint: "U+0259" },
  { symbol: "ɚ", name: "r-coloured schwa", keywords: ["mid", "central", "rhotic"], codepoint: "U+025A" },
  { symbol: "ɜ", name: "open-mid central unrounded vowel", keywords: ["mid", "central"], codepoint: "U+025C" },
  { symbol: "ɜː", name: "long open-mid central unrounded vowel", keywords: ["mid", "central", "long", "nurse"], codepoint: "U+025C U+02D0" },
  { symbol: "ɝ", name: "r-coloured open-mid central vowel", keywords: ["mid", "central", "rhotic"], codepoint: "U+025D" },
  { symbol: "ɨ", name: "close central unrounded vowel", keywords: ["high", "central"], codepoint: "U+0268" },
  { symbol: "ʉ", name: "close central rounded vowel", keywords: ["high", "central", "rounded"], codepoint: "U+0289" },
  { symbol: "ɵ", name: "close-mid central rounded vowel", keywords: ["mid", "central", "rounded"], codepoint: "U+0275" },
  { symbol: "ɐ", name: "near-open central vowel", keywords: ["low", "central", "turned a"], codepoint: "U+0250" },
  { symbol: "ɯ", name: "close back unrounded vowel", keywords: ["high", "back"], codepoint: "U+026F" },
  { symbol: "ɤ", name: "close-mid back unrounded vowel", keywords: ["mid", "back"], codepoint: "U+0264" },
  { symbol: "ʏ", name: "near-close near-front rounded vowel", keywords: ["lax", "high", "front", "rounded"], codepoint: "U+028F" },
  { symbol: "œ", name: "open-mid front rounded vowel", keywords: ["mid", "front", "rounded"], codepoint: "U+0153" },

  // Diphthongs
  { symbol: "eɪ", name: "diphthong", keywords: ["face", "closing"], codepoint: "U+0065 U+026A" },
  { symbol: "aɪ", name: "diphthong", keywords: ["price", "closing"], codepoint: "U+0061 U+026A" },
  { symbol: "ɔɪ", name: "diphthong", keywords: ["choice", "closing"], codepoint: "U+0254 U+026A" },
  { symbol: "aʊ", name: "diphthong", keywords: ["mouth", "closing"], codepoint: "U+0061 U+028A" },
  { symbol: "əʊ", name: "diphthong", keywords: ["goat", "closing"], codepoint: "U+0259 U+028A" },
  { symbol: "ɪə", name: "diphthong", keywords: ["near", "centering"], codepoint: "U+026A U+0259" },
  { symbol: "eə", name: "diphthong", keywords: ["square", "centering"], codepoint: "U+0065 U+0259" },
  { symbol: "ʊə", name: "diphthong", keywords: ["cure", "centering"], codepoint: "U+028A U+0259" },

  // Plosives
  { symbol: "p", name: "voiceless bilabial plosive", keywords: ["stop", "bilabial"], codepoint: "U+0070" },
  { symbol: "b", name: "voiced bilabial plosive", keywords: ["stop", "bilabial"], codepoint: "U+0062" },
  { symbol: "t", name: "voiceless alveolar plosive", keywords: ["stop", "alveolar"], codepoint: "U+0074" },
  { symbol: "d", name: "voiced alveolar plosive", keywords: ["stop", "alveolar"], codepoint: "U+0064" },
  { symbol: "k", name: "voiceless velar plosive", keywords: ["stop", "velar"], codepoint: "U+006B" },
  { symbol: "g", name: "voiced velar plosive", keywords: ["stop", "velar"], codepoint: "U+0067" },
  { symbol: "ʈ", name: "voiceless retroflex plosive", keywords: ["stop", "retroflex"], codepoint: "U+0288" },
  { symbol: "ɖ", name: "voiced retroflex plosive", keywords: ["stop", "retroflex"], codepoint: "U+0256" },
  { symbol: "c", name: "voiceless palatal plosive", keywords: ["stop", "palatal"], codepoint: "U+0063" },
  { symbol: "ɟ", name: "voiced palatal plosive", keywords: ["stop", "palatal", "barred dotless j"], codepoint: "U+025F" },
  { symbol: "q", name: "voiceless uvular plosive", keywords: ["stop", "uvular"], codepoint: "U+0071" },
  { symbol: "ɢ", name: "voiced uvular plosive", keywords: ["stop", "uvular", "small capital g"], codepoint: "U+0262" },
  { symbol: "ʔ", name: "glottal stop", keywords: ["plosive", "glottal"], codepoint: "U+0294" },

  // Fricatives
  { symbol: "f", name: "voiceless labiodental fricative", keywords: ["labiodental"], codepoint: "U+0066" },
  { symbol: "v", name: "voiced labiodental fricative", keywords: ["labiodental"], codepoint: "U+0076" },
  { symbol: "θ", name: "voiceless dental fricative", keywords: ["dental", "theta", "think"], codepoint: "U+03B8" },
  { symbol: "ð", name: "voiced dental fricative", keywords: ["dental", "eth", "this"], codepoint: "U+00F0" },
  { symbol: "s", name: "voiceless alveolar fricative", keywords: ["sibilant", "alveolar"], codepoint: "U+0073" },
  { symbol: "z", name: "voiced alveolar fricative", keywords: ["sibilant", "alveolar"], codepoint: "U+007A" },
  { symbol: "ʃ", name: "voiceless postalveolar fricative", keywords: ["sibilant", "postalveolar", "esh"], codepoint: "U+0283" },
  { symbol: "ʒ", name: "voiced postalveolar fricative", keywords: ["sibilant", "postalveolar", "ezh", "yogh"], codepoint: "U+0292" },
  { symbol: "ʂ", name: "voiceless retroflex fricative", keywords: ["sibilant", "retroflex"], codepoint: "U+0282" },
  { symbol: "ʐ", name: "voiced retroflex fricative", keywords: ["sibilant", "retroflex"], codepoint: "U+0290" },
  { symbol: "ç", name: "voiceless palatal fricative", keywords: ["palatal", "c cedilla"], codepoint: "U+00E7" },
  { symbol: "ʝ", name: "voiced palatal fricative", keywords: ["palatal", "curly-tail j"], codepoint: "U+029D" },
  { symbol: "x", name: "voiceless velar fricative", keywords: ["velar"], codepoint: "U+0078" },
  { symbol: "ɣ", name: "voiced velar fricative", keywords: ["velar", "gamma"], codepoint: "U+0263" },
  { symbol: "χ", name: "voiceless uvular fricative", keywords: ["uvular", "chi"], codepoint: "U+03C7" },
  { symbol: "ʁ", name: "voiced uvular fricative", keywords: ["uvular"], codepoint: "U+0281" },
  { symbol: "ħ", name: "voiceless pharyngeal fricative", keywords: ["pharyngeal"], codepoint: "U+0127" },
  { symbol: "ʕ", name: "voiced pharyngeal fricative", keywords: ["pharyngeal", "reversed glottal"], codepoint: "U+0295" },
  { symbol: "h", name: "voiceless glottal fricative", keywords: ["glottal"], codepoint: "U+0068" },
  { symbol: "ɦ", name: "voiced glottal fricative", keywords: ["glottal", "breathy", "hooktop h"], codepoint: "U+0266" },
  { symbol: "ɕ", name: "voiceless alveolopalatal fricative", keywords: ["sibilant", "alveolopalatal", "curly-tail c"], codepoint: "U+0255" },
  { symbol: "ʑ", name: "voiced alveolopalatal fricative", keywords: ["sibilant", "alveolopalatal", "curly-tail z"], codepoint: "U+0291" },
  { symbol: "ɸ", name: "voiceless bilabial fricative", keywords: ["bilabial", "phi"], codepoint: "U+0278" },
  { symbol: "β", name: "voiced bilabial fricative", keywords: ["bilabial", "beta"], codepoint: "U+03B2" },
  { symbol: "ɧ", name: "voiceless palatal-velar fricative", keywords: ["sj-sound", "swedish"], codepoint: "U+0267" },

  // Nasals
  { symbol: "m", name: "voiced bilabial nasal", keywords: ["bilabial"], codepoint: "U+006D" },
  { symbol: "ɱ", name: "voiced labiodental nasal", keywords: ["labiodental"], codepoint: "U+0271" },
  { symbol: "n", name: "voiced alveolar nasal", keywords: ["alveolar"], codepoint: "U+006E" },
  { symbol: "ɳ", name: "voiced retroflex nasal", keywords: ["retroflex"], codepoint: "U+0273" },
  { symbol: "ɲ", name: "voiced palatal nasal", keywords: ["palatal", "left-tail n"], codepoint: "U+0272" },
  { symbol: "ŋ", name: "voiced velar nasal", keywords: ["velar", "eng", "engma"], codepoint: "U+014B" },
  { symbol: "ɴ", name: "voiced uvular nasal", keywords: ["uvular", "small capital n"], codepoint: "U+0274" },

  // Approximants & Liquids
  { symbol: "ɹ", name: "voiced alveolar approximant", keywords: ["alveolar", "turned r"], codepoint: "U+0279" },
  { symbol: "ɻ", name: "voiced retroflex approximant", keywords: ["retroflex", "turned r hook"], codepoint: "U+027B" },
  { symbol: "j", name: "voiced palatal approximant", keywords: ["palatal", "yod"], codepoint: "U+006A" },
  { symbol: "ɰ", name: "voiced velar approximant", keywords: ["velar", "turned m right leg"], codepoint: "U+0270" },
  { symbol: "w", name: "voiced labial-velar approximant", keywords: ["labiovelar", "semivowel"], codepoint: "U+0077" },
  { symbol: "ʍ", name: "voiceless labial-velar fricative", keywords: ["labiovelar", "turned w", "wh"], codepoint: "U+028D" },
  { symbol: "ɥ", name: "voiced labial-palatal approximant", keywords: ["labiopalatal", "turned h"], codepoint: "U+0265" },
  { symbol: "l", name: "voiced alveolar lateral approximant", keywords: ["lateral", "alveolar"], codepoint: "U+006C" },
  { symbol: "ɫ", name: "velarized alveolar lateral", keywords: ["lateral", "dark l"], codepoint: "U+026B" },
  { symbol: "ɭ", name: "voiced retroflex lateral", keywords: ["lateral", "retroflex"], codepoint: "U+026D" },
  { symbol: "ʎ", name: "voiced palatal lateral", keywords: ["lateral", "palatal", "turned y"], codepoint: "U+028E" },
  { symbol: "ʋ", name: "voiced labiodental approximant", keywords: ["labiodental", "script v"], codepoint: "U+028B" },

  // Trills & Taps
  { symbol: "r", name: "voiced alveolar trill", keywords: ["trill", "alveolar"], codepoint: "U+0072" },
  { symbol: "ʀ", name: "voiced uvular trill", keywords: ["trill", "uvular", "small capital r"], codepoint: "U+0280" },
  { symbol: "ʙ", name: "voiced bilabial trill", keywords: ["trill", "bilabial", "small capital b"], codepoint: "U+0299" },
  { symbol: "ɾ", name: "voiced alveolar tap", keywords: ["tap", "flap", "alveolar", "fish-hook r"], codepoint: "U+027E" },
  { symbol: "ɽ", name: "voiced retroflex flap", keywords: ["tap", "flap", "retroflex"], codepoint: "U+027D" },
  { symbol: "ɺ", name: "voiced alveolar lateral flap", keywords: ["tap", "flap", "lateral"], codepoint: "U+027A" },

  // Lateral fricatives
  { symbol: "ɬ", name: "voiceless alveolar lateral fricative", keywords: ["lateral", "fricative", "belt l"], codepoint: "U+026C" },
  { symbol: "ɮ", name: "voiced alveolar lateral fricative", keywords: ["lateral", "fricative", "lezh"], codepoint: "U+026E" },

  // Affricates
  { symbol: "t͡ʃ", name: "voiceless postalveolar affricate", keywords: ["affricate", "postalveolar", "ch"], codepoint: "U+0074 U+0361 U+0283" },
  { symbol: "d͡ʒ", name: "voiced postalveolar affricate", keywords: ["affricate", "postalveolar", "j"], codepoint: "U+0064 U+0361 U+0292" },
  { symbol: "t͡s", name: "voiceless alveolar affricate", keywords: ["affricate", "alveolar", "ts"], codepoint: "U+0074 U+0361 U+0073" },
  { symbol: "tʃ", name: "voiceless postalveolar affricate (no tie)", keywords: ["affricate", "ch"], codepoint: "U+0074 U+0283" },
  { symbol: "dʒ", name: "voiced postalveolar affricate (no tie)", keywords: ["affricate", "j"], codepoint: "U+0064 U+0292" },

  // Implosives
  { symbol: "ɓ", name: "voiced bilabial implosive", keywords: ["implosive", "bilabial", "hooktop b"], codepoint: "U+0253" },
  { symbol: "ɗ", name: "voiced alveolar implosive", keywords: ["implosive", "alveolar", "hooktop d"], codepoint: "U+0257" },
  { symbol: "ʄ", name: "voiced palatal implosive", keywords: ["implosive", "palatal"], codepoint: "U+0284" },
  { symbol: "ɠ", name: "voiced velar implosive", keywords: ["implosive", "velar", "hooktop g"], codepoint: "U+0260" },
  { symbol: "ʛ", name: "voiced uvular implosive", keywords: ["implosive", "uvular"], codepoint: "U+029B" },

  // Clicks
  { symbol: "ʘ", name: "bilabial click", keywords: ["click", "bilabial"], codepoint: "U+0298" },
  { symbol: "ǀ", name: "dental click", keywords: ["click", "dental", "pipe"], codepoint: "U+01C0" },
  { symbol: "ǃ", name: "alveolar click", keywords: ["click", "postalveolar"], codepoint: "U+01C3" },
  { symbol: "ǂ", name: "palatal click", keywords: ["click", "palatal"], codepoint: "U+01C2" },
  { symbol: "ǁ", name: "lateral click", keywords: ["click", "lateral"], codepoint: "U+01C1" },

  // Suprasegmentals
  { symbol: "ˈ", name: "primary stress", keywords: ["stress", "accent"], codepoint: "U+02C8" },
  { symbol: "ˌ", name: "secondary stress", keywords: ["stress", "accent"], codepoint: "U+02CC" },
  { symbol: "ː", name: "long", keywords: ["length", "geminate"], codepoint: "U+02D0" },
  { symbol: "ˑ", name: "half-long", keywords: ["length"], codepoint: "U+02D1" },

  // Tones
  { symbol: "˥", name: "extra-high tone", keywords: ["tone", "tone bar"], codepoint: "U+02E5" },
  { symbol: "˦", name: "high tone", keywords: ["tone", "tone bar"], codepoint: "U+02E6" },
  { symbol: "˧", name: "mid tone", keywords: ["tone", "tone bar"], codepoint: "U+02E7" },
  { symbol: "˨", name: "low tone", keywords: ["tone", "tone bar"], codepoint: "U+02E8" },
  { symbol: "˩", name: "extra-low tone", keywords: ["tone", "tone bar"], codepoint: "U+02E9" },

  // Diacritics as standalone
  { symbol: "ʰ", name: "aspirated", keywords: ["aspiration", "superscript h"], codepoint: "U+02B0" },
  { symbol: "ʷ", name: "labialized", keywords: ["labialization", "superscript w", "rounded"], codepoint: "U+02B7" },
  { symbol: "ʲ", name: "palatalized", keywords: ["palatalization", "superscript j"], codepoint: "U+02B2" },
  { symbol: "ˠ", name: "velarized", keywords: ["velarization", "superscript gamma"], codepoint: "U+02E0" },
  { symbol: "ˤ", name: "pharyngealized", keywords: ["pharyngealization"], codepoint: "U+02E4" },
  { symbol: "ⁿ", name: "nasal release", keywords: ["release", "superscript n"], codepoint: "U+207F" },
  { symbol: "ˡ", name: "lateral release", keywords: ["release", "superscript l"], codepoint: "U+02E1" },

  // Nasalized vowels
  { symbol: "ã", name: "nasalized open front vowel", keywords: ["nasal", "tilde"], codepoint: "U+00E3" },
  { symbol: "ẽ", name: "nasalized close-mid front vowel", keywords: ["nasal", "tilde"], codepoint: "U+1EBD" },
  { symbol: "õ", name: "nasalized close-mid back rounded vowel", keywords: ["nasal", "tilde"], codepoint: "U+00F5" },
];
