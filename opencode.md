# SynapseOS — Engineering Session Log

## Repository

**GitHub**: `git@github.com:Nikhilanandd/SynapseOS.git`  
**Runner**: `kanchenjunga` (self-hosted, GitHub Actions)

---

## Session Timeline

### 1. Initial State (commit 4a827a4)

The repository contained:
- `build.sh` — 5 lines: `sudo lb clean && sudo lb build`
- `clean.sh` — empty
- `README.md` — 2 lines
- `config/` — standard Debian live-bookworm config with 4 package lists
- No `.gitignore`, no `scripts/`, no `output/`, no CI/CD

### 2. Build Infrastructure (commits c2fce88 → fb3a4b4)

Created the production-grade build system:

| File | Purpose |
|------|---------|
| `.gitignore` | Ignores `.build/`, `cache/`, `chroot/`, `binary/`, `output/`, `tmp/`, `*.iso` |
| `scripts/common.sh` | `detect_version()`, `ensure_root()`, `ensure_command()`, `check_disk()`, `check_memory()` |
| `scripts/logger.sh` | `log_init()`, `log_stage()`, `log_info()`, `log_warn()`, `log_error()` — timestamps + elapsed time |
| `scripts/validate.sh` | Pre-build validation: required commands, dirs, config files, disk, memory |
| `scripts/build.sh` | Build orchestration: `build_main()` |
| `scripts/metadata.sh` | JSON metadata generation with version, commit, branch, build time, ISO size |
| `build.sh` | Entry point: sources all modules, parses `--clean` and `--version` |
| `clean.sh` | Cleanup: removes all artifact dirs. `--all` also purges APT cache |
| `.github/workflows/build.yml` | CI/CD: validate → build → upload → release (on tag) |
| `README.md` | Full rewrite: vision, architecture, build process, contribution guide |

### 3. CI/CD Failure Resolution (commits 8e862ff → fb3a4b4)

Nine cycles of fix-push-test to get the pipeline green:

| # | Issue | Symptom | Fix |
|---|-------|---------|-----|
| 1 | `debootstrap` not in PATH | "MISSING: debootstrap" in validation | Updated `validate.sh` and `common.sh` to search `/usr/sbin:/sbin` |
| 2 | `lb build` skips config stage | "config stage required first" | Added explicit `sudo lb config` before `sudo lb build` |
| 3 | Root-owned `config/` subdirs block checkout | "EACCES: permission denied" on `config/apt/`, `local/bin` | Added `sudo chown` after `lb config` and after build; added Clean Workspace step |
| 4 | `gnome-desktop-environment` not in bookworm | "Unable to locate package" | Replaced with `task-gnome-desktop` |
| 5 | ISO volume label too long (33 > 32) | "xorriso FAILURE: -volid: Text too long" | Shortened `LB_ISO_VOLUME` in `config/binary`; inject overrides into `.build/config` |
| 6 | Root-owned artifacts persist after failure | Next run's checkout fails | Added `sudo lb clean` after build (both success and failure); added Post-Build Cleanup step |

### 4. e-Swecha GitLab Pipeline Reference

A working GitLab pipeline from a similar project (e-Swecha OS) was provided for reference. Key differences:

| e-Swecha (GitLab) | SynapseOS (GitHub Actions) |
|-------------------|---------------------------|
| `GIT_CLEAN_FLAGS` with `--exclude=cache/` | Not used — Clean Workspace removes everything explicitly |
| `RUNNER_CACHE_BASE` outside repo | Caches are in-repo and gitignored |
| `lb clean` in `after_script` | `lb clean` in `build.sh` after build + Post-Build Cleanup step |
| `sudo chown -R` in `after_script` | `sudo chown -R` in `build.sh` after `lb config` and after build |
| `resource_group` prevents concurrent builds | Not yet implemented |
| Preflight stage checks disk/memory/network | Done in validate job |
| Build script (`ci/build.sh`) managed externally | Build logic in `scripts/build.sh` (sourced by `build.sh`) |

