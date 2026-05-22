# rpm-devel tools

Build, package, sign, and distribute RPMs for RHEL 7–10, Fedora, and derivatives
(AlmaLinux, Rocky, Oracle Linux, CentOS).

All builds run inside `ghcr.io/rpm-devel/build:latest` — a single container image
that ships `mock`, `rpmbuild`, `spectool`, and every required tool.
No host toolchain, no per-distro containers, no QEMU setup required.

## Quick start

```shell
bash -c "$(curl -q -LSsf "https://github.com/rpm-devel/tools/raw/main/install.sh")"
```

This installs the scripts to `/usr/local/bin` (root) or `~/.local/bin` (user)
and writes `~/.rpmmacros` with your GPG key settings.

---

## Workflow

```
1. Install tools            →  install.sh
2. Pull the build image     →  create-container.sh pull
3. Place spec files         →  clone repos into ~/rpmbuild/SPECS/ (or symlink)
4. Build packages           →  rpmbuild.sh
5. Release packages         →  make-repo
6. Mirror upstream repos    →  create-mirror -v 9   (separate, optional)
```

### Step 3 in detail — placing spec files

Each package lives in its own repo under the `rpm-devel` GitHub org.
Clone the repos you want to build and place (or symlink) the `.spec` files
under `~/rpmbuild/SPECS/`:

```shell
# Example: build cmus and nginx
git clone https://github.com/rpm-devel/cmus  ~/Projects/github/rpm-devel/cmus
git clone https://github.com/rpm-devel/nginx ~/Projects/github/rpm-devel/nginx

ln -s ~/Projects/github/rpm-devel/cmus/cmus.spec  ~/rpmbuild/SPECS/
ln -s ~/Projects/github/rpm-devel/nginx/nginx.spec ~/rpmbuild/SPECS/
```

`spectool -g -R` (run by the build container) downloads all `SourceN:` tarballs
automatically; you do not need to commit upstream tarballs to the spec repos.

---

## Tools

### create-container.sh

Pulls and manages `ghcr.io/rpm-devel/build:latest`.
One image handles all distro targets via `mock` inside the container.

```shell
# Pull / update the build image
create-container.sh pull

# Enter an interactive shell (useful for debugging a build)
create-container.sh enter

# Enter with a specific mock target preset
create-container.sh 9 amd64          # RPM_TARGET=almalinux-9-x86_64
create-container.sh 10 arm64         # RPM_TARGET=almalinux-10-aarch64
create-container.sh fedora amd64     # RPM_TARGET=fedora-42-x86_64
create-container.sh 7                # RPM_TARGET=eol/centos-7-x86_64

# Pass a raw mock config name
create-container.sh almalinux-9-x86_64

# List all available mock targets
create-container.sh list

# Remove stale build containers (not the image)
create-container.sh remove
```

**Commands / options:**

| Command / Option | Description |
|-----------------|-------------|
| `pull` / `all` | Pull or update `ghcr.io/rpm-devel/build:latest` |
| `enter` | Interactive shell with all standard mounts |
| `list` | Print all available mock target names |
| `remove` | Remove stale containers with the `rpmbuild-` prefix |
| `7` / `8` / `9` / `10` | Enter with the matching AlmaLinux / CentOS target |
| `fedora` | Enter with `fedora-{FEDORA_VERSION}-{arch}` |
| `--platform <arch>` | Force `linux/amd64` or `linux/arm64` |
| `--image <name>` | Override the build image |
| `--config` | (Re)generate `~/.config/rpm-devel/settings.conf` |

**Mounts (always applied):**

| Host path | Container path | Mode |
|-----------|---------------|------|
| `~/rpmbuild` | `/root/rpmbuild` | rw |
| `~/Documents/builds` | `/root/Documents/builds` | rw |
| `~/.rpmmacros` | `/root/.rpmmacros` | ro |
| `~/.gnupg` | `/root/.gnupg` | ro |

**Configuration:** `~/.config/rpm-devel/settings.conf`

---

### rpmbuild.sh

Builds spec files for every enabled mock target using the build container.
`mock` inside the container installs `BuildRequires` and builds in a clean chroot —
no host packages, no dependency pollution between builds.

```shell
# Build all specs in ~/rpmbuild/SPECS/ for all enabled targets
rpmbuild.sh

# Build one package across all enabled targets
rpmbuild.sh nginx

# Build for a specific mock target only
rpmbuild.sh --target almalinux-9-x86_64

# Build for multiple explicit targets
rpmbuild.sh --target almalinux-9-x86_64 --target almalinux-9-aarch64

# Build without GPG signing
rpmbuild.sh --no-sign

# List all targets that would be built (dry-run for target list)
rpmbuild.sh --list-targets

# Update tools
rpmbuild.sh update
```

