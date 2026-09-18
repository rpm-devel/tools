# bash completion for bootstrap
# To use, source this file in your ~/.bashrc or ~/.bash_profile:
#   source /path/to/_bootstrap_completions.bash

__bootstrap_completion() {
  local cur prev
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"

  case "$prev" in
    bootstrap)
      COMPREPLY=($(compgen -W "-h --help -v --version --no-skel --no-macros --force-macros --packages" -- "$cur"))
      return 0
      ;;
    --packages)
      COMPREPLY=($(compgen -f -- "$cur"))
      return 0
      ;;
    *)
      COMPREPLY=($(compgen -W "-h --help -v --version --no-skel --no-macros --force-macros --packages" -- "$cur"))
      return 0
      ;;
  esac
}

complete -o bashdefault -o default -o nospace -F __bootstrap_completion bootstrap
