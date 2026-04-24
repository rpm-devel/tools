# rpm-devel tools

Build, package, sign, and distribute RPMs for RHEL 7-10, Fedora 38+, and derivatives (AlmaLinux, Rocky, Oracle Linux, CentOS).

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
- Built RPMs: `~/Documents/builds/rpmbuild/RHEL/el{VER}/{ARCH}/`
- Build logs: `~/Documents/builds/logs/rpmbuild/`

### make-repo

Organizes built RPMs into repo structure, runs `createrepo`, and syncs to SourceForge/FTP mirrors.

```shell
# Full run: organize, createrepo, sign, sync
make-repo

# Dry run (show what would be done)
make-repo --dry-run

# Set arch and version explicitly
make-repo --arch x86_64 --version 10

# Skip remote sync
make-repo --skip-ftp --skip-sourceforge
```

**What it does:**
1. Separates debug/debuginfo RPMs from main RPMs
2. Signs all packages with `rpm --addsign`
3. Runs `createrepo_c` (or `createrepo`) on each repo directory
4. Syncs to local FTP server (`ftp.casjaysdev.pro`)
5. Syncs to SourceForge web hosting (mirror website)
6. Syncs to SourceForge FRS (download mirrors)

**Repo structure on SourceForge:**
```
/RHEL/{VERSION}/{ARCH}/rpms/      - binary RPMs
/RHEL/{VERSION}/{ARCH}/debug/     - debuginfo RPMs
/RHEL/{VERSION}/{ARCH}/addons/    - addon packages
/RHEL/{VERSION}/{ARCH}/extras/    - extra packages
/RHEL/{VERSION}/SRPMS/            - source RPMs
```

**Configuration:** `~/.config/rpm-devel/make-repo-settings.conf`

### bootstrap

Bootstraps a fresh container for RPM building. Run inside a Docker container.

```shell
# Typically called automatically by create-container.sh
bootstrap
```

Installs build tools, sets up rpmbuild directories, and configures the environment.

### bogusDate

Fixes incorrect weekday names in spec file changelogs.

```shell
# Fix bogus dates in a spec file
bogusDate mypackage.spec

# Fix multiple specs
bogusDate *.spec
```

RPM warns about "bogus date" when the weekday doesn't match the actual date (e.g., "Thu" for a day that was actually a Friday). This script automatically corrects them.

## Workflow

```
1. Install tools          ->  install.sh
2. Create build containers ->  create-container.sh all
3. Enter a container      ->  create-container.sh --enter almalinux 10 amd64
4. Build packages         ->  rpmbuild.sh
5. Create repos & sync    ->  make-repo
```

## Configuration

All configuration lives in `~/.config/rpm-devel/`:

| File | Purpose |
|------|---------|
| `settings.conf` | Container settings (images, versions, paths) |
| `make-repo-settings.conf` | Repo build/sync settings (SourceForge user, FTP) |
| `lists/{7,8,9,10}.txt` | Package lists per EL version |
| `containers/` | Container state tracking |
| `scripts/` | Generated container run scripts |

## Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SOURCEFORGE_USER` | (required) | Your SourceForge username |
| `FTP_USER` | root | FTP server username |
| `ENABLE_VERSION_7` | no | Build for EL7 |
| `ENABLE_VERSION_8` | yes | Build for EL8 |
| `ENABLE_VERSION_9` | yes | Build for EL9 |
| `ENABLE_VERSION_10` | yes | Build for EL10 |
| `ENABLE_FEDORA` | yes | Build for Fedora |
| `FEDORA_VERSION` | 42 | Fedora version to build |

## Supported platforms

- **Build host:** x86_64 Linux with Docker
- **Target arches:** x86_64, aarch64 (via QEMU user-static)
- **Target distros:** RHEL/AlmaLinux/Rocky/Oracle 7-10, Fedora 38+, CentOS 7+
- **Build system:** COPR compatible

## Related repos

- [rpm-devel](https://github.com/rpm-devel) — GitHub org with all spec files
- [casjay-release](https://github.com/rpm-devel/casjay-release) — Repo config package
- [SourceForge mirrors](https://rpm-devel.sourceforge.io/) — Package mirror site
