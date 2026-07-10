enum WorkbenchTab {
  file,
  home,
  template,
  datasource,
  mapping,
  review,
  export,
  view,
  help,
}

extension WorkbenchTabLabel on WorkbenchTab {
  String get label {
    return switch (this) {
      WorkbenchTab.file => 'Archivo',
      WorkbenchTab.home => 'Inicio',
      WorkbenchTab.template => 'Plantilla',
      WorkbenchTab.datasource => 'Datos',
      WorkbenchTab.mapping => 'Mapeo',
      WorkbenchTab.review => 'Revisión',
      WorkbenchTab.export => 'Exportar',
      WorkbenchTab.view => 'Vista',
      WorkbenchTab.help => 'Ayuda',
    };
  }
}
