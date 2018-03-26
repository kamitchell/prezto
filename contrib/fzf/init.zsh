[ -f $HOME/.fzf.zsh ] && source $HOME/.fzf.zsh

# fe [FUZZY PATTERN] - Open the selected file with the default editor
#   - Bypass fuzzy finder if there's only one match (--select-1)
#   - Exit if there's no match (--exit-0)
fe() {
  local file
  file=$(fzf --query="$1" --select-1 --exit-0)
  [ -n "$file" ] && title ${EDITOR:-vim} && ${EDITOR:-vim} "$file"
}

# Modified version where you can press
#   - CTRL-O to open with `open` command,
#   - CTRL-R to open with `open -R` command (Finder),
#   - CTRL-E or Enter key to open with the $EDITOR
fo() {
  local out file key
  out=$(fzf-tmux --query="$1" --exit-0 --expect=ctrl-o,ctrl-e,ctrl-r)
  key=$(head -1 <<< "$out")
  file=$(head -2 <<< "$out" | tail -1)
  if [ -n "$file" ]; then
    if [ "$key" = ctrl-o ]
    then
      open "$file"
    elif [ "$key" = ctrl-r ]
    then
      open -R "$file"
    else
      ${EDITOR:-vim} "$file"
    fi
  fi
}

# Like fo, but honoring git ignore. Uses ag to check ignorance
foag() {
  FZF_DEFAULT_COMMAND='ag -l -g ""' fo
}

# fbr - checkout git branch
# fbr() {
#   local branches branch
#   branches=$(git branch -vv) &&
#   branch=$(echo "$branches" | fzf +m) &&
#   git checkout $(echo "$branch" | awk '{print $1}' | sed "s/.* //")
# }

# fbr - checkout git branch (including remote branches)
fbr() {
  local branches branch
  branches=$(git branch --all | grep -v HEAD) &&
  branch=$(echo "$branches" |
           fzf-tmux -d $(( 2 + $(wc -l <<< "$branches") )) +m) &&
  git checkout $(echo "$branch" | sed "s/.* //" | sed "s#^remotes/##")
}

# fco - checkout git branch/tag
fco() {
  local tags branches target
  tags=$(
    git tag | awk '{print "\x1b[31;1mtag\x1b[m\t" $1}') || return
  branches=$(
    git branch --all | grep -v HEAD |
    sed -e 's/.* //' -e 's#^remotes/\([^/]*\)/\(.*\)#\2 \1#' |
    sort -k1,2 |
    awk '{a[$1]=(!a[$1])?$2:a[$1]", "$2} END{for (i in a) print "\x1b[34;1mbranch\x1b[m\t" i "\t" (a[i]?"\x1b[33m(" a[i] ")\x1b[m":"") }') || return
  target=$(
    (echo "$tags"; echo "$branches") |
    fzf-tmux -l30 -- --no-hscroll --ansi +m -d "\t" -n 2,3) || return
  print -s git checkout "$(echo "$target" | awk '{print $2}')"
  git checkout $(echo "$target" | awk '{print $2}')
}

# fcs - get git commit sha
# example usage: git rebase -i `fcs`
fcs() {
  local commits commit
  commits=$(git log --color=always --graph --format="%C(auto)%h%d %s %C(black)%C(bold)%cr" --abbrev-commit --date=relative "${*:-HEAD}" ) &&
  commit=$(echo "$commits" | fzf-tmux --ansi --no-sort --reverse --tiebreak=index --toggle-sort=\` ) &&
  grep -o '[a-f0-9]\{7\}' <<< "$commit"
}

# fcoc - checkout git commit
fcoc() {
  local commits commit
  commits=$(git log --pretty=oneline --abbrev-commit --reverse) &&
  commit=$(echo "$commits" | fzf --tac +s +m -e) &&
  git checkout $(echo "$commit" | sed "s/ .*//")
}

fugitsha() {
  local git sha
  git=$(git rev-parse --git-dir)
  # Make it absolute
  git=$(cd $(dirname "$git") && pwd)/$(basename "$git")
  sha=$(git rev-parse $1)
  vim fugitive://"$git"//$sha
}

_showref() {
  if [ -x /usr/local/bin/vim ]
  then
    fugitsha $1
  else
    sh -c 'git show --color=always $1 | less -R'
  fi
}


# fshow - git commit browser
fshow() {
  local out q k l sha
  while out=$(
    git log --graph --color=always \
      --format="%C(auto)%h%d %s %C(black)%C(bold)%cr" "$@" |
    fzf --ansi --no-sort --query="$q" --print-query --reverse --tiebreak=index --toggle-sort=\` --expect=ctrl-m,ctrl-s);
  do
      q=$(head -1 <<< "$out")
      k=$(head -2 <<< "$out" | tail -1)
      l=$(tail -1 <<< "$out")
      sha=$(grep -o '[a-f0-9]\{7\}' <<< "$l")
      [ -z "$sha" ] && continue
      if [ "$k" = 'ctrl-m' ]
      then
        _showref $sha
      else
        git show --color=always --stat -C -M --find-copies-harder $sha | less -R
      fi
  done
}

# fstash - easier way to deal with stashes
# type fstash to get a list of your stashes
# enter shows you the contents of the stash
# ctrl-d shows a diff of the stash against your current HEAD
# ctrl-b checks the stash out as a branch, for easier merging
fstash() {
  local out q k sha
    while out=$(
      git stash list --pretty="%C(yellow)%h %>(14)%Cgreen%cr %C(blue)%gs" |
      fzf --ansi --no-sort --query="$q" --print-query \
          --expect=ctrl-d,ctrl-b);
    do
      q=$(head -1 <<< "$out")
      k=$(head -2 <<< "$out" | tail -1)
      sha=$(tail -1 <<< "$out" | cut -d' ' -f1)
      [ -z "$sha" ] && continue
      if [ "$k" = 'ctrl-d' ]; then
        git diff --color=always $sha | less -R
      elif [ "$k" = 'ctrl-b' ]; then
        git stash branch "stash-$sha" $sha
        break;
      else
        git stash show --color=always -p $sha | less -R
      fi
    done
}

# v - open files in ~/.viminfo
v() {
  local files
  files=$(grep '^>' ~/.viminfo | cut -c3- |
          while read line; do
            [ -f "${line/\~/$HOME}" ] && echo "$line"
          done | fzf-tmux -d -m -q "$*" -1) && vim "${files//\~/$HOME}"
}

#  vim: set et sts=2 sw=2 ts=2 :
