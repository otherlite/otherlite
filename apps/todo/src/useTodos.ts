import { useCallback, useState } from 'react';
import { type Todo, MAX_TEXT_LEN } from './types';
import { loadTodos, saveTodos } from './storage';

export function useTodos() {
  const [todos, setTodos] = useState<Todo[]>(() => loadTodos());

  const add = useCallback((text: string) => {
    const trimmed = text.trim();
    if (trimmed.length === 0) return;

    const truncated = trimmed.slice(0, MAX_TEXT_LEN);
    const now = new Date().toISOString();
    const todo: Todo = {
      id: crypto.randomUUID(),
      text: truncated,
      completed: false,
      created_at: now,
      updated_at: now,
    };

    setTodos((prev) => {
      const next = [todo, ...prev];
      saveTodos(next);
      return next;
    });
  }, []);

  const toggle = useCallback((id: string) => {
    setTodos((prev) => {
      const next = prev.map((t) =>
        t.id === id ? { ...t, completed: !t.completed, updated_at: new Date().toISOString() } : t,
      );
      saveTodos(next);
      return next;
    });
  }, []);

  const edit = useCallback((id: string, text: string) => {
    const trimmed = text.trim();
    if (trimmed.length === 0) return;

    setTodos((prev) => {
      const next = prev.map((t) =>
        t.id === id ? { ...t, text: trimmed, updated_at: new Date().toISOString() } : t,
      );
      saveTodos(next);
      return next;
    });
  }, []);

  const remove = useCallback((id: string) => {
    setTodos((prev) => {
      const next = prev.filter((t) => t.id !== id);
      saveTodos(next);
      return next;
    });
  }, []);

  return { todos, add, toggle, edit, remove };
}
