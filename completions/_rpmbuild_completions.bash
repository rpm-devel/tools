# bash completion for rpmbuild
# To use, source this file in your ~/.bashrc or ~/.bash_profile:
#   source /path/to/_rpmbuild_completions.bash

__rpmbuild_completion() {
  local cur prev words cword
  cur="${COMP_WORDS[cword]}"
  prev="${COMP_WORDS[cword-1]}"
  words=("${COMP_WORDS[@]}")

  local longopts="help version debug update list-targets no-sign platform target color no-color"

  case "$prev" in
    rpmbuild)
      COMPREPLY=($(compgen -W "-h --help -v --version --update --no-sign --platform --target --list-targets --color --no-color --debug" -- "$cur"))
      return 0
      ;;
    --platform)
      COMPREPLY=($(compgen -W "amd64 x86_64 arm64 aarch64" -- "$cur"))
      return 0
      ;;
    --target)
      COMPREPLY=($(compgen -W "eol/centos-7-x86_64 eol/centos-7-aarch64 almalinux-8-x86_64 almalinux-8-aarch64 almalinux-9-x86_64 almalinux-9-aarch64 almalinux-10-x86_64 almalinux-10-aarch64 fedora-42-x86_64 fedora-42-aarch64" -- "$cur"))
      return 0
      ;;
    *)
      COMPREPLY=($(compgen -W "-h --help -v --version --update --no-sign --platform --target --list-targets --color --no-color --debug" -- "$cur"))
      return 0
      ;;
  esac
}

complete -o bashdefault -o default -o nospace -F __rpmbuild_completion rpmbuild
