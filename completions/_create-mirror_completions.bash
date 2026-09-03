# bash completion for create-mirror
# To use, source this file in your ~/.bashrc or ~/.bash_profile:
#   source /path/to/_create-mirror_completions.bash

__create_mirror_completion() {
  local cur prev
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"

  case "$prev" in
    create-mirror)
      COMPREPLY=($(compgen -W "-h --help --version --debug --color --no-color -d --distro -v --ver -a --arch -r --repos --dry-run --no-sign --config" -- "$cur"))
      return 0
      ;;
    -d|--distro)
      COMPREPLY=($(compgen -W "el centos fedora" -- "$cur"))
      return 0
      ;;
    -v|--ver)
      COMPREPLY=($(compgen -W "6 7 8 9 10" -- "$cur"))
      return 0
      ;;
    -a|--arch)
      COMPREPLY=($(compgen -W "x86_64 aarch64" -- "$cur"))
      return 0
      ;;
    *)
      COMPREPLY=($(compgen -W "-h --help --version --debug --color --no-color -d --distro -v --ver -a --arch -r --repos --dry-run --no-sign --config" -- "$cur"))
      return 0
      ;;
  esac
}

complete -o bashdefault -o default -o nospace -F __create_mirror_completion create-mirror
