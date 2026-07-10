abstract interface class UndoableCommand<T> {
  T execute(T state);
  T undo(T state);
}