**What it does:**

1. Reads enabled targets from `~/.config/rpm-devel/settings.conf`
2. For each spec × each target, runs:
   ```
   docker run --rm --privileged ghcr.io/rpm-devel/build:latest /root/rpmbuild/SPECS/pkg.spec
   ```
   The container runs `spectool`, `rpmbuild -bs`, and `mock --rebuild` automatically.
3. Moves built RPMs from the container output dir into the `make-repo`-compatible tree:
   `~/Documents/builds/rpmbuild/{DISTRO}/{rel}{VER}/{ARCH}/`
4. Optionally signs all built RPMs with your GPG key
5. Prints a per-package pass/fail summary

**Enabled targets (defaults):**

| Setting | Mock targets |
|---------|-------------|
| `ENABLE_VERSION_7=no` | `eol/centos-7-x86_64`, `eol/centos-7-aarch64` |
| `ENABLE_VERSION_8=yes` | `almalinux-8-x86_64`, `almalinux-8-aarch64` |
| `ENABLE_VERSION_9=yes` | `almalinux-9-x86_64`, `almalinux-9-aarch64` |
| `ENABLE_VERSION_10=yes` | `almalinux-10-x86_64`, `almalinux-10-aarch64` |
| `ENABLE_FEDORA=yes` | `fedora-{N}-x86_64`, `fedora-{N}-aarch64` |

**Output:**
- Built RPMs: `~/Documents/builds/rpmbuild/{DISTRO}/{rel}{VER}/{ARCH}/`
- Build logs: `~/Documents/builds/logs/rpmbuild/{package}/`

**Configuration:** `~/.config/rpm-devel/settings.conf`

---

### make-repo

Signs built RPMs, runs `createrepo`, and syncs the release tree to SourceForge
and a local FTP server.
Run after `rpmbuild.sh` to publish what was just built.

```shell
# Full run: sign, createrepo, sync
make-repo

# Dry run (show what would be done without doing it)
make-repo --dry-run

# Override the distro/version/arch being published
make-repo --name el --version 9 --arch x86_64

# Skip remote sync
make-repo --skip-ftp --skip-sourceforge
```

**What it does:**

1. Signs all RPMs and SRPMs under `~/Documents/builds/rpmbuild/` with `rpm --addsign`
2. Moves SRPMs into the release tree's `srpms/` directory
3. Moves `*debuginfo*` / `*debugsource*` RPMs into `debug/`
4. Runs `createrepo_c` on `rpms/`, `addons/`, `extras/`, `debug/`, and `srpms/`
5. Syncs to local FTP server (`ftp.casjaysdev.pro`)
6. Syncs to SourceForge web hosting (`web.sourceforge.net`)
7. Syncs to SourceForge FRS download mirrors (`frs.sourceforge.net`)

**Release tree layout** (`~/Documents/builds/sourceforge/{DISTRO}/{rel}{VER}/`):

```
{ARCH}/
  rpms/     CasjaysDev-built binary RPMs
  addons/   Upstream third-party mirrors
  extras/   Community extras (EPEL, RPM Fusion, ELRepo)
  debug/    debuginfo and debugsource RPMs
srpms/      Source RPMs (shared across arches)
```

This layout is mirrored verbatim to FTP and SourceForge.

**Configuration:** `~/.config/rpm-devel/make-repo-settings.conf`

---

### create-mirror

Downloads upstream repos to a local mirror tree using `reposync`.
Supports RHEL/AlmaLinux, CentOS (vault), and Fedora.
Only the newest RPM for each package is kept (`--newest-only`).

```shell
# Mirror RHEL/AlmaLinux 9 (defaults to host arch)
create-mirror -v 9

# Mirror CentOS 7 from vault (x86_64 only)
create-mirror -d centos -v 7

# Mirror Fedora 42
create-mirror -d fedora -v 42

# Mirror a specific repo only
create-mirror -v 9 -r casjay-epel

# Dry run — show what would be synced
create-mirror -v 10 --dry-run

# Skip re-signing after sync
create-mirror -v 9 --no-sign
```

**Options:**

| Option | Description |
|--------|-------------|
| `-d, --distro` | Distribution: `rhel` (default), `centos`, `fedora` |
| `-v, --version` | Major version: 6, 7, 8, 9, 10 |
| `-a, --arch` | Architecture (default: host arch) |
| `-r, --repos` | Comma-separated repo IDs to sync (default: all enabled) |
| `--dry-run` | Show what would be synced without doing it |
| `--no-sign` | Skip re-signing packages after sync |

**Mirror layout** (root: `/var/ftp/pub/mirror`):

