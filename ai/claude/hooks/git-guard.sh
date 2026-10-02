#!/usr/bin/env bash
# PreToolUse hook: Claude may change git state freely in its own scratch dirs
# (temp dirs, ~/.claude). Anywhere else, anything that creates, moves or
# deletes branches, worktrees, refs or history needs your approval.
#
#   commit/push/pull outside a throwaway repo -> "deny"
#   gated op outside scratch                  -> "ask"
#   only safe git ops in inert scratch        -> "allow" (no prompt)
#   anything else                             -> no output (normal permission flow)
#
# A throwaway repo is an inert repo under a temp dir (/tmp, $TMPDIR), main
# checkout included; ~/.claude is scratch but not throwaway. A push must name
# its remote, and that must be a throwaway repo too, so nothing leaves the
# machine.
#
# This hook is the only guard for commit/push/pull (settings.json has no deny
# rules for them, since those can't tell a throwaway repo apart), so it
# catches every form it can: git -C . push, /usr/bin/git commit, \git ... .
# Written for macOS /bin/bash 3.2.
set -Eeuo pipefail

decide() { # decision reason
  jq -n --arg d "$1" --arg r "$2" '{hookSpecificOutput: {hookEventName: "PreToolUse",
    permissionDecision: $d, permissionDecisionReason: $r}}'
  exit 0
}
deny() { decide deny "$1"; }
ask() { decide ask "$1"; }
allow() { decide allow "$1"; }
# Fail safe: any unexpected error asks instead of silently letting the call
# through. Only in the main shell; a failing $(...) just returns non-zero.
trap '((BASH_SUBSHELL)) || { printf "%s\n" "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"ask\",\"permissionDecisionReason\":\"git-guard: internal error\"}}"; exit 0; }' ERR

input=$(cat)
tool=$(jq -r '.tool_name // ""' <<<"$input")
cwd=$(jq -r '.cwd // ""' <<<"$input")
[[ -n $cwd ]] || cwd=$PWD
claude_home=$(cd "$HOME/.claude" 2>/dev/null && pwd -P) || claude_home=$HOME/.claude
# mktemp puts things under $TMPDIR on macOS, so it counts as a temp dir too.
tmp_dir=$(cd "${TMPDIR:-/tmp}" 2>/dev/null && pwd -P) || tmp_dir=""
case $tmp_dir in /private/var/folders/?*) ;; *) tmp_dir=/private/tmp ;; esac

