# Architecture

This app uses **feature-first Clean Architecture** with Riverpod for DI/state.
The `auth/` feature is the canonical reference — copy its layout when
migrating any other feature.

## Layout per feature

```
lib/src/features/<feature>/
├── data/
│   ├── datasources/         # (optional) thin wrappers over network/disk
│   ├── models/              # (optional) DTOs with fromJson/toJson
│   └── repositories/
│       └── <feature>_repository_impl.dart   # implements the domain contract
├── domain/
│   ├── entities/            # pure Dart, no Flutter, no JSON
│   ├── repositories/        # abstract contract (interface)
│   └── usecases/            # (optional) single-method classes
└── presentation/
    ├── controllers/         # Riverpod Notifier / FutureProvider
    ├── screens/             # full-page widgets routed by go_router
    └── widgets/             # widgets used only inside this feature
```

Use `core/widgets/` for widgets reused by 2+ features (e.g.
`states/loading_view.dart`). When `core/widgets/` accumulates one-off widgets,
that's a signal — move them back into the feature that owns them.

## The data flow

```
Widget
  ↓ ref.read / ref.watch
Riverpod controller       (presentation/controllers/)
  ↓ calls
Repository (abstract)     (domain/repositories/)
  ↓ implemented by
Repository impl           (data/repositories/)
  ↓ uses
DataSource / API client   (data/datasources/ or lib/api/akhiyan_api.dart today)
```

**Rules:**

1. The `domain/` layer imports nothing from Flutter, packages, or `data/`.
2. The `presentation/` layer never touches `data/` or the raw API client.
3. The `data/` layer catches platform/HTTP exceptions and **throws a
   `Failure` subclass** from `core/errors/failures.dart`. This is what the
   guideline calls "errors are first-class citizens" — every error reaching
   the UI is a typed value, never a raw `Exception`.

## Errors

`core/errors/failures.dart` defines a sealed `Failure` hierarchy:
`NetworkFailure`, `ServerFailure`, `AuthFailure`, `ValidationFailure`,
`CacheFailure`, `UnknownFailure`. Repositories throw these.

`core/errors/error_mapper.dart` provides:

- `mapToFailure(Object e)` — maps any thrown object (incl. `ApiException`,
  `NetworkException`) to a `Failure` subtype. Repositories use this.
- `describeError(Object e, {String fallback})` — friendly user-facing
  string for any error. Screens use this from `.when(error: ...)`.

## Shared async-state widgets

`core/widgets/states/`:

- `LoadingView` — centered spinner with optional message.
- `ErrorView` — centered error icon + message + optional retry.
- `EmptyView` — centered empty-state icon + title + message + optional action.

Import via the barrel: `import '../../../core/widgets/states/states.dart';`

## Reference: the `auth/` feature

```
features/auth/
├── data/repositories/auth_repository_impl.dart
├── domain/
│   ├── entities/user.dart                  # pure Dart User
│   └── repositories/auth_repository.dart   # abstract contract
└── presentation/
    ├── controllers/auth_controller.dart    # Notifier<User?> + provider
    └── screens/login_screen.dart
```

`AuthRepositoryImpl` wraps the existing monolithic `AkhiyanApi.auth` for
now. When `lib/api/akhiyan_api.dart` is split into per-feature data sources,
`AuthRepositoryImpl` will take an `AuthRemoteDataSource` instead — but
nothing above the data layer changes.

## Migrating another feature

Pick the smallest unmigrated feature. For each:

1. Define the `domain/entities/` (pure Dart immutable classes).
2. Write the `domain/repositories/<feature>_repository.dart` abstract.
3. Write the `data/repositories/<feature>_repository_impl.dart` that:
   - takes the API client / data source in its constructor,
   - converts DTOs → entities via a private mapper,
   - catches exceptions in `try { ... } on Exception catch (e, st) { throw mapToFailure(e, st); }`.
4. Add a Riverpod `Provider<XRepository>` that injects the impl.
5. Move the existing controller into `presentation/controllers/` and rewrite
   it to call the repository instead of the raw API.
6. Move screens into `presentation/screens/` (update relative imports).
7. Update import sites elsewhere (typically `app_router.dart` and any
   widgets that depended on the old controller's types).
8. Run `flutter analyze` — must be zero errors before merging.

**Don't** rewrite the whole feature in one PR. Split work: domain + data
in one PR (compiles, no UI change), then presentation rewiring in a
follow-up.

## What's deliberately NOT here

These are skipped intentionally to avoid ceremony for ceremony's sake in
a solo / single-backend project:

- **`UseCase` classes** (e.g. `SignInUseCase`) — for one-line repo calls
  they add zero value. If a feature gains complex orchestration logic
  spanning multiple repos, then add use cases.
- **`fpdart` / `Either<Failure, T>`** — Riverpod's `AsyncValue` already
  models loading/data/error elegantly. Throwing typed `Failure` and
  letting `AsyncValue.error` catch them is more idiomatic.
- **DTO classes mirroring entities** when JSON shape == entity shape —
  reuse the existing model from `lib/api/akhiyan_api.dart` as the DTO and
  map to the domain entity in the repository.

## Lints / CI

- `analysis_options.yaml` uses `very_good_analysis`. Errors fail builds;
  warnings/infos are tracked but not blocking during the migration.
- `.github/workflows/ci.yml` runs format + analyze + tests on every PR.
- Run `flutter analyze` locally before pushing — must show **0 errors**.