```
{RHEL,CentOS,Fedora}/{VER}/{ARCH}/
  addons/   OS base, third-party (Docker, MariaDB, PostgreSQL, Remi, etc.)
  extras/   Community repos (EPEL, RPMFusion, ELRepo)
  debug/    debuginfo and debugsource RPMs
{RHEL,CentOS,Fedora}/{VER}/
  srpms/    source RPMs (arch-independent)
```

Repos routed to each directory:

| Directory | Repo IDs matched |
|-----------|-----------------|
| `extras/` | `casjay-epel`, `casjay-rpmfusion*`, `casjay-gf`, `casjay-elrepo*` |
| `srpms/` | `*-srpm`, `*-SRPMS`, `*-source` |
| `addons/` | Everything else (OS, languages, databases, infra, etc.) |
| *(skipped)* | `casjay-rpms`, `casjay-addons`, `casjay-extras`, `casjay-debug`, `casjay-sources`, `casjay-packages`, `casjay-testing` — local repos, not mirrored |

Repo files are read from `casjay-release/` (checked in `~/rpmbuild/`,
`~/Projects/github/rpm-devel/`, and `~/Projects/local/system/repo/rpm-devel/`).

**Configuration:** `~/.config/rpm-devel/create-mirror-settings.conf`
**Logs:** `/var/log/rpm-devel/mirror/`

---

### bootstrap

Sets up rpmbuild directories and installs base build tools.
Useful when configuring a new host or a manually created container.
In the normal workflow this step is not needed — `rpmbuild.sh` handles
everything inside the build container automatically.

```shell
bootstrap
```

---

### bogusDate

Fixes incorrect weekday names in spec file `%changelog` entries.

```shell
# Fix one spec
bogusDate cmus.spec

# Fix all specs at once
bogusDate *.spec
```

RPM rejects changelogs where the weekday does not match the calendar date
(e.g. `Thu` written for a Friday). Run `bogusDate` before every commit.

---

## Configuration

All configuration lives in `~/.config/rpm-devel/`:

| File | Used by | Purpose |
|------|---------|---------|
| `settings.conf` | `create-container.sh`, `rpmbuild.sh` | Build image, enabled targets, paths |
| `make-repo-settings.conf` | `make-repo` | SourceForge user, FTP host/dir |
| `create-mirror-settings.conf` | `create-mirror` | Mirror root, excluded repos |

Generate the default `settings.conf`:

```shell
create-container.sh --config
```

## Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `BUILD_IMAGE` | `ghcr.io/rpm-devel/build:latest` | Build container image |
| `RPM_GPG_KEY_ID` | *(from `.rpmmacros`)* | GPG key for signing built RPMs |
| `ENABLE_VERSION_7` | `no` | Build EL7 targets |
| `ENABLE_VERSION_8` | `yes` | Build EL8 targets |
| `ENABLE_VERSION_9` | `yes` | Build EL9 targets |
| `ENABLE_VERSION_10` | `yes` | Build EL10 targets |
| `ENABLE_FEDORA` | `yes` | Build Fedora targets |
| `FEDORA_VERSION` | `42` | Fedora version number |
| `SOURCEFORGE_USER` | *(required for sync)* | Your SourceForge username |
| `FTP_USER` | `root` | FTP server username |
| `MIRROR_ROOT` | `/var/ftp/pub/mirror` | Root of the local mirror tree |

## Supported platforms

- **Build host:** x86_64 Linux with Docker
- **Build container:** `ghcr.io/rpm-devel/build:latest` (Fedora-based, multi-arch)
- **Target arches:** x86_64, aarch64 — mock handles cross-arch builds inside the container
- **Target distros:** RHEL/AlmaLinux/Rocky/Oracle 8–10, CentOS 7 (EOL), Fedora current + rawhide

## Spec Repo Layout

Every package repo uses a **flat layout** — spec file and any committed sources
sit directly at the repository root. No `SPEC/`, `SOURCES/`, or `Makefile`.

```
{package}/
  {package}.spec          ← spec file at root
  {package}-{ver}.tar.gz  ← committed sources (only when not fetchable upstream)
  *.patch                 ← patches, if any
  sources                 ← lookaside hash file, if used
```

Rules:
- One spec per repo, named `{package}.spec`, at the root
- `SourceN:` tarballs are downloaded by `spectool -g -R` at build time
- No `Makefile`, `IDEA.md`, `AI.md`, or `.github/` in package repos
- Run `bogusDate {package}.spec` before every commit

---

## Related repos

- [rpm-devel](https://github.com/rpm-devel) — GitHub org with all spec files
- [casjay-release](https://github.com/rpm-devel/casjay-release) — Repo config package
- [SourceForge mirrors](https://rpm-devel.sourceforge.io/) — Package mirror site

See [LAYOUT.md](LAYOUT.md) for the complete repo-ID → directory mapping reference.
