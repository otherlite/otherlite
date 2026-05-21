import { useTodos } from './useTodos';
import TodoInput from './components/TodoInput';
import TodoList from './components/TodoList';

function App() {
  const { todos, add, toggle, edit, remove } = useTodos();

  return (
    <main className="todo-app">
      <h1 className="todo-app__title">待办事项</h1>
      <TodoInput onAdd={add} />
      <TodoList todos={todos} onToggle={toggle} onEdit={edit} onRemove={remove} />
    </main>
  );
}

export default App;
