# Repository Layout

## Mirror Directory Structure

```
RHEL/{VER}/{ARCH}/
  casjay/              CasjaysDev custom-built packages
  testing/             Packages being tested before promotion to casjay/
  os/                  Upstream base OS packages
  langs/               Programming language runtimes and libraries
  databases/           Database servers and clients
  infra/               Infrastructure and DevOps tools
  extras/              Community extras (EPEL, RPM Fusion, etc.)
  kernel/              Kernel packages (ELRepo kernel)
  debug/               All debuginfo/debugsource RPMs
  empty/               Placeholder for missing arch repos

RHEL/{VER}/
  sources/             All SRPMs (arch-independent)
```

## Repo Section -> Mirror Directory Mapping

### casjay/ (CasjaysDev custom-built)
Our rpm-devel built packages — latest versions of common tools.

| Repo Section | Mirror Dir | What's In It |
|-------------|-----------|--------------|
| casjay-packages | casjay/ | bash, zsh, fish, vim, neovim, nano, tmux, zellij, git, cmake, meson, direnv, jq, htop, btop, nginx, httpd, lighttpd, caddy, openlitespeed, haproxy, traefik, varnish, squid, qemu, rsync, aria2, vnstat, netdata, all python-* packages, apr, apr-util, brotli, c-ares, nghttp2, mod_http2, mod_wsgi, etc. |
| casjay-testing | testing/ | Same packages, pre-release/testing versions |
| casjay-community | (removed) | Merged into casjay/ — no separate community repo |

### os/ (Upstream Base OS)
AlmaLinux base operating system. Only latest versions mirrored.

| Repo Section | Mirror Dir | What's In It |
|-------------|-----------|--------------|
| casjay-os-base | os/ | AlmaLinux BaseOS |
| casjay-os-appstream | os/ | AlmaLinux AppStream |
| casjay-os-crb | os/ | AlmaLinux CRB (PowerTools on EL8) |
| casjay-os-extras | os/ | AlmaLinux Extras |
| casjay-os-plus | os/ | AlmaLinux Plus |
| casjay-os-highavailability | os/ | AlmaLinux HA (disabled by default) |
| casjay-os-nfv | os/ | AlmaLinux NFV (disabled) |
| casjay-os-rt | os/ | AlmaLinux RT (disabled) |
| casjay-os-resilientstorage | os/ | AlmaLinux Resilient Storage (disabled) |
| casjay-os-saphana | os/ | AlmaLinux SAP HANA (disabled) |
| casjay-os-sap | os/ | AlmaLinux SAP (disabled) |

### langs/ (Programming Languages)
Language runtimes, compilers, and libraries.

| Repo Section | Mirror Dir | What's In It |
|-------------|-----------|--------------|
| casjay-remi-base | langs/ | Remi base packages |
| casjay-remi-safe | langs/ | Remi safe (SCL-style) |
| casjay-remi-php | langs/ | PHP 7.4 (Remi) |
| casjay-nodejs | langs/ | Node.js 22.x (NodeSource) |
| casjay-yarn | langs/ | Yarn package manager |

### databases/ (Database Servers)
Database engines and client libraries.

| Repo Section | Mirror Dir | What's In It |
|-------------|-----------|--------------|
| casjay-mariadb | databases/ | MariaDB 10.10 |
| casjay-postgresql | databases/ | PostgreSQL 15 |
| casjay-mongodb | databases/ | MongoDB 8.0 |

### infra/ (Infrastructure & DevOps)
Containerization, CI/CD, management, VPN.

| Repo Section | Mirror Dir | What's In It |
|-------------|-----------|--------------|
| casjay-docker | infra/ | Docker CE |
| casjay-jenkins | infra/ | Jenkins CI |
| casjay-webmin | infra/ | Webmin admin panel |
| casjay-pritunl | infra/ | Pritunl VPN |
| casjay-copr-incus | infra/ | Incus container manager |
| casjay-i2pd | infra/ | I2P daemon |

### extras/ (Community Extras)
Third-party community repos — EPEL, RPM Fusion, etc.

