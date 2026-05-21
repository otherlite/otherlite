export interface Todo {
  id: string;
  text: string;
  completed: boolean;
  created_at: string;
  updated_at: string;
}

export const MAX_TEXT_LEN = 200;
export const STORAGE_KEY = 'todo-mvp:v1';
