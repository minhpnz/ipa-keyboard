import { useState, useEffect } from "react";
import "../styles/onboarding.css";

const STORAGE_KEY = "ipa-keyboard-onboarded-v2";

interface OnboardingProps {
  onComplete: () => void;
}

const STEPS = [
  {
    title: "Welcome to IPA Keyboard",
    body: "Type IPA symbols in any app on your Mac. 22 keys cover all 44 English phonemes — vowels, consonants, and affricates.",
    icon: "ə",
  },
  {
    title: "How It Works",
    body: "Hold Ctrl and press a letter to type an IPA symbol. Press the same key again to cycle through variants.\n\nFor example: Ctrl+A → æ → ɑ → ɑː → ʌ",
    icon: "æ",
  },
  {
    title: "Toggle On / Off",
    body: "Press Ctrl+Space to toggle IPA input on or off. When off, your keyboard works normally. You can also toggle from the menu bar icon.",
    icon: "⌨",
  },
  {
    title: "Quick Reference",
    body: "Vowels: A E I O U\nConsonants: T(→θ ð) S(→ʃ ʒ) D(→dʒ) C(→k tʃ) N(→ŋ)\nSingle: R L H M F V B P G Z W J\n\nGrant Accessibility permission when prompted — it's required for system-wide input.",
    icon: "ʃ",
  },
];

export function Onboarding({ onComplete }: OnboardingProps) {
  const [step, setStep] = useState(0);
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    if (!localStorage.getItem(STORAGE_KEY)) {
      setVisible(true);
    }
  }, []);

  const handleNext = () => {
    if (step < STEPS.length - 1) {
      setStep(step + 1);
    } else {
      localStorage.setItem(STORAGE_KEY, "true");
      setVisible(false);
      onComplete();
    }
  };

  const handleSkip = () => {
    localStorage.setItem(STORAGE_KEY, "true");
    setVisible(false);
    onComplete();
  };

  if (!visible) return null;

  const current = STEPS[step];

  return (
    <div className="onboarding-overlay">
      <div className="onboarding-card">
        <div className="onboarding-icon">{current.icon}</div>
        <h2 className="onboarding-title">{current.title}</h2>
        <p className="onboarding-body" style={{ whiteSpace: "pre-line" }}>{current.body}</p>

        <div className="onboarding-dots">
          {STEPS.map((_, i) => (
            <span
              key={i}
              className={`onboarding-dot ${i === step ? "active" : ""}`}
            />
          ))}
        </div>

        <div className="onboarding-actions">
          <button className="onboarding-skip" onClick={handleSkip}>
            Skip
          </button>
          <button className="onboarding-next" onClick={handleNext}>
            {step < STEPS.length - 1 ? "Next" : "Get Started"}
          </button>
        </div>
      </div>
    </div>
  );
}
