#!/bin/sh
# Fail unless ${path:#/mnt/*} appears only inside {{ if .isWSL }} in dot_zshenv.tmpl.
set -u

base=$(dirname "$0")
file=$base/../home/dot_config/zsh/dot_zshenv.tmpl

if [ ! -f "$file" ]; then
  echo "fail: missing home/dot_config/zsh/dot_zshenv.tmpl" >&2
  exit 1
fi

awk '
function strip(s) {
  sub(/^[-[:space:]]+/, "", s)
  sub(/[-[:space:]]+$/, "", s)
  return s
}

function push(k) {
  depth++
  kind[depth] = k
  branch[depth] = "true"
}

function in_wsl_true(    i) {
  for (i = depth; i >= 1; i--) {
    if (kind[i] == "wsl" && branch[i] == "true") return 1
  }
  return 0
}

function handle(body) {
  body = strip(body)
  if (body ~ /^if[[:space:]]+\.isWSL$/) {
    push("wsl")
  } else if (body ~ /^if[[:space:]]/) {
    push("other")
  } else if (body ~ /^(range|with|block|define)([[:space:]]|$)/) {
    push("other")
  } else if (body ~ /^else[[:space:]]+if[[:space:]]+\.isWSL$/) {
    if (depth < 1) bad_struct = 1
    else { kind[depth] = "wsl"; branch[depth] = "true" }
  } else if (body ~ /^else[[:space:]]+if[[:space:]]/) {
    if (depth < 1) bad_struct = 1
    else { kind[depth] = "other"; branch[depth] = "true" }
  } else if (body ~ /^else$/) {
    if (depth < 1) bad_struct = 1
    else branch[depth] = "false"
  } else if (body ~ /^end$/) {
    if (depth < 1) bad_struct = 1
    else depth--
  }
}

function consume(text,    f, a, rest, endp, n) {
  n = length(needle)
  while (length(text) > 0) {
    f = index(text, needle)
    a = index(text, "{{")
    if (f == 0 && a == 0) return ""
    if (a == 0 || (f > 0 && f < a)) {
      if (in_wsl_true()) good++
      else bad++
      text = substr(text, f + n)
      continue
    }
    rest = substr(text, a + 2)
    endp = index(rest, "}}")
    if (endp == 0) return "{{" rest
    handle(substr(rest, 1, endp - 1))
    text = substr(rest, endp + 2)
  }
  return ""
}

BEGIN {
  needle = "${path:#/mnt/*}"
  depth = 0
  good = 0
  bad = 0
  bad_struct = 0
  pending = ""
}

{
  pending = consume(pending $0 "\n")
}

END {
  if (pending != "") bad_struct = 1
  if (bad_struct) {
    print "fail: could not parse if/end in dot_zshenv.tmpl"
    exit 1
  }
  if (bad > 0) {
    print "fail: " needle " appears outside {{ if .isWSL }}"
    exit 1
  }
  if (good < 1) {
    print "fail: " needle " is not inside {{ if .isWSL }}"
    exit 1
  }
  print "ok: " needle " is only inside {{ if .isWSL }}"
  exit 0
}
' "$file"
