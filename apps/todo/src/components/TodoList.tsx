import { type Todo } from '../types';
import TodoItem from './TodoItem';
import EmptyState from './EmptyState';

interface TodoListProps {
  todos: Todo[];
  onToggle: (id: string) => void;
  onEdit: (id: string, text: string) => void;
  onRemove: (id: string) => void;
}

export default function TodoList({ todos, onToggle, onEdit, onRemove }: TodoListProps) {
  if (todos.length === 0) {
    return <EmptyState />;
  }

  return (
    <ul className="todo-list">
      {todos.map((todo) => (
        <li key={todo.id} className="todo-list__item">
          <TodoItem
            todo={todo}
            onToggle={onToggle}
            onEdit={onEdit}
            onRemove={onRemove}
          />
        </li>
      ))}
    </ul>
  );
}
