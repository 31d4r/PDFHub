# Contributing to Beaver

Thank you for thinking about contributing to Beaver!

We welcome:

- Pull requests
- Bug reports
- Feature requests

## Before You Start

If you want to work on a new feature, open an issue first and describe what you're planning. This helps avoid duplicate work and lets others give feedback.

## Development

To run the app:

1. Clone the repo
2. Open `Beaver.xcodeproj` in Xcode
3. Build and run the `Beaver` scheme

Run the full test suite before opening a pull request. The command and testing conventions are in
[docs/testing.md](docs/testing.md).

## Commit Messages

Use [Conventional Commits](https://www.conventionalcommits.org): one line, `type(scope): summary`,
imperative mood, lowercase, no trailing period. Keep one concern per commit.

Types: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `build`, `perf`.

```
feat(rotation): add button to rotate pdf pages
fix(images): avoid crash when opening a large image
docs: describe the test command
```

## Bug Reports

Please report bugs using the [GitHub Issues](https://github.com/31d4r/PDFHub/issues) section. Include clear steps to reproduce the issue.

## Code Style

- Swift 6 language mode; use async/await rather than Dispatch or Combine.
- Put user-facing text in `DesignSystem` using `String(localized:)` and add it to
  `Localizable.xcstrings`.
- Use the named colours in the asset catalog so light and dark mode both work.
- Give icon-only buttons an accessibility label.
- New tests use Swift Testing.

---

Thanks for contributing!
