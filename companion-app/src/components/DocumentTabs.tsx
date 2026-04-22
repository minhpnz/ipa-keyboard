import "../styles/tabs.css";

interface Document {
  id: string;
  name: string;
  path: string | null;
  content: string;
  isDirty: boolean;
}

interface DocumentTabsProps {
  documents: Document[];
  activeId: string;
  onSelect: (id: string) => void;
  onClose: (id: string) => void;
  onNew: () => void;
  onOpen: () => void;
  onSave: () => void;
  onSaveAs: () => void;
  recentPaths: string[];
  onOpenRecent: (path: string) => void;
}

export function DocumentTabs({
  documents,
  activeId,
  onSelect,
  onClose,
  onNew,
  onOpen,
  onSave,
  onSaveAs,
  recentPaths,
  onOpenRecent,
}: DocumentTabsProps) {
  return (
    <div className="doc-tabs-bar">
      <div className="doc-tabs">
        {documents.map((doc) => (
          <div
            key={doc.id}
            className={`doc-tab${doc.id === activeId ? " active" : ""}`}
            onClick={() => onSelect(doc.id)}
          >
            <span className="doc-tab-name">
              {doc.isDirty ? "* " : ""}
              {doc.name}
            </span>
            <button
              className="doc-tab-close"
              onClick={(e) => {
                e.stopPropagation();
                onClose(doc.id);
              }}
              title="Close"
            >
              x
            </button>
          </div>
        ))}
        <button className="doc-tab-add" onClick={onNew} title="New document">
          +
        </button>
      </div>
      <div className="doc-actions">
        <button className="doc-action-btn" onClick={onOpen} title="Open file">
          Open
        </button>
        <button className="doc-action-btn" onClick={onSave} title="Save (Ctrl+S)">
          Save
        </button>
        <button className="doc-action-btn" onClick={onSaveAs} title="Save As">
          Save As
        </button>
        {recentPaths.length > 0 && (
          <div className="recent-dropdown">
            <button className="doc-action-btn">Recent</button>
            <div className="recent-menu">
              {recentPaths.map((p) => (
                <button
                  key={p}
                  className="recent-item"
                  onClick={() => onOpenRecent(p)}
                  title={p}
                >
                  {p.split("/").pop()?.split("\\").pop() ?? p}
                </button>
              ))}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
