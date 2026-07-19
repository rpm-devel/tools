# bash completion for create-container
# To use, source this file in your ~/.bashrc or ~/.bash_profile:
#   source /path/to/_create-container_completions.bash

__create_container_completion() {
  local cur prev words cword
  cur="${COMP_WORDS[cword]}"
  prev="${COMP_WORDS[cword-1]}"
  words=("${COMP_WORDS[@]}")

  local longopts="debug help version config update enter color no-color image platform"
  local commands="pull all update enter list remove 7 8 9 10 fedora fedora-rawhide"
  local archs="amd64 x86_64 arm64 aarch64"

  if [[ "$prev" == "create-container" ]] || [[ "$prev" == "" ]]; then
    COMPREPLY=($(compgen -W "$commands" -- "$cur"))
    COMPREPLY+=($(compgen -W "--${longopts}" -- "$cur"))
    return 0
  fi

  case "$prev" in
    --image)
      COMPREPLY=()
      return 0
      ;;
    --platform)
      COMPREPLY=($(compgen -W "$archs" -- "$cur"))
      return 0
      ;;
    7|8|9|10|fedora|fedora-rawhide)
      COMPREPLY=($(compgen -W "$archs" -- "$cur"))
      return 0
      ;;
    *)
      COMPREPLY=($(compgen -W "--${longopts}" -- "$cur"))
      return 0
      ;;
  esac
}

complete -o bashdefault -o default -o nospace -F __create_container_completion create-container
