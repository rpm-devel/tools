# Repository Layout

## Directory Structure

```
RHEL/{VER}/{ARCH}/
  rpms/        CasjaysDev custom-built packages
  addons/      Upstream third-party mirrors (OS, langs, databases, infra)
  extras/      Community extras (EPEL, RPM Fusion, Ghettoforge, ELRepo)
  debug/       All debuginfo/debugsource RPMs

RHEL/{VER}/
  srpms/       Source RPMs (shared across arches — stored once per version)

Fedora/{VER}/{ARCH}/
  rpms/
  addons/
  extras/
  debug/

Fedora/{VER}/
  srpms/
```

## Repo Section -> Mirror Directory Mapping

### rpms/ (CasjaysDev custom-built)
Built by `make-repo` from local rpmbuild output. Not mirrored by `create-mirror`.

| Repo Section | Mirror Dir | What's In It |
|-------------|-----------|--------------|
| casjay-rpms | rpms/ | All locally built CasjaysDev packages |

### addons/ (Upstream Third-Party)
Mirrored by `create-mirror` from upstream vendor repos.

| Repo Section | Mirror Dir | What's In It |
|-------------|-----------|--------------|
| casjay-os-* | addons/ | AlmaLinux BaseOS, AppStream, CRB, Extras, Plus |
| casjay-remi-* | addons/ | Remi PHP/language packages |
| casjay-nodejs | addons/ | Node.js (NodeSource) |
| casjay-yarn | addons/ | Yarn package manager |
| casjay-mariadb | addons/ | MariaDB |
| casjay-postgresql | addons/ | PostgreSQL |
| casjay-mongodb | addons/ | MongoDB |
| casjay-docker* | addons/ | Docker CE |
| casjay-jenkins | addons/ | Jenkins CI |
| casjay-webmin | addons/ | Webmin |
| casjay-pritunl | addons/ | Pritunl VPN |
| casjay-copr-* | addons/ | COPR builds (incus, i2pd) |

### extras/ (Community Extras)
Mirrored by `create-mirror` from community repos.

| Repo Section | Mirror Dir | What's In It |
|-------------|-----------|--------------|
| casjay-epel | extras/ | Extra Packages for Enterprise Linux |
| casjay-rpmfusion-* | extras/ | RPM Fusion Free + Non-Free |
| casjay-gf | extras/ | Ghettoforge |
| casjay-elrepo* | extras/ | ELRepo (kernel, drivers, extras) |

### debug/ (Debug Packages)
All debuginfo and debugsource RPMs moved here after sync.

### srpms/ (Source RPMs)
All .src.rpm files — from local builds and upstream mirrors.

## Mirror File Mapping

| Mirror File | SF Path |
|------------|---------|
| ZREPO/RHEL/{VER}/{ARCH}/mirrors/rpms | /RHEL/{VER}/{ARCH}/rpms |
| ZREPO/RHEL/{VER}/{ARCH}/mirrors/addons | /RHEL/{VER}/{ARCH}/addons |
| ZREPO/RHEL/{VER}/{ARCH}/mirrors/extras | /RHEL/{VER}/{ARCH}/extras |
| ZREPO/RHEL/{VER}/{ARCH}/mirrors/debug | /RHEL/{VER}/{ARCH}/debug |
| ZREPO/RHEL/{VER}/mirrors/srpms | /RHEL/{VER}/srpms |

## create-mirror Routing

```
Repo Section                          ->  Local Mirror Dir
──────────────────────────────────────────────────────────
casjay-os-*                           ->  addons/
casjay-remi-*, casjay-nodejs,
  casjay-yarn                         ->  addons/
casjay-mariadb, casjay-postgresql,
  casjay-mongodb, casjay-mssql        ->  addons/
casjay-docker*, casjay-jenkins,
  casjay-webmin, casjay-pritunl,
  casjay-copr-*, casjay-i2pd          ->  addons/
casjay-epel, casjay-rpmfusion-*,
  casjay-gf, casjay-elrepo*           ->  extras/
*-srpm, *-SRPMS, *-source             ->  srpms/
*-debuginfo-*, *-debugsource-*        ->  debug/  (moved post-sync)
casjay-rpms, casjay-addons,
  casjay-extras, casjay-debug,
  casjay-sources, casjay-packages,
  casjay-testing                      ->  SKIP (local repos, not mirrored)
```
