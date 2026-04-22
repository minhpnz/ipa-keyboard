import "../styles/toolbar.css";

interface ToolbarProps {
  onFormat: (command: string) => void;
  onUndo: () => void;
  onRedo: () => void;
  onClear: () => void;
  onCopyAll: () => void;
}

export function Toolbar({ onFormat, onUndo, onRedo, onClear, onCopyAll }: ToolbarProps) {
  return (
    <div className="toolbar">
      <div className="toolbar-group">
        <button className="toolbar-btn format-btn" onClick={() => onFormat("bold")} title="Bold">
          <b>B</b>
        </button>
        <button className="toolbar-btn format-btn" onClick={() => onFormat("italic")} title="Italic">
          <i>I</i>
        </button>
        <button className="toolbar-btn format-btn" onClick={() => onFormat("underline")} title="Underline">
          <u>U</u>
        </button>
        <button
          className="toolbar-btn format-btn"
          onClick={() => onFormat("superscript")}
          title="Superscript"
        >
          S
        </button>
        <button
          className="toolbar-btn format-btn"
          onClick={() => onFormat("subscript")}
          title="Subscript"
        >
          <sub>s</sub>
        </button>
        <button
          className="toolbar-btn format-btn"
          onClick={() => onFormat("removeFormat")}
          title="Remove formatting"
        >
          R
        </button>
      </div>

      <div className="toolbar-group">
        <button className="toolbar-btn" onClick={onUndo} title="Undo">
          ↩
        </button>
        <button className="toolbar-btn" onClick={onRedo} title="Redo">
          ↪
        </button>
      </div>

      <div className="toolbar-group">
        <button className="toolbar-btn action-btn" onClick={onClear}>
          Clear
        </button>
        <button className="toolbar-btn action-btn" onClick={onCopyAll}>
          Copy all
        </button>
      </div>
    </div>
  );
}
