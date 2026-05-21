import { useState, type KeyboardEvent } from 'react';

interface TodoInputProps {
  onAdd: (text: string) => void;
}

export default function TodoInput({ onAdd }: TodoInputProps) {
  const [text, setText] = useState('');

  function handleSubmit() {
    const trimmed = text.trim();
    if (trimmed.length === 0) return;
    onAdd(trimmed);
    setText('');
  }

  function handleKeyDown(e: KeyboardEvent<HTMLInputElement>) {
    if (e.key === 'Enter') {
      handleSubmit();
    }
  }

  return (
    <div className="todo-input-row">
      <label htmlFor="todo-input" className="sr-only">
        新待办
      </label>
      <input
        id="todo-input"
        type="text"
        value={text}
        onChange={(e) => setText(e.target.value)}
        onKeyDown={handleKeyDown}
        placeholder="输入待办事项……"
        autoFocus
      />
      <button type="button" onClick={handleSubmit} aria-label="添加待办">
        添加
      </button>
    </div>
  );
}
