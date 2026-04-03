# Detect shell if not specified
shell_type="${args[shell]}"
if [ -z "$shell_type" ]; then
  case "${SHELL##*/}" in
    zsh)  shell_type="zsh" ;;
    bash) shell_type="bash" ;;
    *)
      msg_error "Cannot auto-detect shell. Please specify 'bash' or 'zsh'."
      exit 1
      ;;
  esac
fi

case "$shell_type" in
  bash) : ;;
  zsh)  : ;;
  *)
    msg_error "Unsupported shell '$shell_type'. Use 'bash' or 'zsh'."
    exit 1
    ;;
esac

# --- Bash completion script ---
_dcm_bash_completion() {
  cat <<'BASH_COMPLETION'
# dcm shell completion for bash                            -*- shell-script -*-
# Source this file or add to ~/.bash_completion.d/dcm

_dcm_resolve_workdir() {
  local i
  for ((i = 1; i < ${#COMP_WORDS[@]}; i++)); do
    case "${COMP_WORDS[i]}" in
      --dir=*) echo "${COMP_WORDS[i]#--dir=}"; return ;;
      --dir | -d)
        ((i++))
        [ -n "${COMP_WORDS[i]}" ] && echo "${COMP_WORDS[i]}" && return
        ;;
    esac
  done
  echo "${DCM_CONFIG:-${HOME}/.local/share/dcm}"
}

_dcm_list_repos() {
  local workdir="$1"
  [ -d "$workdir/repos" ] && ls -1 "$workdir/repos" 2>/dev/null || true
}

_dcm_list_services() {
  local workdir="$1"
  local repo_dir repo svc_dir
  [ -d "$workdir/repos" ] || return
  for repo_dir in "$workdir/repos"/*/; do
    [ -d "$repo_dir/services" ] || continue
    repo=$(basename "$repo_dir")
    for svc_dir in "$repo_dir/services"/*/; do
      [ -d "$svc_dir" ] && echo "$repo/$(basename "$svc_dir")"
    done
  done
}

_dcm_list_enabled_services() {
  local workdir="$1"
  local config="$workdir/state/config.ini"
  [ -f "$config" ] || return
  grep '^\[' "$config" | tr -d '[]'
}

_dcm() {
  local cur prev
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD - 1]}"

  local workdir
  workdir="$(_dcm_resolve_workdir)"

  # Find main command (skip flags and their values)
  local cmd="" subcmd="" i
  for ((i = 1; i < COMP_CWORD; i++)); do
    case "${COMP_WORDS[i]}" in
      --dir | -d) ((i++)); continue ;;
      --*) continue ;;
      -*)  continue ;;
    esac
    if [ -z "$cmd" ]; then
      case "${COMP_WORDS[i]}" in
        init | i)               cmd="init" ;;
        repo | rep | r)         cmd="repo" ;;
        service | s*)           [[ "${COMP_WORDS[i]}" == su || "${COMP_WORDS[i]}" == self-update ]] && cmd="self-update" || cmd="service" ;;
        caddy | ca | c)         cmd="caddy" ;;
        run)                    cmd="run" ;;
        self-update | su)       cmd="self-update" ;;
        completion | comp)      cmd="completion" ;;
      esac
    elif [ -z "$subcmd" ]; then
      subcmd="${COMP_WORDS[i]}"
    fi
  done

  COMPREPLY=()

  case "$cmd" in
    "")
      # Top-level commands and global flags
      COMPREPLY=($(compgen -W "init repo service caddy run self-update completion --dir --help --version -d -h -v" -- "$cur"))
      ;;

    init)
      COMPREPLY=($(compgen -W "--help -h" -- "$cur"))
      ;;

    repo)
      case "$subcmd" in
        "")
          COMPREPLY=($(compgen -W "install add rm info show register list ls update pull add-source --help -h" -- "$cur"))
          ;;
        info | show)
          local repos
          repos="$(_dcm_list_repos "$workdir")"
          COMPREPLY=($(compgen -W "$repos --help -h" -- "$cur"))
          ;;
        rm | d*)
          local repos
          repos="$(_dcm_list_repos "$workdir")"
          COMPREPLY=($(compgen -W "$repos --help -h" -- "$cur"))
          ;;
        pull)
          local repos
          repos="$(_dcm_list_repos "$workdir")"
          COMPREPLY=($(compgen -W "$repos --help -h" -- "$cur"))
          ;;
        install | add)
          COMPREPLY=($(compgen -W "--branch --help -b -h" -- "$cur"))
          ;;
        register | reg)
          COMPREPLY=($(compgen -W "--branch --help -b -h" -- "$cur"))
          ;;
        list | ls | l)
          COMPREPLY=($(compgen -W "--all --help -a -h" -- "$cur"))
          ;;
        update | u*)
          COMPREPLY=($(compgen -W "--help -h" -- "$cur"))
          ;;
        add-source)
          COMPREPLY=($(compgen -W "--help -h" -- "$cur"))
          ;;
        *)
          COMPREPLY=($(compgen -W "--help -h" -- "$cur"))
          ;;
      esac
      ;;

    service)
      case "$subcmd" in
        "")
          COMPREPLY=($(compgen -W "enable disable config status up down restart logs shell --help -h" -- "$cur"))
          ;;
        enable | e*)
          local svcs
          svcs="$(_dcm_list_services "$workdir")"
          COMPREPLY=($(compgen -W "$svcs --all --yes --help -a -y -h" -- "$cur"))
          ;;
        disable | dis*)
          local svcs
          svcs="$(_dcm_list_enabled_services "$workdir")"
          COMPREPLY=($(compgen -W "$svcs --all --help -a -h" -- "$cur"))
          ;;
        config | c*)
          local svcs
          svcs="$(_dcm_list_enabled_services "$workdir")"
          COMPREPLY=($(compgen -W "$svcs --help -h" -- "$cur"))
          ;;
        up | u*)
          local svcs
          svcs="$(_dcm_list_enabled_services "$workdir")"
          COMPREPLY=($(compgen -W "$svcs --build --help -b -h" -- "$cur"))
          ;;
        down | d*)
          local svcs
          svcs="$(_dcm_list_enabled_services "$workdir")"
          COMPREPLY=($(compgen -W "$svcs --help -h" -- "$cur"))
          ;;
        restart | r*)
          local svcs
          svcs="$(_dcm_list_enabled_services "$workdir")"
          COMPREPLY=($(compgen -W "$svcs --help -h" -- "$cur"))
          ;;
        logs | l*)
          local svcs
          svcs="$(_dcm_list_enabled_services "$workdir")"
          COMPREPLY=($(compgen -W "$svcs --help -h" -- "$cur"))
          ;;
        shell | sh*)
          local svcs
          svcs="$(_dcm_list_enabled_services "$workdir")"
          COMPREPLY=($(compgen -W "$svcs --help -h" -- "$cur"))
          ;;
        status | s*)
          COMPREPLY=($(compgen -W "--all --help -a -h" -- "$cur"))
          ;;
        *)
          COMPREPLY=($(compgen -W "--help -h" -- "$cur"))
          ;;
      esac
      ;;

    caddy)
      case "$subcmd" in
        "")
          COMPREPLY=($(compgen -W "add service-add reverse-proxy rp --help -h" -- "$cur"))
          ;;
        add | a*)
          COMPREPLY=($(compgen -W "--file --target --help -f -t -h" -- "$cur"))
          ;;
        service-add | sa*)
          COMPREPLY=($(compgen -W "--file --help -f -h" -- "$cur"))
          ;;
        reverse-proxy | rp)
          COMPREPLY=($(compgen -W "--target --help -t -h" -- "$cur"))
          ;;
        *)
          COMPREPLY=($(compgen -W "--help -h" -- "$cur"))
          ;;
      esac
      ;;

    run)
      if [ -z "$subcmd" ]; then
        local repos
        repos="$(_dcm_list_repos "$workdir")"
        COMPREPLY=($(compgen -W "$repos --list --help -l -h" -- "$cur"))
      else
        COMPREPLY=($(compgen -W "--list --help -l -h" -- "$cur"))
      fi
      ;;

    completion | comp)
      COMPREPLY=($(compgen -W "bash zsh --install --help -i -h" -- "$cur"))
      ;;

    self-update)
      COMPREPLY=($(compgen -W "--help -h" -- "$cur"))
      ;;
  esac
}

