import { useState, useRef, type KeyboardEvent } from 'react';
import { type Todo } from '../types';

interface TodoItemProps {
  todo: Todo;
  onToggle: (id: string) => void;
  onEdit: (id: string, text: string) => void;
  onRemove: (id: string) => void;
}

export default function TodoItem({ todo, onToggle, onEdit, onRemove }: TodoItemProps) {
  const [editing, setEditing] = useState(false);
  const [editText, setEditText] = useState(todo.text);
  const inputRef = useRef<HTMLInputElement>(null);

  function startEditing() {
    setEditText(todo.text);
    setEditing(true);
    // Focus the input on next tick after React renders it
    requestAnimationFrame(() => inputRef.current?.select());
  }

  function saveEdit() {
    const trimmed = editText.trim();
    if (trimmed.length > 0) {
      onEdit(todo.id, trimmed);
    }
    setEditing(false);
  }

  function cancelEdit() {
    setEditText(todo.text);
    setEditing(false);
  }

  function handleEditKeyDown(e: KeyboardEvent<HTMLInputElement>) {
    if (e.key === 'Enter') {
      saveEdit();
    } else if (e.key === 'Escape') {
      cancelEdit();
    }
  }

  function handleToggle() {
    onToggle(todo.id);
  }

  function handleRemove() {
    onRemove(todo.id);
  }

  return (
    <div
      className={`todo-item${todo.completed ? ' todo-item--completed' : ''}`}
      data-completed={todo.completed || undefined}
    >
      <label className="todo-item__checkbox-label sr-only" htmlFor={`todo-check-${todo.id}`}>
        {todo.completed ? '标记未完成' : '标记完成'}
      </label>
      <input
        id={`todo-check-${todo.id}`}
        type="checkbox"
        className="todo-item__checkbox"
        checked={todo.completed}
        onChange={handleToggle}
      />

      {editing ? (
        <input
          ref={inputRef}
          type="text"
          className="todo-item__edit-input"
          value={editText}
          onChange={(e) => setEditText(e.target.value)}
          onKeyDown={handleEditKeyDown}
          onBlur={saveEdit}
          autoFocus
        />
      ) : (
        <span
          className="todo-item__text"
          onDoubleClick={startEditing}
          title="双击编辑"
        >
          {todo.text}
        </span>
      )}

      <button
        type="button"
        className="todo-item__delete"
        onClick={handleRemove}
        aria-label={`删除「${todo.text}」`}
      >
        删除
      </button>
    </div>
  );
}