---

## Architecture Decisions

### Build Flow

```
build.sh (entry point)
  ├── source scripts/common.sh    (version, utils)
  ├── source scripts/logger.sh    (logging)
  ├── source scripts/validate.sh  (pre-build checks)
  ├── source scripts/metadata.sh  (post-build metadata)
  ├── source scripts/build.sh     (build_main function)
  └── build_main "$clean_flag"
       ├── log_init()
       ├── validate()
       ├── sudo lb config
       ├── inject overrides into .build/config
       ├── sudo lb build
       ├── move ISO → output/
       ├── generate SHA256SUMS
       ├── generate package.manifest
       ├── generate metadata.json
       ├── sudo lb clean
       └── sudo chown
```

### Version Scheme

- Tagged: `v1.2.3` → version `1.2.3`
- Untagged: commit hash → version `a65e6c4`
- Dirty: appends `-dirty`

### Output Artifacts

All in `output/`:
- `synapseos-<version>-amd64.hybrid.iso`
- `SHA256SUMS`
- `metadata.json` (version, git_commit, git_branch, build_time, debian_version, kernel_version, package_count, iso_size, builder_name, build_machine)
- `package.manifest`
- `build.log`

---

### 5. Feature Completion — Concurrent Locks, Cache, QEMU Test, Branding (Session 5)

All five remaining issues from the previous session were addressed:

| # | Issue | Changes |
|---|-------|---------|
| 1 | **GNOME desktop** | Refined package lists: added `gnome-terminal`, `gnome-software`, `firefox-esr`, `network-manager-gnome` to `desktop.list.chroot`; added `docker-compose`, `python3-venv`, `openssh-server`, `tmux`, `rsync`, `unzip`, `ca-certificates`, `software-properties-common`, `apt-transport-https`, `gnupg` across `core.list.chroot` and `dev.list.chroot` |
| 2 | **Concurrent builds** | Added `_acquire_lock()`/`_release_lock()` to `scripts/build.sh` — creates `.build.lock` with PID, checks for live/stale locks, cleans up on EXIT/INT/TERM via trap |
| 3 | **Cache preservation** | Removed `cache/` from Clean Workspace and Post-Build Cleanup in `.github/workflows/build.yml` so bootstrap/package caches persist across CI runs |
| 4 | **QEMU boot verification** | Created `scripts/test-qemu.sh` — boots ISO in QEMU with KVM, polls serial console for `login:` prompt (120s timeout), detects kernel panics. Added as optional CI step with `continue-on-error: true` and KVM detection |
| 5 | **GNOME branding** | Created `config/includes.chroot/` with: custom `/etc/os-release` (PRETTY_NAME="SynapseOS 1.0"), GNOME gschema overrides (dark theme, custom wallpaper, privacy defaults, keybindings), `/etc/skel/.bashrc` with colored prompt and aliases, SVG wallpaper with neural-network-inspired design (gradient background with connection nodes). Created `config/hooks/live/9010_synapseos_branding.chroot` to compile glib schemas and set hostname |

### New/Modified Files

| File | Change |
|------|--------|
| `scripts/build.sh` | Added `_acquire_lock()`/`_release_lock()` lock mechanism with trap-based cleanup |
| `.github/workflows/build.yml` | Preserves `cache/` across CI runs; added QEMU boot test step |
| `scripts/test-qemu.sh` | **New** — automated ISO boot verification via QEMU |
| `config/package-lists/core.list.chroot` | Added `ca-certificates`, `software-properties-common`, `apt-transport-https`, `gnupg` |
| `config/package-lists/desktop.list.chroot` | Added `gnome-terminal`, `gnome-software`, `firefox-esr`, `network-manager-gnome` |
| `config/package-lists/dev.list.chroot` | Added `docker-compose`, `python3-venv`, `openssh-server`, `tmux`, `rsync`, `unzip` |
| `config/includes.chroot/etc/os-release` | **New** — SynapseOS branding metadata |
| `config/includes.chroot/etc/skel/.bashrc` | **New** — default user shell config with colored prompt |
| `config/includes.chroot/usr/share/glib-2.0/schemas/90_synapseos.gschema.override` | **New** — GNOME dark theme, wallpaper, privacy, keybindings |
| `config/includes.chroot/usr/share/backgrounds/synapseos/synapseos-wallpaper.svg` | **New** — custom SVG wallpaper (1920x1080, dark gradient with synaptic node motif) |
| `config/hooks/live/9010_synapseos_branding.chroot` | **New** — compiles glib schemas, sets hostname, configures APT sources |
| `.gitignore` | Added `.build.lock` |

