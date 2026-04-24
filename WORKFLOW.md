# RPM Build & Distribution Workflow

## Overview

```
  Upstream Sources
       |
       v
  [rpmbuild.sh]     Build RPMs from spec files
       |
       v
  ~/Documents/builds/rpmbuild/RHEL/el{VER}/{ARCH}/
       |
       v
  [make-repo]        Sign, organize, createrepo, sync to SF
       |
       v
  SourceForge FRS    /RHEL/{VER}/{ARCH}/{casjay,os,langs,databases,infra,extras,kernel,debug}
  SourceForge Web    /repo/RHEL/{VER}/{ARCH}/{casjay,os,langs,databases,infra,extras,kernel,debug}
  Local FTP          /repo/RHEL/{VER}/{ARCH}/{casjay,os,langs,databases,infra,extras,kernel,debug}
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
  rpmbuild/RHEL/el{VER}/
    SRPMS/                           # Source RPMs
    {ARCH}/rpms/                     # Binary RPMs
  sourceforge/RHEL/el{VER}/{ARCH}/
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
/home/frs/project/rpm-devel/RHEL/{VER}/{ARCH}/casjay/
/home/frs/project/rpm-devel/RHEL/{VER}/{ARCH}/os/
/home/frs/project/rpm-devel/RHEL/{VER}/{ARCH}/langs/
/home/frs/project/rpm-devel/RHEL/{VER}/{ARCH}/databases/
/home/frs/project/rpm-devel/RHEL/{VER}/{ARCH}/infra/
/home/frs/project/rpm-devel/RHEL/{VER}/{ARCH}/extras/
/home/frs/project/rpm-devel/RHEL/{VER}/{ARCH}/kernel/
/home/frs/project/rpm-devel/RHEL/{VER}/{ARCH}/debug/
/home/frs/project/rpm-devel/RHEL/{VER}/sources/
```

### SourceForge Web
```
/home/project-web/rpm-devel/htdocs/repo/RHEL/{VER}/{ARCH}/casjay/
/home/project-web/rpm-devel/htdocs/repo/RHEL/{VER}/{ARCH}/os/
...same structure as FRS...
```

### Local Mirror (create-mirror)
```
~/Documents/builds/mirror/RHEL/{VER}/{ARCH}/
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
