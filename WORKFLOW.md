# RPM Build & Distribution Workflow

## Overview

```
  Upstream Sources
       |
       v
  [rpmbuild.sh]     Build RPMs from spec files
       |
       v
  ~/Documents/builds/rpmbuild/EL/el{VER}/{ARCH}/
       |
       v
  [make-repo]        Sign, organize, createrepo, sync to SF
       |
       v
  SourceForge FRS    /EL/{VER}/{ARCH}/{casjay,os,langs,databases,infra,extras,kernel,debug}
  SourceForge Web    /repo/EL/{VER}/{ARCH}/{casjay,os,langs,databases,infra,extras,kernel,debug}
  Local FTP          /repo/EL/{VER}/{ARCH}/{casjay,os,langs,databases,infra,extras,kernel,debug}
       |
       v
  [casjay-release]   Repo config installed on end-user systems
       |
       v
  Users: dnf install <package>
```

## Directory Layout

### Build host
```
~/rpmbuild/                          # Spec files + sources (per-package dirs)
~/Documents/builds/
  rpmbuild/EL/el{VER}/
    SRPMS/                           # Source RPMs
    {ARCH}/rpms/                     # Binary RPMs
  sourceforge/EL/el{VER}/{ARCH}/
    casjay/                          # CasjaysDev packages (signed)
    testing/                         # Pre-release testing
    os/                              # Upstream base OS mirror
    langs/                           # Languages (PHP, Node.js)
    databases/                       # Databases (MariaDB, PostgreSQL, MongoDB)
    infra/                           # Infrastructure (Docker, Jenkins)
    extras/                          # Community extras (EPEL, RPM Fusion)
    kernel/                          # ELRepo kernel
    debug/                           # debuginfo/debugsource
    empty/                           # Placeholder
  logs/rpmbuild/                     # Build logs
```

### SourceForge FRS
```
/home/frs/project/rpm-devel/EL/{VER}/{ARCH}/casjay/
/home/frs/project/rpm-devel/EL/{VER}/{ARCH}/os/
/home/frs/project/rpm-devel/EL/{VER}/{ARCH}/langs/
/home/frs/project/rpm-devel/EL/{VER}/{ARCH}/databases/
/home/frs/project/rpm-devel/EL/{VER}/{ARCH}/infra/
/home/frs/project/rpm-devel/EL/{VER}/{ARCH}/extras/
/home/frs/project/rpm-devel/EL/{VER}/{ARCH}/kernel/
/home/frs/project/rpm-devel/EL/{VER}/{ARCH}/debug/
/home/frs/project/rpm-devel/EL/{VER}/sources/
```

### SourceForge Web
```
/home/project-web/rpm-devel/htdocs/repo/EL/{VER}/{ARCH}/casjay/
/home/project-web/rpm-devel/htdocs/repo/EL/{VER}/{ARCH}/os/
...same structure as FRS...
```

### Local Mirror (create-mirror)
```
~/Documents/builds/mirror/EL/{VER}/{ARCH}/
  base/                              # Upstream base OS + third-party (latest only, re-signed)
  updates/                           # Upstream updates + EPEL/ELRepo/Remi/etc (latest only, re-signed)
  rpms/                              # YOUR rpm-devel built packages
  extras/                            # One-off packages you need
  debug/                             # debuginfo/debugsource RPMs
  empty/                             # Placeholder for arches with no repo
  SRPMS/                             # All source RPMs
```

## Tools

| Script | Purpose | Input | Output |
|--------|---------|-------|--------|
| `create-container.sh` | Create Docker build envs | Image + version | Running container |
| `bootstrap` | Setup container interior | (runs inside container) | Build-ready env |
| `rpmbuild.sh` | Build specs into RPMs | Spec files | RPMs in ~/Documents/builds/ |
| `make-repo` | Sign, organize, sync | Built RPMs | SourceForge repos |
| `create-mirror` | Download & re-sign upstream | Repo config | Local mirror |
| `bogusDate` | Fix spec changelog dates | Spec file | Fixed spec |
| `install.sh` | Install tools | (curl pipe) | Tools in $PATH |

## Workflow Steps

### Initial Setup
1. `bash -c "$(curl -q -LSsf https://github.com/rpm-devel/tools/raw/main/install.sh)"`
2. Set `SOURCEFORGE_USER` in `~/.config/rpm-devel/make-repo-settings.conf`
3. Import your GPG signing key

### Build Cycle
1. `create-container.sh 10 amd64` — create build container
2. `create-container.sh --enter almalinux 10 amd64` — enter it
3. `rpmbuild.sh` or `rpmbuild.sh nginx` — build packages
4. `exit` — leave container
5. `make-repo --version 10` — sign, createrepo, sync

### Mirror Sync
1. `create-mirror --version 10` — download upstream, re-sign, createrepo
2. `make-repo --version 10` — sync to SourceForge

### Intra-org build dependencies (casjay-local repo)
Some specs `BuildRequires` a package this org builds itself rather than one
available in the base AlmaLinux/EPEL repos (e.g. `mod_geoip` needs
`GeoIP-devel` from this org's own `GeoIP` package). To resolve this without
depending on SourceForge/network availability mid-batch, the build image
(`.github/docker/rootfs/etc/mock/site-defaults.cfg`) defines a local mock
repo, `casjay-local`, pointing at
`/root/Documents/builds/rpmbuild/EL/el<VER>/<ARCH>` — the same host dir
`rpmbuild.sh` already collects signed RPMs into, bind-mounted one level
further into the mock chroot itself.

`rpmbuild.sh` keeps that dir's repodata current automatically: after every
successful build, `__collect_rpms` calls `__refresh_local_repo`
(`createrepo_c --update`) on the output dir. This means **build order
matters** — a prerequisite package (e.g. `GeoIP`) must finish building
across all needed targets before a dependent package (e.g. `mod_geoip`) is
attempted, so its repodata exists when the dependent's mock build runs.
Until that repodata exists, the `casjay-local` repo definition is a no-op
(guarded in `site-defaults.cfg`), not a hard failure — it degrades to
today's "dependency unresolved" behavior rather than crashing unrelated
builds. Scoped to `almalinux-*` targets only.

## TODO

- [ ] Test full build cycle for all 77 packages
- [ ] QEMU build test (needs many deps)
- [ ] Set up COPR builds
- [ ] Create Fedora build containers
- [ ] Verify all repo URLs work on EL7/8/9/10
- [ ] Set up CI/CD for automated builds
- [ ] Create GPG signing key if not exists
- [ ] Test create-mirror with live repos
- [ ] Upload initial RPMs to SourceForge FRS
- [ ] Verify end-to-end: install casjay-release -> dnf install package
