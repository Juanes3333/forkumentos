# Forkumentos

Forkumentos is a Windows Desktop application designed for document mapping, preview, review, and export. It provides an efficient and modular system to handle templates, data sources, and document transformations.

## Installation

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install/windows) (Stable channel, version 3.44.6 or later)
- [Visual Studio 2022](https://visualstudio.microsoft.com/) with the "Desktop development with C++" workload installed
- Git

### Setup
1. Clone the repository:
   ```bash
   git clone https://github.com/juane/forkumentos.git
   cd forkumentos
   ```
2. Fetch dependencies:
   ```bash
   flutter pub get
   ```
3. Run the application:
   ```bash
   flutter run -d windows
   ```

## Repository Structure

The project follows a **Feature-First** architecture:
```
forkumentos/
├── assets/             # Fonts, icons, and images
├── docs/               # Architecture and project documentation
├── .cursor/rules/      # Cursor rules and styling guidelines
├── lib/
│   ├── app/            # App entry point and global configuration
│   ├── core/           # Commands, constants, errors, extensions, services, theme, utils
│   ├── features/       # Modular features: project, template, datasource, mapping, etc.
│   ├── shared/         # Shared dialogs, enums, models, providers, widgets
│   ├── routing/        # Router configuration and paths
│   └── main.dart       # App initialization
└── test/               # Widget and unit tests
```

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
