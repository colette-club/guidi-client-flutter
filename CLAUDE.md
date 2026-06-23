# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is `guidi_client`, a Flutter **package** (not an app) that provides the client toolkit for the Guidi guide/tour tracking API. It bundles an HTTP/GraphQL API client, guide models, a service layer that caches per-user guide state, and a coach-mark UI player. Host apps (e.g. club-mobile) depend on this package to define and play interactive product tours.

## Git Commit Policy

**NEVER commit automatically. ALWAYS ask first.**

Before any commit: present the changes (`git diff --stat` or a summary of modified files), propose a commit message, and wait for explicit user approval ("commit", "yes", or similar). This applies to all changes — code, docs, and config alike.

## Common Commands

This is a package, so there are no flavors, run targets, or build artifacts.

- `flutter pub get` — install/update dependencies
- `flutter analyze` — static analysis / linting
- `flutter test` — run all tests
- `flutter test test/guidi_client_test.dart` — run a specific test file
- `flutter clean` — clean build artifacts

There is no `l10n` in this package — user-facing strings are supplied by the host app through `l10n` resolver callbacks on guides and steps, and via `GuidePlayerTheme` labels.

## Architecture

### Directory Structure
- `lib/guidi_client.dart` — public library barrel; re-exports the package API plus `tutorial_coach_mark`
- `lib/src/` — implementation
  - `guidi_client.dart` — `GuidiClient`: low-level GraphQL client (queries/mutations over `http`, bearer-token auth)
  - `guide_service.dart` — `GuideService`: stateful layer that caches per-user `GuideState`, resolves unseen guides per screen, and proxies seen/reset/not-applicable mutations
  - `guidi_exception.dart` — `GuidiException` error type
  - `models/` — `Guide` / `GuideStep` (definitions, audiences, step grouping), `GuideProgress`, `GuideState`
  - `components/guide_player.dart` — `GuidePlayer` (coach-mark playback) and `GuidePlayerTheme` (overlay/tooltip styling)
- `test/` — unit tests using `http/testing` `MockClient`

### Key Technologies
- **Flutter SDK**: Dart `>=3.0.0 <4.0.0`
- **API**: GraphQL over plain `http` (`GuidiClient`), no GraphQL client dependency
- **Coach marks**: `tutorial_coach_mark` (re-exported for consumers)
- **State**: in-memory caching inside `GuideService` (no BLoC/Cubit in the package itself)

## Code Conventions

All Dart/Flutter coding conventions — cubit architecture and state shape, error handling, repos & GraphQL, models & enums, screens & widgets, components, routing/theme, localization, testing, and DI — live in the **`flutter-conventions-guide`** skill, shared across our Flutter apps via the `colette-club` plugin marketplace (`flutter-conventions-guide@colette-club`).

**Before writing or editing ANY `.dart`/`.arb` file, you MUST first load this skill** by invoking the Skill tool with `flutter-conventions-guide:flutter-conventions-guide`. Do NOT rely on file-pattern auto-activation — it does not reliably surface a reminder; invoke the skill yourself at the start of any Flutter work. It is the authoritative source for "how to write code here" (see its `reference.md` for full templates). (If the skill is unavailable, enable the plugin via `"enabledPlugins": { "flutter-conventions-guide@colette-club": true }`, or read it from the plugin cache at `~/.claude/plugins/cache/colette-club/flutter-conventions-guide/0.1.0/skills/flutter-conventions-guide/SKILL.md`.)

Do NOT re-document coding conventions yourself — that's what the pointer is for.
