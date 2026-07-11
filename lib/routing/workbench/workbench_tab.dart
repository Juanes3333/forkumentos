enum WorkbenchTab { file, home, templates, review, export }

extension WorkbenchTabLabel on WorkbenchTab {
  String get label {
    return switch (this) {
      WorkbenchTab.file => 'Archivo',
      WorkbenchTab.home => 'Inicio',
      WorkbenchTab.templates => 'Plantillas',
      WorkbenchTab.review => 'Revisión',
      WorkbenchTab.export => 'Exportar',
    };
  }
}