complete -F _dcm dcm
BASH_COMPLETION
}

# --- Zsh completion script ---
_dcm_zsh_completion() {
  cat <<'ZSH_COMPLETION'
#compdef dcm
# dcm shell completion for zsh
# Place this file in a directory on your $fpath, e.g. ~/.zsh/completions/_dcm

_dcm_resolve_workdir() {
  local workdir="${DCM_CONFIG:-${HOME}/.local/share/dcm}"
  local i
  for ((i = 1; i < ${#words[@]}; i++)); do
    case "${words[i]}" in
      --dir=*) workdir="${words[i]#--dir=}"; break ;;
      --dir | -d) workdir="${words[i+1]}"; break ;;
    esac
  done
  echo "$workdir"
}

_dcm_repos() {
  local workdir
  workdir="$(_dcm_resolve_workdir)"
  [ -d "$workdir/repos" ] && ls -1 "$workdir/repos" 2>/dev/null
}

_dcm_services() {
  local workdir repo_dir repo svc_dir
  workdir="$(_dcm_resolve_workdir)"
  [ -d "$workdir/repos" ] || return
  for repo_dir in "$workdir/repos"/*/; do
    [ -d "$repo_dir/services" ] || continue
    repo=$(basename "$repo_dir")
    for svc_dir in "$repo_dir/services"/*/; do
      [ -d "$svc_dir" ] && echo "$repo/$(basename "$svc_dir")"
    done
  done
}

_dcm_enabled_services() {
  local workdir config
  workdir="$(_dcm_resolve_workdir)"
  config="$workdir/state/config.ini"
  [ -f "$config" ] && grep '^\[' "$config" | tr -d '[]'
}

_dcm() {
  local state line
  local -a repos services enabled_services

  _arguments -C \
    '(-d --dir)'{-d,--dir}'[DCM working directory]:dir:_files -/' \
    '(-h --help)'{-h,--help}'[Show help]' \
    '(-v --version)'{-v,--version}'[Show version]' \
    '1: :->command' \
    '*:: :->args' && return

  case "$state" in
    command)
      local -a commands
      commands=(
        'init:Initialize DockManager directories'
        'repo:Manage git repositories'
        'service:Manage docker services'
        'caddy:Manage Caddy reverse proxy configuration'
        'run:Run a command provided by a repo'
        'completion:Output shell completion script'
        'self-update:Update dcm to the latest released version'
      )
      _describe 'command' commands
      ;;

    args)
      case "${line[1]}" in
        init | i)
          _arguments '(-h --help)'{-h,--help}'[Show help]'
          ;;

        repo | rep | r)
          case "${line[2]}" in
            info | show)
              repos=("${(@f)$(_dcm_repos)}")
              _arguments \
                '(-h --help)'{-h,--help}'[Show help]' \
                '1:repository name:(${repos[@]})'
              ;;
            rm | d*)
              repos=("${(@f)$(_dcm_repos)}")
              _arguments \
                '(-h --help)'{-h,--help}'[Show help]' \
                '1:repository name:(${repos[@]})'
              ;;
            pull)
              repos=("${(@f)$(_dcm_repos)}")
              _arguments \
                '(-h --help)'{-h,--help}'[Show help]' \
                '*:repository name:(${repos[@]})'
              ;;
            install | add)
              _arguments \
                '(-b --branch)'{-b,--branch}'[Branch to checkout]:branch' \
                '(-h --help)'{-h,--help}'[Show help]' \
                '1:repository name'
              ;;
            register | reg)
              _arguments \
                '(-b --branch)'{-b,--branch}'[Branch to track]:branch' \
                '(-h --help)'{-h,--help}'[Show help]' \
                '1:URL'
              ;;
            list | ls | l)
              _arguments \
                '(-a --all)'{-a,--all}'[Show all available repos]' \
                '(-h --help)'{-h,--help}'[Show help]'
              ;;
            update | u*)
              _arguments '(-h --help)'{-h,--help}'[Show help]'
              ;;
            add-source)
              _arguments \
                '(-h --help)'{-h,--help}'[Show help]' \
                '1:URL'
              ;;
            *)
              local -a repo_commands
              repo_commands=(
                'install:Install a repository from the catalog'
                'rm:Remove a repository'
                'info:Show details about a repository'
                'show:Show details about a repository'
                'register:Register a repository URL without cloning'
                'list:List repositories'
                'update:Fetch manifests from sources'
                'pull:git pull on installed repositories'
                'add-source:Add an external source file'
              )
              _describe 'repo command' repo_commands
              ;;
          esac
          ;;

        service | s*)
          case "${line[2]}" in
            enable | e*)
              services=("${(@f)$(_dcm_services)}")
              _arguments \
                '(-a --all)'{-a,--all}'[Enable all services]' \
                '(-y --yes)'{-y,--yes}'[Non-interactive mode]' \
                '(-h --help)'{-h,--help}'[Show help]' \
                '*:service:(${services[@]})'
              ;;
            disable | dis*)
              enabled_services=("${(@f)$(_dcm_enabled_services)}")
              _arguments \
                '(-a --all)'{-a,--all}'[Disable all services]' \
                '(-h --help)'{-h,--help}'[Show help]' \
                '*:service:(${enabled_services[@]})'
              ;;
            config | c*)
              enabled_services=("${(@f)$(_dcm_enabled_services)}")
              _arguments \
                '(-h --help)'{-h,--help}'[Show help]' \
                '*:service:(${enabled_services[@]})'
              ;;
            up | u*)
              enabled_services=("${(@f)$(_dcm_enabled_services)}")
              _arguments \
                '(-b --build)'{-b,--build}'[Rebuild images]' \
                '(-h --help)'{-h,--help}'[Show help]' \
                '*:service:(${enabled_services[@]})'
              ;;
            down | d* | restart | r* | logs | l* | shell | sh*)
              enabled_services=("${(@f)$(_dcm_enabled_services)}")
              _arguments \
                '(-h --help)'{-h,--help}'[Show help]' \
                '*:service:(${enabled_services[@]})'
              ;;
            status | s*)
              _arguments \
                '(-a --all)'{-a,--all}'[Show all services]' \
                '(-h --help)'{-h,--help}'[Show help]'
              ;;
            *)
              local -a service_commands
              service_commands=(
                'enable:Enable services'
                'disable:Disable services'
                'config:Configure services'
                'status:Show status'
                'up:Start services'
                'down:Stop services'
                'restart:Restart services'
                'logs:Follow logs'
                'shell:Open shell in container'
              )
              _describe 'service command' service_commands
              ;;
          esac
          ;;

        caddy | ca | c)
          case "${line[2]}" in
            add | a*)
              _arguments \
                '(-f --file)'{-f,--file}'[Read snippet from file]:file:_files' \
                '(-t --target)'{-t,--target}'[Target file (before/after)]:target:(before after)' \
                '(-h --help)'{-h,--help}'[Show help]' \
                '1:snippet name'
              ;;
            service-add | sa*)
              _arguments \
                '(-f --file)'{-f,--file}'[Read snippet from file]:file:_files' \
                '(-h --help)'{-h,--help}'[Show help]' \
                '1:snippet name'
              ;;
            reverse-proxy | rp)
              _arguments \
                '(-t --target)'{-t,--target}'[Target file (before/after)]:target:(before after)' \
                '(-h --help)'{-h,--help}'[Show help]' \
                '1:domain' \
                '2:upstream target'
              ;;
            *)
              local -a caddy_commands
              caddy_commands=(
                'add:Add/update a snippet in Caddyfile'
                'service-add:Add a route snippet in Caddyfile.Services'
                'reverse-proxy:Add a reverse proxy route'
              )
              _describe 'caddy command' caddy_commands
              ;;
          esac
          ;;

        run)
          if [[ -z "${line[2]}" ]]; then
            repos=("${(@f)$(_dcm_repos)}")
            _arguments \
              '(-l --list)'{-l,--list}'[List available commands]' \
              '(-h --help)'{-h,--help}'[Show help]' \
              '1:repository:(${repos[@]})'
          else
            _arguments \
              '(-l --list)'{-l,--list}'[List available commands]' \
              '(-h --help)'{-h,--help}'[Show help]' \
              '1:command'
          fi
          ;;

        completion | comp)
          _arguments \
            '(-i --install)'{-i,--install}'[Install completion script]' \
            '(-h --help)'{-h,--help}'[Show help]' \
            '1:shell:(bash zsh)'
          ;;

        self-update | su)
          _arguments '(-h --help)'{-h,--help}'[Show help]'
          ;;
      esac
      ;;
  esac
}

