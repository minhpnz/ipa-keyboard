import { useState, useCallback, useEffect, useRef } from "react";
import { save, open } from "@tauri-apps/plugin-dialog";
import { readTextFile, writeTextFile } from "@tauri-apps/plugin-fs";

interface Document {
  id: string;
  name: string;
  path: string | null;
  content: string;
  isDirty: boolean;
}

const RECENT_KEY = "ipa-keyboard-recent-docs";
const SESSION_KEY = "ipa-keyboard-session";
const ACTIVE_KEY = "ipa-keyboard-active-id";
const MAX_RECENT = 10;

function newDocument(): Document {
  return {
    id: crypto.randomUUID(),
    name: "Untitled",
    path: null,
    content: "",
    isDirty: false,
  };
}

function loadRecent(): string[] {
  try {
    const raw = localStorage.getItem(RECENT_KEY);
    return raw ? JSON.parse(raw) : [];
  } catch {
    return [];
  }
}

function saveRecent(paths: string[]) {
  localStorage.setItem(RECENT_KEY, JSON.stringify(paths.slice(0, MAX_RECENT)));
}

function addToRecent(path: string) {
  const recent = loadRecent().filter((p) => p !== path);
  recent.unshift(path);
  saveRecent(recent);
}

// Lazy initializer: restore session from localStorage or create fresh
function initDocuments(): Document[] {
  try {
    const raw = localStorage.getItem(SESSION_KEY);
    if (raw) {
      const session = JSON.parse(raw) as Document[];
      if (session.length > 0) {
        return session.map((d) => ({ ...d, isDirty: false }));
      }
    }
  } catch {
    // ignore
  }
  return [newDocument()];
}

function initActiveId(docs: Document[]): string {
  try {
    const saved = localStorage.getItem(ACTIVE_KEY);
    if (saved && docs.some((d) => d.id === saved)) {
      return saved;
    }
  } catch {
    // ignore
  }
  return docs[0].id;
}

export function useDocuments() {
  const [documents, setDocuments] = useState<Document[]>(initDocuments);
  const [activeId, setActiveId] = useState(() => initActiveId(documents));
  const [recentPaths, setRecentPaths] = useState<string[]>(loadRecent);
  const isInitialized = useRef(false);

  const activeDoc = documents.find((d) => d.id === activeId) ?? documents[0];

  // Auto-save session to localStorage (skip first render to avoid overwriting)
  useEffect(() => {
    if (!isInitialized.current) {
      isInitialized.current = true;
      return;
    }
    const session = documents.map((d) => ({
      id: d.id,
      name: d.name,
      path: d.path,
      content: d.content,
    }));
    localStorage.setItem(SESSION_KEY, JSON.stringify(session));
    localStorage.setItem(ACTIVE_KEY, activeId);
  }, [documents, activeId]);

  const updateContent = useCallback(
    (content: string) => {
      setDocuments((docs) =>
        docs.map((d) =>
          d.id === activeId ? { ...d, content, isDirty: true } : d
        )
      );
    },
    [activeId]
  );

  const saveDocument = useCallback(async () => {
    const doc = documents.find((d) => d.id === activeId);
    if (!doc) return;

    let filePath: string;
    if (doc.path) {
      filePath = doc.path;
    } else {
      const result = await save({
        defaultPath: `${doc.name}.txt`,
        filters: [{ name: "Text Files", extensions: ["txt"] }],
      });
      if (!result) return;
      filePath = result;
    }

    await writeTextFile(filePath, doc.content);
    const fileName = filePath.split("/").pop()?.split("\\").pop() ?? "Untitled";

    setDocuments((docs) =>
      docs.map((d) =>
        d.id === activeId
          ? { ...d, path: filePath, name: fileName, isDirty: false }
          : d
      )
    );
    addToRecent(filePath);
    setRecentPaths(loadRecent());
  }, [activeId, documents]);

  const saveAsDocument = useCallback(async () => {
    const doc = documents.find((d) => d.id === activeId);
    if (!doc) return;

    const filePath = await save({
      defaultPath: `${doc.name}.txt`,
      filters: [{ name: "Text Files", extensions: ["txt"] }],
    });
    if (!filePath) return;

    await writeTextFile(filePath, doc.content);
    const fileName = filePath.split("/").pop()?.split("\\").pop() ?? "Untitled";

    setDocuments((docs) =>
      docs.map((d) =>
        d.id === activeId
          ? { ...d, path: filePath, name: fileName, isDirty: false }
          : d
      )
    );
    addToRecent(filePath);
    setRecentPaths(loadRecent());
  }, [activeId, documents]);

  const openDocument = useCallback(async () => {
    const result = await open({
      filters: [{ name: "Text Files", extensions: ["txt"] }],
      multiple: false,
    });
    if (!result) return;

    const filePath = result as string;
    const content = await readTextFile(filePath);
    const fileName = filePath.split("/").pop()?.split("\\").pop() ?? "Untitled";

    const doc: Document = {
      id: crypto.randomUUID(),
      name: fileName,
      path: filePath,
      content,
      isDirty: false,
    };

    setDocuments((docs) => [...docs, doc]);
    setActiveId(doc.id);
    addToRecent(filePath);
    setRecentPaths(loadRecent());
  }, []);

  const openFilePath = useCallback(async (filePath: string) => {
    try {
      const content = await readTextFile(filePath);
      const fileName =
        filePath.split("/").pop()?.split("\\").pop() ?? "Untitled";

      const doc: Document = {
        id: crypto.randomUUID(),
        name: fileName,
        path: filePath,
        content,
        isDirty: false,
      };

      setDocuments((docs) => [...docs, doc]);
      setActiveId(doc.id);
      addToRecent(filePath);
      setRecentPaths(loadRecent());
    } catch {
      const updated = loadRecent().filter((p) => p !== filePath);
      saveRecent(updated);
      setRecentPaths(updated);
    }
  }, []);

  const newDoc = useCallback(() => {
    const doc = newDocument();
    setDocuments((docs) => [...docs, doc]);
    setActiveId(doc.id);
  }, []);

  const closeDocument = useCallback(
    (id: string) => {
      setDocuments((docs) => {
        const remaining = docs.filter((d) => d.id !== id);
        if (remaining.length === 0) {
          const fresh = newDocument();
          setActiveId(fresh.id);
          return [fresh];
        }
        if (activeId === id) {
          setActiveId(remaining[remaining.length - 1].id);
        }
        return remaining;
      });
    },
    [activeId]
  );

  return {
    documents,
    activeDoc,
    activeId,
    recentPaths,
    setActiveId,
    updateContent,
    saveDocument,
    saveAsDocument,
    openDocument,
    openFilePath,
    newDoc,
    closeDocument,
  };
}
