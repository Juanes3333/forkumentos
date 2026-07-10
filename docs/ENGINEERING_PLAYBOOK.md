# Engineering Playbook: Forkumentos

This document serves as the operational manual for the Forkumentos engineering team. It defines the workflows, policies, and conventions required to maintain a sustainable, high-quality codebase. Future contributors and AI agents must strictly adhere to these practices.

---

## 1. Development Philosophy

We build for the long term. Code is read significantly more often than it is written.
- **YAGNI (You Aren't Gonna Need It):** Never write speculative code. Implement only what is explicitly required.
- **Readability Over Cleverness:** Prefer the obvious, readable solution over the highly optimized, cryptic one.
- **Quality at the Source:** Bugs are caught and fixed at the time of development, not deferred to a QA phase.
- **AI-Assisted, Human-Guided:** AI agents augment development speed, but human developers retain full responsibility for architecture and correctness.

---

## 2. Sprint Workflow

The project is built in sequential, atomic sprints as defined in `IMPLEMENTATION_PLAN.md`.
1. **Context Initialization:** The developer (or AI) reviews the sprint objectives and dependencies.
2. **Execution:** Implement features one at a time, making small, logical commits.
3. **Validation:** Ensure the implementation meets the Definition of Done.
4. **Closure:** The sprint is finalized, documented, and the branch is merged.

---

## 3. Definition of Ready (DoR)

A sprint or feature task is ready for development only if:
- [ ] It has a clear, unambiguous objective.
- [ ] Dependencies (architectural or prior sprints) are fully resolved.
- [ ] Acceptance criteria are explicitly defined.
- [ ] Relevant architectural and UI rules (`ARCHITECTURE.md`, `DESIGN_SYSTEM.md`) are understood.

---

## 4. Definition of Done (DoD)

A task or sprint is considered complete only when:
- [ ] The implementation satisfies all acceptance criteria.
- [ ] `flutter analyze` returns zero issues.
- [ ] `flutter test` passes with all tests green.
- [ ] The code introduces no unused imports, variables, or dead code.
- [ ] No unrequested abstractions or speculative features were introduced.
- [ ] The Git working tree is clean and commits follow conventions.

---

## 5. Code Review Checklist

Whether self-reviewing or evaluating AI output, apply this checklist rigorously:

| Category | Verification |
| :--- | :--- |
| **Architecture** | Does any new class violate the boundary rules in `ARCHITECTURE.md`? |
| **Scope** | Does the code implement more than requested? (Reject if yes). |
| **Simplicity** | Does a new abstraction have fewer than two concrete call sites? |
| **Performance** | Are large tasks offloaded from the main thread? |
| **UI/UX** | Does it follow the `DESIGN_SYSTEM.md` density and interaction heuristics? |
| **Resilience** | Does the code introduce hardcoded paths, magic numbers, or raw exceptions? |

---

## 6. Git Workflow

### Branch Strategy
- **`main`**: The single source of truth. Always deployable, compiling, and clean.
- **Feature Branches**: Cut from `main` for new work. Named `feat/brief-description`.
- **Bugfix Branches**: Cut from `main` for defect resolution. Named `fix/brief-description`.
- **Chore Branches**: Cut from `main` for infrastructure or tooling. Named `chore/brief-description`.

### Commit Strategy
Commits must adhere to the **Conventional Commits** format.
- Use atomic, logical commits. Avoid large "end-of-day" dumps.
- Prefix examples: `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`.

---

## 7. AI & Cursor Workflow

When delegating work to Cursor or other AI agents, the following workflow is mandatory:
1. **Provide Constraints:** Feed the agent the exact sprint objective and explicit boundaries.
2. **Enforce Rules:** The agent must automatically read and follow the `.cursor/rules/` for the specific domain.
3. **Verify Output:** AI output is treated as untrusted until it passes the Definition of Done. The AI is not permitted to bypass architectural boundaries to solve a problem quickly.

---

## 8. Core Policies

### Architecture Changes
- Significant changes to the system design must be proposed, debated, and documented in `ARCHITECTURE.md` *before* any code is written.
- Silent, gradual drift from the architecture is strictly prohibited.

### Bug Fixing Workflow
1. **Reproduce:** Confirm the bug on the `main` branch.
2. **Root Cause:** Fix the bug at its source, not at the symptom level (e.g., patch the utility, not every caller).
3. **Test:** Write a regression test that fails without the fix and passes with it.
4. **Implement:** Apply the fix and commit.

### Refactoring Policy
- Refactoring must be isolated to its own branch and commit (using the `refactor: ` prefix).
- **Never mix functional changes (features/bugs) with refactoring in the same commit.**
- Refactoring is permitted only if adequate test coverage exists to verify behavior remains unchanged.

### Dependency Policy
- **Native First:** Prefer the Dart standard library and native Flutter SDK over external packages.
- **Evaluation:** Before adding a dependency to `pubspec.yaml`, prove it saves >100 lines of complex, error-prone code.
- **Isolation:** Third-party libraries handling critical operations (like I/O or complex parsing) must be wrapped in `core/` interfaces.

### Testing Policy

| Layer | Strategy |
| :--- | :--- |
| **Core** | Pure unit tests without Flutter SDK dependencies. |
| **Domain / Data** | Unit tests using fake or mock repository implementations. |
| **Presentation** | Widget tests utilizing Riverpod `ProviderScope` overrides. |
| **Integration** | Automated user flow tests (reserved for end-to-end critical paths). |

### Documentation Workflow
- Documentation is a first-class deliverable, not an afterthought.
- If a system behavior changes, the corresponding document in `docs/` must be updated in the same commit.

### Release Workflow
1. Ensure the sprint or milestone is fully completed and integrated into `main`.
2. Run final regression testing (`flutter test`, `flutter analyze`).
3. Update the `CHANGELOG.md` with user-facing features and fixes.
4. Tag the release on the `main` branch (e.g., `v1.0.0`).
5. Generate the final executable binaries for deployment.