| Repo Section | Mirror Dir | What's In It |
|-------------|-----------|--------------|
| casjay-epel | extras/ | Extra Packages for Enterprise Linux |
| casjay-rpmfusion-free-updates | extras/ | RPM Fusion Free |
| casjay-rpmfusion-nonfree-updates | extras/ | RPM Fusion Non-Free |
| casjay-gf | extras/ | Ghettoforge |

### kernel/ (Kernel Packages)
Kernel builds from ELRepo.

| Repo Section | Mirror Dir | What's In It |
|-------------|-----------|--------------|
| casjay-elrepo | kernel/ | ELRepo base (drivers, kmod) |
| casjay-elrepo-kernel | kernel/ | ELRepo kernel-ml, kernel-lt |
| casjay-elrepo-extras | kernel/ | ELRepo extras |

### debug/ (Debug Packages)
All debuginfo and debugsource RPMs from any of the above.

| Source | Mirror Dir |
|--------|-----------|
| All *-debuginfo-*.rpm | debug/ |
| All *-debugsource-*.rpm | debug/ |

### sources/ (Source RPMs)
All SRPMs, arch-independent. Only newest versions kept.

| Upstream | Provides SRPMs | URL Pattern |
|----------|:-:|-------------|
| AlmaLinux (all repos) | Yes | vault.almalinux.org/{VER}/{Repo}/Source/ |
| EPEL | Yes | metalink |
| RPM Fusion | Yes | download1.rpmfusion.org/{free,nonfree}/el/updates/{VER}/SRPMS/ |
| Remi | Yes | rpms.remirepo.net/SRPMS/ |
| ELRepo | Yes | elrepo.org/linux/{elrepo,kernel,extras}/el{VER}/SRPMS/ |
| PostgreSQL | Yes | download.postgresql.org/pub/repos/yum/srpms/ |
| Docker | Yes | download.docker.com/linux/centos/{VER}/source/stable/ |
| MariaDB | No | |
| MongoDB | No | |
| NodeSource/Yarn | No | Pre-built binaries only |
| Webmin/Jenkins | No | |
| Pritunl | No | |
| COPR (i2pd, incus) | No | |
| Ghettoforge | No | |

### empty/ (Placeholder)
Empty repo with valid repodata. Used for arches/versions where a repo doesn't exist yet.

## Mirror File Mapping

| Mirror File | Points To | SF FRS Path |
|------------|-----------|-------------|
| mirrors/casjay | casjay/ | /RHEL/$releasever/$basearch/casjay |
| mirrors/testing | testing/ | /RHEL/$releasever/$basearch/testing |
| mirrors/os | os/ | /RHEL/$releasever/$basearch/os |
| mirrors/langs | langs/ | /RHEL/$releasever/$basearch/langs |
| mirrors/databases | databases/ | /RHEL/$releasever/$basearch/databases |
| mirrors/infra | infra/ | /RHEL/$releasever/$basearch/infra |
| mirrors/extras | extras/ | /RHEL/$releasever/$basearch/extras |
| mirrors/kernel | kernel/ | /RHEL/$releasever/$basearch/kernel |
| mirrors/debug | debug/ | /RHEL/$releasever/$basearch/debug |
| mirrors/sources | sources/ | /RHEL/$releasever/sources |
| mirrors/empty | empty/ | /RHEL/$releasever/$basearch/empty |

## create-mirror Routing

```
Repo Section              ->  Local Mirror Dir
─────────────────────────────────────────────
casjay-os-*               ->  os/
casjay-remi-*, casjay-nodejs, casjay-yarn  ->  langs/
casjay-mariadb, casjay-postgresql, casjay-mongodb  ->  databases/
casjay-docker, casjay-jenkins, casjay-webmin, casjay-pritunl, casjay-copr-*, casjay-i2pd  ->  infra/
casjay-epel, casjay-rpmfusion-*, casjay-gf  ->  extras/
casjay-elrepo*            ->  kernel/
casjay-packages           ->  casjay/        (NOT mirrored — built locally)
casjay-testing            ->  testing/ (NOT mirrored — built locally)
*-debuginfo-*, *-debugsource-*  ->  debug/
*-srpm                    ->  sources/
```
