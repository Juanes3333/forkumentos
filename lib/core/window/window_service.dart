abstract interface class WindowService {
  Future<void> setTitle(String title);

  // ignore: avoid_positional_boolean_parameters
  Future<void> setPreventClose(bool value);

  void addCloseListener(Future<void> Function() onCloseRequested);

  Future<void> destroy();
}
