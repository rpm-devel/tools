# rpm-devel tools

Build, package, sign, and distribute RPMs for RHEL 7–10, Fedora, and derivatives (AlmaLinux, Rocky, Oracle Linux, CentOS).

## Quick start

```shell
bash -c "$(curl -q -LSsf "https://github.com/rpm-devel/tools/raw/main/install.sh")"
```

This installs the scripts to `/usr/local/bin` (root) or `~/.local/bin` (user) and sets up `~/.rpmmacros`.

## Tools

### create-container.sh

Creates Docker build containers for cross-arch RPM builds.

```shell
# Create all containers (EL 8/9/10 + Fedora, both amd64 and arm64)
create-container.sh all

# Create a specific version and arch
create-container.sh 10 amd64
create-container.sh fedora arm64

# Enter an existing container
create-container.sh --enter almalinux 10 amd64

# Remove containers
create-container.sh remove all
create-container.sh remove 9 amd64
```

**Options:**

| Option | Description |
|--------|-------------|
| `all` | Create containers for all enabled versions and arches |
| `arm` | Create all versions for arm64 only |
| `amd` | Create all versions for amd64 only |
| `7/8/9/10` | Create a specific EL version |
| `fedora` | Create Fedora containers |
| `--enter` | Enter the container after creation |
| `--remove` | Remove a container |
| `--platform <arch>` | Override the default platform |
| `--image <name>` | Override the container image |

**Configuration:** `~/.config/rpm-devel/settings.conf`

---

### rpmbuild.sh

Builds all (or specific) spec files, installs dependencies, downloads sources, and signs packages.

```shell
# Build all specs in ~/rpmbuild/
rpmbuild.sh

# Build a single package
rpmbuild.sh nginx

# Build without signing
rpmbuild.sh --no-sign

# Update tools first
rpmbuild.sh update
```

**What it does:**

1. Finds all `.spec` files in `~/rpmbuild/`
2. Downloads sources with `spectool -g -R`
3. Installs build dependencies with `dnf builddep` (or `yum-builddep`)
4. Runs `rpmbuild -ba` for each spec
5. Signs all built RPMs with your GPG key
6. Prints a build summary (passed/failed)

**Output directories:**
- Built RPMs: `~/Documents/builds/rpmbuild/{DISTRO}/{NAME}{VER}/{ARCH}/`
- Build logs: `~/Documents/builds/logs/rpmbuild/`

---

### make-repo

Signs built RPMs, runs `createrepo`, and syncs the release directories to SourceForge and a local FTP server.

```shell
# Full run: sign, createrepo, sync
make-repo

# Dry run (show what would be done)
make-repo --dry-run

# Set arch and version explicitly
make-repo --arch x86_64 --version 10

# Skip remote sync
make-repo --skip-ftp --skip-sourceforge
```

**What it does:**

1. Signs all packages with `rpm --addsign`
2. Moves SRPMs from the build tree into the release tree
3. Moves debug RPMs (`*debuginfo*`, `*debugsource*`) into the `debug/` subdir
4. Runs `createrepo_c` (or `createrepo`) on each repo directory
5. Syncs to local FTP server (`ftp.casjaysdev.pro`)
6. Syncs to SourceForge web hosting (`web.sourceforge.net`)
7. Syncs to SourceForge FRS download mirrors (`frs.sourceforge.net`)

**Local staging layout** (`~/Documents/builds/sourceforge/{DISTRO}/{NAME}{VER}/`):

```
{ARCH}/
  rpms/     binary RPMs
  addons/   addon packages
  extras/   extra packages
  debug/    debuginfo and debugsource RPMs
srpms/      source RPMs (shared across arches)
```

This same layout is mirrored verbatim to FTP and SourceForge.

**Configuration:** `~/.config/rpm-devel/make-repo-settings.conf`

---

### create-mirror

Downloads upstream repos to a local mirror tree using `reposync`. Supports RHEL/AlmaLinux, CentOS (vault), and Fedora. Only the newest RPM for each package is kept (`--newest-only`).

