# SynapseOS

**Debian-based AI-native Linux distribution** — built from source with live-build.

SynapseOS provides a zero-configuration development workstation for AI engineering,
cloud development, cybersecurity research, and reproducible environments.

---

## Vision

A production-grade operating system where a user can install and immediately begin
building AI, cloud, DevOps, and research projects — no configuration required.

## Goals

- Zero-configuration development workstation
- AI development and coding agent toolchain pre-installed
- Reproducible builds with semantic versioning
- Multi-edition profiles (Developer, AI, Research, Student, Minimal)
- Cross-architecture support (amd64, ARM64)
- Automated CI/CD pipeline with artifact publishing

## Architecture

```
SynapseOS/
├── build.sh                  # Single entry point for building
├── clean.sh                  # Clean build artifacts
├── .github/workflows/        # CI/CD pipeline definitions
├── config/                   # live-build configuration
│   ├── common                # Shared build options
│   ├── bootstrap             # debootstrap settings
│   ├── chroot                # Chroot filesystem options
│   ├── binary                # ISO/image output options
│   ├── package-lists/        # Package selection manifests
│   ├── hooks/                # Build hooks (normal + live)
│   ├── includes.*/           # File inclusion directories
│   └── preseed/              # Debian installer preseed
├── scripts/                  # Build system modules
│   ├── common.sh             # Shared utilities (sourced)
│   ├── logger.sh             # Structured logging (sourced)
│   ├── validate.sh           # Pre-build validation
│   ├── build.sh              # Build orchestration (sourced)
│   └── metadata.sh           # Release metadata generation
└── output/                   # Build artifacts (gitignored)
    ├── *.iso                 # ISO image
    ├── SHA256SUMS            # Checksums
    ├── metadata.json         # Build metadata
    ├── package.manifest      # Installed packages
    └── build.log             # Build log
```

## Requirements

| Requirement | Minimum | Recommended |
|---|---|---|
| Architecture | amd64 | amd64 |
| Disk Space | 10 GB | 25 GB |
| Memory | 2 GB | 8 GB |
| OS | Debian 12+ | Debian 12+ |
| Packages | live-build, debootstrap, xorriso, mksquashfs | — |

Install build dependencies on Debian:

```bash
sudo apt-get update
sudo apt-get install -y live-build debootstrap xorriso squashfs-tools
```

## Build Process

Build SynapseOS with a single command:

```bash
sudo ./build.sh
```

For a clean build (purges caches, full rebuild):

```bash
sudo ./build.sh --clean
```

Print the current version:

```bash
./build.sh --version
```

The build system handles:

- Pre-build validation (dependencies, disk, memory)
- live-build execution with full logging
- ISO image generation with semantic versioning
- Checksum generation (SHA256)
- Package manifest extraction
- Release metadata generation

All artifacts are placed in `output/`.

## Versioning

SynapseOS follows [Semantic Versioning](https://semver.org/).

- Tagged releases: `v1.2.3` → version `1.2.3`
- Untagged commits: `0.0.0-g<abbrev-commit>`
- Dirty working tree: appends `-dirty`

The version is embedded in:

- ISO filename (`synapseos-<version>-amd64.hybrid.iso`)
- `/etc/os-release` (in the built image)
- `metadata.json`
- Volume label

## Repository Layout

| Path | Purpose |
|---|---|
| `config/` | live-build configuration tree |
| `config/package-lists/` | Package manifests by category |
| `scripts/` | Build system modules |
| `output/` | Build artifacts (gitignored) |
| `.github/workflows/` | CI/CD automation |

## CI/CD

The project uses GitHub Actions with self-hosted runners.

Pipeline stages:

1. **Checkout** — fetch source with full git history
2. **Validate** — run `scripts/validate.sh`
3. **Build** — run `sudo ./build.sh`
4. **Artifact** — upload `output/` to workflow run
5. **Release** — on tag push `v*`, create GitHub Release with all artifacts

## Contribution Guide

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Make changes to `config/` or `scripts/`
4. Run validation: `./scripts/validate.sh`
5. Submit a pull request

### Guidelines

- All scripts use `set -Eeuo pipefail`
- No hardcoded paths — use `$PROJECT_ROOT`
- No logic duplication between shell scripts and CI workflows
- Package lists go in `config/package-lists/*.list.chroot`
- Build hooks go in `config/hooks/`
- Functions are documented in the source

## Release Process

```bash
# Tag the release
git tag -a v1.0.0 -m "SynapseOS 1.0.0"
git push origin v1.0.0

# CI automatically builds and publishes
```

Hotfixes follow the same process from a maintenance branch.

## Roadmap

- [x] Build infrastructure (live-build, validation, logging)
- [x] CI/CD pipeline with artifact publishing
- [x] Semantic versioning and release automation
- [x] Desktop profiles (GNOME)
- [x] SynapseOS branding (wallpaper, theming, os-release)
- [x] QEMU boot verification
- [x] AI toolchain installer (first-boot profile selector)
- [x] VSCodium, OpenCode, Ollama, Aider, Jupyter, Streamlit
- [x] AI Researcher profile (PyTorch, LangChain, Transformers, Whisper)
- [x] AI Agent profile (AutoGen, CrewAI, LangChain, ChromaDB)
- [ ] Desktop profiles (KDE, Sway)
- [ ] Edition profiles (Research, Student)
- [ ] NVIDIA GPU driver integration
- [ ] ARM64 cross-build support
- [ ] Offline installer
- [ ] Calamares graphical installer
- [ ] SynapseOS package repository

## Screenshots

*(Screenshots will be added after the first successful build.)*

## License

GNU General Public License v3.0 — see [LICENSE](LICENSE).