_dcm "$@"
ZSH_COMPLETION
}

# --- Install logic ---
_install_completion() {
  local shell="$1"
  local install_dir install_file rc_file marker

  case "$shell" in
    bash)
      install_dir="${HOME}/.bash_completion.d"
      install_file="$install_dir/dcm"
      rc_file="${HOME}/.bashrc"
      marker="# dcm completion"
      mkdir -p "$install_dir"
      _dcm_bash_completion > "$install_file"
      msg_success "Bash completion installed to $install_file"
      # Add source line to ~/.bashrc if not already present
      if [ -f "$rc_file" ] && ! grep -qF "$marker" "$rc_file"; then
        printf '\n%s\n[ -f ~/.bash_completion.d/dcm ] && source ~/.bash_completion.d/dcm\n' "$marker" >> "$rc_file"
        msg_success "Added source line to $rc_file"
        msg_info "Run 'source ~/.bashrc' or open a new terminal to activate."
      else
        msg_info "Already configured in $rc_file — run 'source ~/.bashrc' to reload."
      fi
      ;;
    zsh)
      install_dir="${HOME}/.zsh/completions"
      install_file="$install_dir/_dcm"
      rc_file="${HOME}/.zshrc"
      marker="# dcm completion"
      mkdir -p "$install_dir"
      _dcm_zsh_completion > "$install_file"
      msg_success "Zsh completion installed to $install_file"
      # Add fpath + compinit to ~/.zshrc if not already present
      if [ -f "$rc_file" ] && ! grep -qF "$marker" "$rc_file"; then
        printf '\n%s\nfpath=(~/.zsh/completions $fpath)\nautoload -Uz compinit && compinit\n' "$marker" >> "$rc_file"
        msg_success "Added fpath and compinit to $rc_file"
        msg_info "Run 'source ~/.zshrc' or open a new terminal to activate."
      else
        msg_info "Already configured in $rc_file — run 'source ~/.zshrc' to reload."
      fi
      ;;
  esac
}

# --- Main ---
if [ -n "${args[--install]}" ]; then
  _install_completion "$shell_type"
else
  case "$shell_type" in
    bash) _dcm_bash_completion ;;
    zsh)  _dcm_zsh_completion ;;
  esac
fi