---

## Architecture Decisions (Updated)

### Build Flow (Updated)

```
build.sh (entry point)
  ├── source scripts/common.sh    (version, utils)
  ├── source scripts/logger.sh    (logging)
  ├── source scripts/validate.sh  (pre-build checks)
  ├── source scripts/metadata.sh  (post-build metadata)
  ├── source scripts/build.sh     (build_main function)
  └── build_main "$clean_flag"
       ├── _acquire_lock()        ← NEW: PID lock file
       ├── log_init()
       ├── validate()
       ├── sudo lb config
       ├── inject overrides into .build/config
       ├── sudo lb build
       ├── move ISO → output/
       ├── generate SHA256SUMS
       ├── generate package.manifest
       ├── generate metadata.json
       ├── sudo lb clean
       ├── sudo chown
       └── _release_lock()        ← NEW: trap-based cleanup
```

### Branding Architecture

```
config/includes.chroot/
└── usr/share/
    ├── backgrounds/synapseos/synapseos-wallpaper.svg  (SVG wallpaper)
    ├── glib-2.0/schemas/90_synapseos.gschema.override (GNOME settings)
    └── etc/
        ├── os-release                                 (distro metadata)
        └── skel/.bashrc                               (default user shell)

config/hooks/live/
└── 9010_synapseos_branding.chroot                     (chroot hook: compiles schemas, sets hostname)
```

---

## Remaining Issues (Next Session)

1. **First CI build**: Push to `develop` or `main` to trigger the pipeline. The bootstrap + package downloads for `task-gnome-desktop` (~3GB) will take 30-60 min. If it fails, check logs with `gh run view <run-id> --log-failed`.

2. **GNOME wallpaper rendering**: The SVG wallpaper uses gradients and opacity — confirm GNOME 43 (bookworm) renders it correctly. If not, convert to PNG.

3. **GDM greeter branding**: The gschema overrides apply to the user session but not to GDM. Add `config/includes.chroot/usr/share/glib-2.0/schemas/90_synapseos_gdm.gschema.override` for GDM theming (requires `gdm` user schema compilation).

4. **Edition profiles**: Developer, AI, Research, Student, Minimal editions would use different package lists and hooks.

5. **ARM64 cross-build**: Needs `LB_BOOTSTRAP_QEMU_ARCHITECTURE="arm64"` and QEMU user static.

---

## Debugging Tips

- View logs: `gh run view <run-id> --log-failed`
- Get job logs: `gh api repos/Nikhilanandd/SynapseOS/actions/jobs/<job-id>/logs`
- The runner is on `kanchenjunga` — login to check disk, memory, or zombie processes
- If workspace cleanup fails, `sudo rm -rf /home/github-runner/actions-runner/_work/SynapseOS/` on the runner

## Key Commands

```bash
./build.sh --version              # Print version
sudo ./build.sh                   # Incremental build
sudo ./build.sh --clean           # Full clean build
sudo ./clean.sh                   # Remove artifacts
sudo ./clean.sh --all             # Remove artifacts + purge caches
./scripts/validate.sh             # Pre-build validation
sudo lb clean --purge             # Manual live-build cleanup
```
