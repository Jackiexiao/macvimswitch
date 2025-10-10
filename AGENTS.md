# Repository Guidelines

## Project Structure & Module Organization
- Core Swift sources live in the repository root: `main.swift` boots the app, `AppDelegate.swift` wires lifecycle, and managers such as `StatusBarManager.swift`, `InputMethodManager.swift`, and `UserPreferences.swift` keep UI, input hooks, and persistence separated.
- `public/` stores shipped assets (e.g., `tip-qr-code.jpg`); optimize and document any additions.
- `dist/` is generated output from `build.sh`; keep it out of version control and treat it as disposable.
- Packaging helpers (`build.sh`, `Info.plist`, `entitlements.plist`, `macvimswitch.rb`) define bundle metadata, signing, and Homebrew distribution—mirror their patterns when adding new tooling.

## Build, Test & Development Commands
- `./build.sh` — builds universal arm64/x86_64 binaries, recreates `dist/MacVimSwitch.app`, and signs with local entitlements.
- `./build.sh --create-dmg` — runs the full build and emits `MacVimSwitch.dmg` for release validation.
- After building, run `pkill -f MacVimSwitch` to stop old instances, then launch the fresh binary via `./dist/MacVimSwitch.app/Contents/MacOS/macvimswitch` for manual testing.

## Coding Style & Naming Conventions
- Follow the existing Swift style: 4-space indentation, same-line braces, `UpperCamelCase` for types, `lowerCamelCase` for functions/properties, and descriptive enum/raw value names.
- Keep feature logic inside the dedicated managers (status bar, keyboard, preferences, updates). Reuse `UserPreferences` for persisted settings to avoid divergence.
- Use targeted `print` diagnostics when adding behavior—they feed directly into release troubleshooting.
- No formatter runs automatically; match surrounding code or run `swift-format` locally if you already use it.

## Testing Guidelines
- Automated tests are not yet present; rely on hands-on verification after each change:
  - Launch from `dist`, grant accessibility trust, and confirm ESC/Shift switching works in an allowed app while remaining idle elsewhere.
  - Toggle menu options (inputs, allowed apps, auto-launch) and ensure state persists across relaunches.
- When touching distribution flow, rerun `./build.sh --create-dmg` and confirm `codesign` completes without warnings.

## Commit & Pull Request Guidelines
- Use Conventional Commit prefixes observed in history (`feat:`, `fix:`, `docs:`, `ci:`) and keep commits focused.
- Exclude generated artifacts (`dist/`, DMGs) from commits; only include source, plist, or script updates.
- Pull requests should include: a concise summary of the change, manual test notes, linked issues when relevant, and screenshots or recordings for menu/UI adjustments.

## Security & Configuration Tips
- The app depends on accessibility permissions; advise reviewers to remove stale entries before testing new builds to avoid silent failures.
- Updating signing or entitlements? Re-run `codesign --force --deep --sign - --entitlements entitlements.plist dist/MacVimSwitch.app`, document the rationale, and note any additional macOS prompts reviewers should expect.
