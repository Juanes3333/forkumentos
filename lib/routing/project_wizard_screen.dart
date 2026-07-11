import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/core/theme/app_colors.dart';
import 'package:forkumentos/features/datasource/presentation/active_datasource_provider.dart';
import 'package:forkumentos/features/datasource/presentation/datasource_resource_card.dart';
import 'package:forkumentos/features/project/presentation/close_active_project.dart';
import 'package:forkumentos/features/template/presentation/active_template_provider.dart';
import 'package:forkumentos/features/template/presentation/template_resource_card.dart';
import 'package:forkumentos/routing/app_phase_provider.dart';
import 'package:forkumentos/shared/providers/active_project_provider.dart';
import 'package:intl/intl.dart';

final class ProjectWizardScreen extends ConsumerWidget {
  const ProjectWizardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(activeProjectProvider).valueOrNull;
    if (project == null) {
      return const SizedBox.shrink();
    }

    final hasTemplate = ref.watch(activeTemplateProvider).valueOrNull != null;
    final hasDatasource =
        ref.watch(activeDatasourceProvider).valueOrNull != null;
    final canStartWorking = hasTemplate && hasDatasource;
    final createdAtLabel = DateFormat(
      'dd/MM/yyyy HH:mm',
    ).format(project.createdAt.toLocal());

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Configurar proyecto',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  TextButton(
                    onPressed: () => closeActiveProject(context, ref),
                    child: const Text('Cerrar proyecto'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Importa la plantilla y la fuente de datos antes de '
                'empezar a trabajar.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Nombre del proyecto',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.of(context).foregroundMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        project.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Fecha de creación',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.of(context).foregroundMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        createdAtLabel,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const TemplateResourceCard(),
              const SizedBox(height: 16),
              const DatasourceResourceCard(),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: canStartWorking
                    ? () {
                        ref
                            .read(workbenchEnteredProvider.notifier)
                            .enterWorkbench();
                      }
                    : null,
                icon: const Icon(Icons.play_arrow_outlined),
                label: const Text('Empezar a trabajar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
