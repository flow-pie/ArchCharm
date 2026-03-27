# Contributing to ArchCharm

Thank you for considering contributing to ArchCharm! This document provides guidelines and instructions for contributing.

## How to Contribute

### Reporting Issues

- Search existing issues before opening a new one
- Include your Arch Linux version, installed packages, and relevant logs
- Attach screenshots if the issue is visual

### Submitting Changes

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Make your changes
4. Test your changes on a clean Arch install (VM or spare machine)
5. Commit with a descriptive message
6. Push to your fork
7. Open a Pull Request

### Adding New Application Configs

1. Create a directory under `dotfiles/` with your app name
2. Add the config files
3. Update `install.sh` to link the new directory
4. Update `uninstall.sh` to handle the new symlink
5. Document the addition in `README.md`

### Package Lists

- Add official repo packages to `packages-pacman.txt`
- Add AUR packages to `packages-aur.txt`
- One package per line
- Add a comment above groups of related packages

## Code Style

### Shell Scripts

- Use `#!/usr/bin/env bash` shebang
- Enable `set -euo pipefail`
- Use `readonly` for constants
- Prefix functions with descriptive names
- Use the existing color/logging helpers

### Config Files

- Keep configs minimal and well-commented
- Use the Noctalia color scheme where applicable
- Prefer XDG-compliant paths

## Testing

Before submitting:

1. Run `shellcheck` on all `.sh` files
2. Test the installer on a fresh Arch install
3. Verify all symlinks are created correctly
4. Ensure the uninstaller removes all symlinks

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