# Physical path of $1 relative to dir $2. Fails when it can't be known without
# running the shell (variables, globs, `cd -`, unresolved ..).
abspath() {
  local p=$1 base=$2
  p=${p#\"}; p=${p%\"}; p=${p#\'}; p=${p%\'}
  case $p in '' | -* | *[\$\`*?{}]*) return 1 ;; esac
  case $p in
    "~") p=$HOME ;;
    \~/*) p=$HOME/${p#??} ;;
    "~"*) return 1 ;;
  esac
  if [[ $p != /* ]]; then
    [[ -n $base ]] || return 1
    p=$base/$p
  fi
  if [[ -d $p ]]; then
    (cd "$p" && pwd -P)
  else
    case $p/ in */../* | */./*) return 1 ;; esac
    printf '%s\n' "$p"
  fi
}

# Git common dir (physical) of the repo containing $1; fails outside a repo.
common_dir() {
  local gd
  gd=$(git -C "$1" rev-parse --git-common-dir 2>/dev/null) || return 1
  (cd "$1" 2>/dev/null && cd "$gd" 2>/dev/null && pwd -P)
}

# Succeeds when $1 — and the repo it belongs to, main checkout included — is
# under a scratch root, or with $2 = tmp, under a temp dir. A worktree in /tmp
# of one of your repos is not scratch.
in_scratch() {
  local dir=$1 tmp_only=${2:-} top common p
  [[ -n $dir ]] || return 1
  if top=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) && common=$(common_dir "$dir"); then
    set -- "$(cd "$top" && pwd -P)" "$common"
  else
    set -- "$dir"
  fi
  for p; do
    case $p/ in
      /tmp/* | /private/tmp/* | "$tmp_dir"/*) ;;
      "$claude_home"/*) [[ -z $tmp_only ]] || return 1 ;;
      *) return 1 ;;
    esac
  done
}

# Succeeds when the repo at $1 has no local hooks or config that would make git
# run arbitrary commands, so auto-allowing git there can't smuggle code in.
inert() {
  local common
  common=$(common_dir "$1") || return 0
  [[ -z $(find "$common/hooks" -type f -perm -u+x ! -name '*.sample' 2>/dev/null) ]] &&
    ! git -C "$1" config --local --get-regexp \
      '^(core\.(hookspath|fsmonitor|sshcommand|pager|editor|askpass|gitproxy)|sequence\.editor|remote\..*\.(receivepack|uploadpack)|(filter|merge|diff|alias|include|includeif)\..*)$' \
      >/dev/null 2>&1
}

# Succeeds when `git <sub> <args>` creates, moves or deletes branches,
# worktrees, refs or history.
gated() {
  local sub=$1 a
  shift
  case $sub in
    commit | push | pull | switch | merge | rebase | cherry-pick | revert | am | update-ref | filter-branch | filter-repo)
      return 0 ;;
    checkout | co | reset)
      for a; do [[ $a == -- ]] && return 1; done # path form only touches files
      [[ $sub == reset && $# -eq 0 ]] && return 1 # plain reset only unstages
      return 0 ;;
    branch | br)
      for a; do
        case $a in
          -a | -r | -v | -vv | -l | --list | --all | --remotes | --show-current | --verbose | \
            --no-color | --color* | --format=* | --sort=* | --column* | --no-column) ;;
          *) return 0 ;;
        esac
      done
      return 1 ;;
    tag)
      for a; do
        case $a in -l | --list | -n* | --sort=* | --format=* | --column* | --no-column | --color*) ;; *) return 0 ;; esac
      done
      return 1 ;;
    worktree)
      case ${1:-} in add | remove | move | prune | repair | lock | unlock) return 0 ;; esac
      return 1 ;;
    stash)
      case ${1:-} in list | show) return 1 ;; esac
      return 0 ;;
    reflog)
      case ${1:-} in expire | delete) return 0 ;; esac
      return 1 ;;
    symbolic-ref)
      (($# >= 2)) ;;
    *) return 1 ;;
  esac
}

# Succeeds when `git <sub> <args>` in scratch dir $3 is fine to run without a prompt.
auto_ok() {
  local sub=$1 dir=$2 a
  shift 2
  case $sub in
    init | status | log | diff | show | add | rev-parse | branch | br | checkout | co | switch | \
      tag | merge | rebase | reset | cherry-pick | revert | stash | worktree | commit | push | pull) ;;
    *) return 1 ;;
  esac
  for a; do
    case $a in -x | --exec* | --output* | --template* | --separate-git-dir* | --ext-diff) return 1 ;; esac
  done
  # A new worktree or repo must land in scratch too.
  if [[ $sub == worktree && ${1:-} == add ]] || [[ $sub == init ]]; then
    local target="" skip=0
    [[ $sub == worktree ]] && shift
    for a; do
      if ((skip)); then skip=0; continue; fi
      case $a in -b | -B | --reason | --orphan) skip=1 ;; -*) ;; *) target=$a; break ;; esac
    done
    if [[ -n $target ]]; then
      target=$(abspath "$target" "$dir") && in_scratch "$target" || return 1
    fi
  fi
  inert "$dir"
}

# Succeeds when git URL $1 is an existing throwaway repo on this machine, a
# relative path being taken from each dir that follows.
throwaway_url() {
  local u=$1 b p
  shift
  case $u in
    file:///*) u=${u#file://} ;;
    *://* | *::*) return 1 ;;
  esac
  case ${u%%:*} in "$u" | */*) ;; *) return 1 ;; esac # host:path is ssh
  for b; do
    p=$(abspath "$u" "$b") && [[ -d $p ]] && in_scratch "$p" tmp && inert "$p" || return 1
  done
}

# Succeeds when `git <sub> <args>` (commit, push or pull) run in $2 stays within
# throwaway repos. Sets $why when it fails.
throwaway_ok() {
  local sub=$1 dir=$2 a repo="" skip=0 top urls url
  shift 2
  if ! in_scratch "$dir" tmp; then
    why="${dir:-the directory} is not in a repo under /tmp or \$TMPDIR"; return 1
  fi
  if ! inert "$dir"; then
    why="the repo has hooks or config that run commands"; return 1
  fi
  for a; do
    case $a in --exec* | --receive-pack* | --upload-pack* | --repo*) why="$a is not allowed"; return 1 ;; esac
  done
  [[ $sub == push ]] || return 0

  if ! top=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null); then
    why="push only from an existing, non-bare repo"; return 1
  fi
  if [[ -e $top/.gitmodules ]]; then
    why="a push with submodules could reach their remotes"; return 1
  fi
  for a; do
    if ((skip)); then skip=0; continue; fi
    case $a in -o | --push-option) skip=1 ;; -*) ;; *) repo=${a//[\'\"]/}; break ;; esac
  done
  if [[ -z $repo ]]; then
    why="name the remote or path to push to"; return 1
  fi
  if urls=$(git -C "$dir" remote get-url --push --all "$repo" 2>/dev/null); then
    : # insteadOf and pushInsteadOf already applied
  elif git -C "$dir" config --get-regexp '^url\.' >/dev/null 2>&1; then
    why="url.*.insteadOf rules could rewrite $repo"; return 1
  else
    urls=$repo
  fi
  while IFS= read -r url; do
    throwaway_url "$url" "$dir" "$top" ||
      { why="$url is not an existing throwaway repo under /tmp or \$TMPDIR"; return 1; }
  done <<<"$urls"
}

# Reads the shell word starting at t[j], rejoining a quoted value that the
# split on spaces broke up. Sets $val and moves $j past the word.
word() {
  local q="" qs k c
  val=""
  while ((j < n)); do
    val+=${val:+ }${t[j]}
    qs=${t[j]//[^\"\']/}
    j=$((j + 1))
    for ((k = 0; k < ${#qs}; k++)); do
      c=${qs:k:1}
      if [[ -z $q ]]; then q=$c; elif [[ $c == "$q" ]]; then q=""; fi
    done
    [[ -n $q ]] || break
  done
}

check_bash() {
  local cmd bare seg dir=$cwd safe=1 fuzzy=0 any_gated=0 ask_reason="" why i j n tok val g_dir g_sub g_plain
  local -a t g_args
  cmd=$(jq -r '.tool_input.command // ""' <<<"$input")
  # Redirects that only merge or drop output are harmless.
  for tok in '2>&1' '2>/dev/null' '>/dev/null'; do cmd=${cmd//"$tok"/}; done
  # Substitutions, redirects and groups rule out auto-allow. Quoted text like
  # "fix (typo)" doesn't count; "$(...)" does.
  bare=$(sed -E "s/'[^']*'|\"[^\"]*\"//g" <<<"$cmd")
  case $cmd in *'`'* | *"\$("*) safe=0 fuzzy=1 ;; esac
  case $bare in *[\<\>\(\)\{\}]*) safe=0 ;; esac
  # A cd inside a subshell, group or substitution doesn't move what follows it,
  # so once there is one of those, cd leaves the directory unknown.
  case $bare in *[\(\)\{\}]*) fuzzy=1 ;; esac
  case $cmd in *GIT_DIR* | *GIT_WORK_TREE* | *GIT_COMMON_DIR*) dir="" ;; esac

  seg=${cmd//&&/$'\n'}; seg=${seg//||/$'\n'}
  seg=${seg//|/$'\n'}; seg=${seg//&/$'\n'}; seg=${seg//;/$'\n'}
  seg=$(tr '(){}' '    ' <<<"$seg")

  while IFS= read -r line; do
    read -ra t <<<"$line" || true
    n=${#t[@]}
    ((n)) || continue

    case ${t[0]} in
      cd | pushd)
        if ((fuzzy)); then dir=""; else dir=$(abspath "${t[1]:-~}" "$dir") || dir=""; fi
        continue ;;
      popd) dir=""; continue ;;
    esac

    # Find git anywhere in the segment (catches xargs git, env X=1 git,
    # bash -c "git ...", ...). Quotes and backslashes are stripped so "git,
    # 'git and \git match too. A cd before it (sh -c 'cd x ...) loses track of
    # the directory.
    i=-1
    for ((j = 0; j < n; j++)); do
      tok=${t[j]//[\'\"\\]/}
      [[ ${tok##*/} == git ]] && { i=$j; break; }
      case $tok in cd | pushd | popd) dir="" ;; esac
    done
    if ((i < 0)); then safe=0; continue; fi
    ((i == 0)) || safe=0

    # Global options: -C changes the target; anything that points git elsewhere
    # or injects config rules out auto-allow.
    g_dir=$dir g_plain=1 g_sub=""
    j=$((i + 1))
    while ((j < n)); do
      word; tok=$val
      case $tok in
        -C) word; g_dir=$(abspath "$val" "$g_dir") || g_dir="" ;;
        --git-dir=* | --work-tree=*) g_dir=$(abspath "${tok#*=}" "$g_dir") || g_dir=""; g_plain=0 ;;
        --git-dir | --work-tree) word; g_dir=$(abspath "$val" "$g_dir") || g_dir=""; g_plain=0 ;;
        -c | --namespace | --config-env | --exec-path) word; g_plain=0 ;;
        --no-pager | -P) ;;
        -*) g_plain=0 ;;
        *) g_sub=${tok//[\'\"]/}; break ;; # git 'push' runs push too
      esac
    done
    g_args=()
    while ((j < n)); do
      word
      case $val in *'>'* | *'<'*) ;; *) g_args+=("$val") ;; esac
    done

    case $g_sub in ci | cm) g_sub=commit ;; esac
    case $g_sub in
      commit | push | pull)
        why=""
        if ((i > 0 || !g_plain)); then
          why="run it as plain git, without -c, --git-dir or a wrapper (git -C <dir> is fine)"
        elif [[ $g_sub == push ]] && ((!safe)); then
          why="push only in a command of cd and git alone, with no \$(...), subshell, redirect or other command before it"
        else
          throwaway_ok "$g_sub" "$g_dir" ${g_args[@]+"${g_args[@]}"} || true
        fi
        [[ -z $why ]] ||
          deny "git $g_sub is reserved for you outside Claude's throwaway repos (inert repos under /tmp or \$TMPDIR): $why" ;;
    esac
    if gated "$g_sub" ${g_args[@]+"${g_args[@]}"}; then
      any_gated=1
      # Keep scanning: a later commit/push must still be denied, not just asked.
      in_scratch "$g_dir" || [[ -n $ask_reason ]] ||
        ask_reason="git $g_sub in ${g_dir:-an unknown directory}: outside Claude's scratch dirs (/tmp, ~/.claude)"
    fi
    if ((safe)); then
      ((g_plain)) && in_scratch "$g_dir" && auto_ok "$g_sub" "$g_dir" ${g_args[@]+"${g_args[@]}"} || safe=0
    fi
  done <<<"$seg"

  [[ -z $ask_reason ]] || ask "$ask_reason"
  if ((any_gated && safe)); then
    allow "git in Claude's scratch dir"
  fi
}

case $tool in
  Bash)
    check_bash ;;
  EnterWorktree)
    p=$(jq -r '.tool_input.path // ""' <<<"$input")
    if [[ -n $p ]]; then d=$(abspath "$p" "$cwd") || d=""; else d=$cwd; fi
    in_scratch "$d" || ask "EnterWorktree would add a worktree/branch to the repo at ${d:-an unknown path}"
    ;;
  Agent)
    if [[ $(jq -r '.tool_input.isolation // ""' <<<"$input") == worktree ]]; then
      in_scratch "$cwd" || ask "Subagent worktree isolation would add a worktree and branch to the repo at $cwd"
    fi
    ;;
esac
exit 0
