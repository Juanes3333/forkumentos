# Guidelines for AI Agents (AGENTS.md)

Welcome, AI Agent (Cursor, Cline, Windsurf, or others)! Please adhere to these guidelines strictly when working in this codebase.

## 1. Respect the Architecture
- Follow the **Feature-First** structure. If you need to add a new concept, decide if it should be an isolated feature in `lib/features/` or a shared component in `lib/shared/`.
- Never introduce direct dependencies between features.
- Never write business logic inside core or shared layers.

## 2. Coding Standards
- **Lints and Warnings**: The codebase uses `very_good_analysis`. You must resolve all lint warnings, errors, and formatting before completing your task.
- **Dart Formatter**: Run `dart format` on all modified files.
- **No Placeholders**: Never write mock UI, dummy screens, hardcoded state, or temporary widget placeholders unless explicitly requested.
- **No TODO Comments**: Do not leave `TODO` comments. If a task is deferred, document it externally or in project logs.

## 3. Code Generation
- We use `freezed` and `json_serializable` for data modeling.
- When you modify models, always run `dart run build_runner build --delete-conflicting-outputs` to regenerate code files.

## 4. Git & Commits
- Follow Conventional Commits format (`feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`).
- Commit atomic and logical units of work. Avoid large multi-purpose commits.
- Ensure that the project compiles and all tests pass before making a commit.
