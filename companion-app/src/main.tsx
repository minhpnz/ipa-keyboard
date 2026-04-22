import React from "react";
import ReactDOM from "react-dom/client";
import App from "./App";
import { FloatingKeyboard } from "./components/FloatingKeyboard";

// If URL has ?floating=true, render the floating keyboard instead
const isFloating = window.location.search.includes("floating=true");

ReactDOM.createRoot(document.getElementById("root") as HTMLElement).render(
  <React.StrictMode>
    {isFloating ? <FloatingKeyboard /> : <App />}
  </React.StrictMode>,
);