```shell
# Mirror RHEL/AlmaLinux 9 (defaults to host arch)
create-mirror -v 9

# Mirror CentOS 7 from vault (x86_64 only)
create-mirror -d centos -v 7

# Mirror CentOS 6 from vault (x86_64 only)
create-mirror -d centos -v 6

# Mirror Fedora 41
create-mirror -d fedora -v 41

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
| `-v, --version` | Major version to mirror: 6, 7, 8, 9, 10 |
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
| `srpms/`  | `*-srpm`, `*-SRPMS`, `*-source` |
| `addons/` | Everything else (OS, languages, databases, infra, etc.) |
| *(skipped)* | `casjay-rpms`, `casjay-addons`, `casjay-extras`, `casjay-debug`, `casjay-sources`, `casjay-packages`, `casjay-testing` — local repos, not mirrored |

Repo files are read from `casjay-release/` (checked in `~/rpmbuild/`, `~/Projects/github/rpm-devel/`, and `~/Projects/local/system/repo/rpm-devel/`).

**Configuration:** `~/.config/rpm-devel/create-mirror-settings.conf`  
**Logs:** `/var/log/rpm-devel/mirror/`

---

### bootstrap

Bootstraps a fresh container for RPM building. Typically called automatically by `create-container.sh`.

```shell
# Usually called automatically; can be run manually inside a container
bootstrap
```

Installs build tools, sets up rpmbuild directories, and configures the environment.

---

### bogusDate

Fixes incorrect weekday names in spec file `%changelog` entries.

```shell
# Fix bogus dates in a spec file
bogusDate mypackage.spec

# Fix multiple specs
bogusDate *.spec
```

RPM warns about "bogus date" when the weekday does not match the actual date (e.g., `Thu` written for a day that was a Friday). This script automatically corrects them.

---

## Workflow

```
1. Install tools            →  install.sh
2. Create build containers  →  create-container.sh all
3. Enter a container        →  create-container.sh --enter almalinux 10 amd64
4. Build packages           →  rpmbuild.sh
5. Release packages         →  make-repo
6. Mirror upstream repos    →  create-mirror -v 9   (separate, optional)
```

## Configuration

All configuration lives in `~/.config/rpm-devel/`:

| File | Purpose |
|------|---------|
| `settings.conf` | Container settings (images, versions, paths) |
| `make-repo-settings.conf` | Release settings (SourceForge user, FTP host/dir) |
| `create-mirror-settings.conf` | Mirror settings (mirror root, excluded repos) |

## Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SOURCEFORGE_USER` | *(required)* | Your SourceForge username |
| `FTP_USER` | `root` | FTP server username |
| `MIRROR_ROOT` | `/var/ftp/pub/mirror` | Root of the local mirror tree |
| `ENABLE_VERSION_8` | `yes` | Build containers for EL8 |
| `ENABLE_VERSION_9` | `yes` | Build containers for EL9 |
| `ENABLE_VERSION_10` | `yes` | Build containers for EL10 |
| `ENABLE_FEDORA` | `yes` | Build containers for Fedora |

## Supported platforms

- **Build host:** x86_64 Linux with Docker
- **Target arches:** x86_64, aarch64 (via QEMU user-static)
- **Target distros:** RHEL/AlmaLinux/Rocky/Oracle 7–10, Fedora, CentOS 7 (vault), CentOS 6 (vault)

## Spec Repo Layout

Every individual package repo (e.g. `certbot`, `cmus`, `nginx`, `git`, `nano`) uses a **flat layout** — all files live directly at the repository root. There are no `SPEC/`, `SOURCES/`, or `Makefile` subdirectories.

```
{package}/
  {package}.spec          ← spec file at root
  {package}-{ver}.tar.gz  ← upstream source tarball(s), if committed
  *.patch                 ← patches, if any
  sources                 ← spectool/lookaside cache hash file, if used
```

Rules:
- One spec file per repo, named `{package}.spec`, at the root
- Source tarballs referenced by `SourceN:` URLs are downloaded by `spectool -g -R` at build time — only commit them when they cannot be fetched from a canonical upstream URL
- No `Makefile`, no `IDEA.md`, no `AI.md`, no `.github/` workflows in package repos
- `bogusDate {package}.spec` before every commit to fix changelog weekday names

---

## Related repos

- [rpm-devel](https://github.com/rpm-devel) — GitHub org with all spec files
- [casjay-release](https://github.com/rpm-devel/casjay-release) — Repo config package
- [SourceForge mirrors](https://rpm-devel.sourceforge.io/) — Package mirror site

See [LAYOUT.md](LAYOUT.md) for the complete repo-ID → directory mapping reference.
