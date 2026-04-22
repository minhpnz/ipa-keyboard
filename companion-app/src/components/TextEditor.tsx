import { useRef, useState, useCallback, useImperativeHandle, forwardRef, useEffect } from "react";
import { useSymbolCycle } from "../hooks/useSymbolCycle";
import { MAPPINGS } from "../data/default-mappings";
import { CandidatePopup } from "./CandidatePopup";
import "../styles/editor.css";

export interface TextEditorHandle {
  insertSymbol: (symbol: string) => void;
  setContent: (text: string) => void;
  getPlainText: () => string;
  getHtml: () => string;
  clear: () => void;
  focus: () => void;
}

interface TextEditorProps {
  onFormat: string | null;
  onClearFormat: () => void;
  onSymbolInserted?: (symbol: string) => void;
  onContentChange?: () => void;
}

export const TextEditor = forwardRef<TextEditorHandle, TextEditorProps>(
  function TextEditor({ onFormat, onClearFormat, onSymbolInserted, onContentChange }, ref) {
    const editorRef = useRef<HTMLDivElement>(null);
    const lastInsertionRef = useRef<{ node: Text; offset: number; length: number } | null>(null);
    const [candidates, setCandidates] = useState<string[]>([]);
    const [candidatePos, setCandidatePos] = useState<{ x: number; y: number } | undefined>();

    const insertAtCursor = useCallback(
      (symbol: string, isReplace: boolean) => {
        const editor = editorRef.current;
        if (!editor) return;
        editor.focus();

        const sel = window.getSelection();
        if (!sel) return;

        if (isReplace && lastInsertionRef.current) {
          const { node, offset, length } = lastInsertionRef.current;
          try {
            node.deleteData(offset, length);
            node.insertData(offset, symbol);
            const range = document.createRange();
            range.setStart(node, offset + symbol.length);
            range.collapse(true);
            sel.removeAllRanges();
            sel.addRange(range);
            lastInsertionRef.current = { node, offset, length: symbol.length };
          } catch {
            document.execCommand("insertText", false, symbol);
            lastInsertionRef.current = null;
          }
        } else {
          if (sel.rangeCount > 0) {
            const range = sel.getRangeAt(0);
            range.deleteContents();
            const textNode = document.createTextNode(symbol);
            range.insertNode(textNode);
            range.setStartAfter(textNode);
            range.collapse(true);
            sel.removeAllRanges();
            sel.addRange(range);
            lastInsertionRef.current = {
              node: textNode,
              offset: 0,
              length: symbol.length,
            };
          }
        }

        onSymbolInserted?.(symbol);
        onContentChange?.();
      },
      [onSymbolInserted, onContentChange]
    );

    const { handleKeyDown: cycleKeyDown } = useSymbolCycle(insertAtCursor);

    // Wrap key handler to show candidate popup on Ctrl+key
    const handleKeyDown = useCallback(
      (e: React.KeyboardEvent<HTMLElement>) => {
        // If candidate popup is open, let it handle keys
        if (candidates.length > 0) return;

        // Check if this is a Ctrl+letter that has mappings — show popup
        if ((e.ctrlKey || e.metaKey) && !e.altKey) {
          const key = e.key.toLowerCase();
          const symbols = MAPPINGS[key];
          if (symbols && symbols.length > 1) {
            e.preventDefault();

            // Get cursor position for popup placement
            const sel = window.getSelection();
            if (sel && sel.rangeCount > 0) {
              const rect = sel.getRangeAt(0).getBoundingClientRect();
              const editorRect = editorRef.current?.getBoundingClientRect();
              if (editorRect) {
                setCandidatePos({
                  x: rect.left - editorRect.left,
                  y: rect.bottom - editorRect.top,
                });
              }
            }

            setCandidates(symbols);
            return;
          }
        }

        cycleKeyDown(e);
      },
      [cycleKeyDown, candidates]
    );

    const handleCandidateSelect = useCallback(
      (symbol: string) => {
        insertAtCursor(symbol, false);
        setCandidates([]);
      },
      [insertAtCursor]
    );

    const handleCandidateDismiss = useCallback(() => {
      setCandidates([]);
      editorRef.current?.focus();
    }, []);

    // Apply formatting commands via useEffect (not during render)
    useEffect(() => {
      if (onFormat) {
        editorRef.current?.focus();
        document.execCommand(onFormat, false);
        onClearFormat();
      }
    }, [onFormat, onClearFormat]);

    useImperativeHandle(ref, () => ({
      insertSymbol: (symbol: string) => insertAtCursor(symbol, false),
      setContent: (text: string) => {
        if (editorRef.current) {
          editorRef.current.innerText = text;
        }
      },
      getPlainText: () => editorRef.current?.innerText ?? "",
      getHtml: () => editorRef.current?.innerHTML ?? "",
      clear: () => {
        if (editorRef.current) editorRef.current.innerHTML = "";
      },
      focus: () => editorRef.current?.focus(),
    }));

    return (
      <div style={{ position: "relative" }}>
        <div
          ref={editorRef}
          className="text-editor"
          contentEditable
          suppressContentEditableWarning
          onKeyDown={handleKeyDown}
          onMouseDown={() => {
            lastInsertionRef.current = null;
            if (candidates.length > 0) setCandidates([]);
          }}
          data-placeholder="Type here or use the keyboard below..."
          onInput={onContentChange}
        />
        <CandidatePopup
          candidates={candidates}
          onSelect={handleCandidateSelect}
          onDismiss={handleCandidateDismiss}
          position={candidatePos}
        />
      </div>
    );
  }
);
