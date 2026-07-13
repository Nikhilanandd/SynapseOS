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

## Remaining Issues (Next Session)

1. **GNOME desktop installation**: `task-gnome-desktop` pulls in ~3GB of packages. The build succeeded in reaching the binary stage (xorriso) in 46 minutes before the volume label error was fixed. Next build should produce a bootable ISO.

2. **Concurrent builds**: No lock mechanism. Two pushes close together would race on the same runner (`kanchenjunga`). Add a `resource_group`-style lock.

3. **Cache preservation**: `cache/` is deleted by Clean Workspace. For incremental builds in CI, the cache should be preserved (like e-Swecha does with `GIT_CLEAN_FLAGS: "--exclude=cache/"`).

4. **QEMU boot verification**: No automated ISO boot test yet.

5. **GNOME branding**: `task-gnome-desktop` installs stock Debian GNOME. No SynapseOS theming exists yet.

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
