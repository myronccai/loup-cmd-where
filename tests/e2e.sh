#!/usr/bin/env bash
# End-to-end tests: run the built binary and compare its standard output
# (byte for byte), and where given its standard error, and exit status with
# the expected ones. The cases run inside a fixture tree built under $TMP.
#
# usage: tests/e2e.sh BINARY

set -u
BIN=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
pass=0
fail=0

# check_file NAME STATUS EXPECTED_FILE [ARGS...]
# Runs BINARY ARGS... with standard input from the file named by $IN
# (default: /dev/null) and PATH set to $RUN_PATH when that is set (the
# script's own PATH is left alone), and compares standard output with
# EXPECTED_FILE.
# If $WANT_ERR is set, standard error must equal it too.
check_file() {
    local name=$1 want_status=$2 want_file=$3
    shift 3
    if [ -n "${RUN_PATH+set}" ]; then
        PATH="$RUN_PATH" "$BIN" "$@" < "${IN:-/dev/null}" > "$TMP/out" 2> "$TMP/err"
    else
        "$BIN" "$@" < "${IN:-/dev/null}" > "$TMP/out" 2> "$TMP/err"
    fi
    local status=$?
    local err_ok=1
    if [ -n "${WANT_ERR+set}" ]; then
        printf '%s' "$WANT_ERR" > "$TMP/want_err"
        cmp -s "$TMP/want_err" "$TMP/err" || err_ok=0
    fi
    if [ "$status" -eq "$want_status" ] && cmp -s "$want_file" "$TMP/out" && [ "$err_ok" -eq 1 ]; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (exit $status, expected $want_status)"
        diff <(od -c "$want_file") <(od -c "$TMP/out") | sed 's/^/    /' | head -20
        if [ "$err_ok" -eq 0 ]; then
            diff <(od -c "$TMP/want_err") <(od -c "$TMP/err") | sed 's/^/    stderr /' | head -20
        fi
        sed 's/^/    stderr: /' "$TMP/err" | head -5
    fi
}

# check NAME STATUS EXPECTED_STDOUT [ARGS...]
# As check_file, with the expected output given as a string. Bash strings
# cannot hold NUL bytes; use check_file for output that contains them.
check() {
    local name=$1 want_status=$2
    printf '%s' "$3" > "$TMP/want"
    shift 3
    check_file "$name" "$want_status" "$TMP/want" "$@"
}

# check_both NAME STATUS EXPECTED_STDOUT EXPECTED_STDERR [ARGS...]
check_both() {
    local name=$1 want_status=$2 want_out=$3
    local WANT_ERR=$4
    shift 4
    check "$name" "$want_status" "$want_out" "$@"
}


# The fixture tree, built under $TMP. Expected paths are absolute and
# printed with `\`: d PATH gives that form.
W="$TMP/w"
mkdir -p "$W/cur" "$W/bin1" "$W/bin2/tooldir" "$W/tree/sub/deep" "$W/tree/b"
: > "$W/cur/tool"
: > "$W/cur/notes.txt"
: > "$W/bin1/tool"
: > "$W/bin1/tool.EXE"
: > "$W/bin1/Tool.bat"
: > "$W/bin1/toolbox"
: > "$W/bin2/tool"
: > "$W/bin2/other.cmd"
: > "$W/tree/a.txt"
: > "$W/tree/b/b.TXT"
: > "$W/tree/sub/c.txt"
: > "$W/tree/sub/deep/d.txt"
: > "$W/tree/sub/deep/e.log"
ln -s .. "$W/tree/sub/deep/loop"
ln -s ../a.txt "$W/tree/b/link.txt"
cd "$W/cur"

d() { printf '%s' "$1" | tr / '\\'; }
nl=$'\n'
syntax="Type \"WHERE /?\" for usage.$nl"
notfound="INFO: Could not find files for the given pattern(s).$nl"
P1="$W/bin1:$W/bin2"

usage_text=$(build_usage() {
    printf '%s\n' \
        'WHERE [/R dir] [/Q] [/F] [/T] pattern...' \
        '' \
        'Shows the full path of every file that matches a pattern. Without /R it' \
        'looks in the current directory, then in each directory of PATH.' \
        '' \
        '  /R dir    Search dir and every directory below it instead.' \
        '  /Q        Quiet: print nothing, only set the ERRORLEVEL.' \
        '  /F        Put each path in double quotes.' \
        '  /T        Sizes and times (not supported by this version).' \
        '  pattern   A file name; * and ? are wildcards. $VAR:pattern searches' \
        '            the directories listed in environment variable VAR, and' \
        '            dir1;dir2:pattern the directories given. Each extension' \
        '            in PATHEXT is also tried after the pattern.' \
        '' \
        'ERRORLEVEL: 0 found, 1 nothing found, 2 error.'
    printf '.'
}; build_usage)
usage_text=${usage_text%.}

# Help and version.
check_both "/? help"               0 "$usage_text" ''        '/?'
check      "-? with patterns"      0 "$usage_text"           tool '-?'
check      "--help"                0 "$usage_text"           --help
check      "--version"             0 $'where (loup-cmd-where) 0.1.0\n' --version

# The default search: the current directory, then PATH.
RUN_PATH="$P1" check_both "current directory then PATH" 0 \
    "$(d "$W/cur/tool")$nl$(d "$W/bin1/tool")$nl$(d "$W/bin2/tool")$nl" ''  tool
RUN_PATH="$P1" PATHEXT=".EXE;.BAT" check "PATHEXT extensions" 0 \
    "$(d "$W/cur/tool")$nl$(d "$W/bin1/tool")$nl$(d "$W/bin1/tool.EXE")$nl$(d "$W/bin1/Tool.bat")$nl$(d "$W/bin2/tool")$nl" tool
RUN_PATH="$P1" PATHEXT=".bat" check "case-insensitive names" 0 \
    "$(d "$W/bin1/Tool.bat")$nl"                                     'TOOL.BAT'
RUN_PATH="$P1" check "wildcard, sorted" 0 \
    "$(d "$W/cur/tool")$nl$(d "$W/bin1/tool")$nl$(d "$W/bin1/Tool.bat")$nl$(d "$W/bin1/tool.EXE")$nl$(d "$W/bin1/toolbox")$nl$(d "$W/bin2/tool")$nl" 'to*'
RUN_PATH="$P1" check "question mark" 0 "$(d "$W/bin2/other.cmd")$nl" 'other.c?d'
RUN_PATH="$P1" check "/F quotes" 0 "\"$(d "$W/bin2/other.cmd")\"$nl" /F '*.cmd'
RUN_PATH="$P1" check "each file once" 0 \
    "$(d "$W/cur/tool")$nl$(d "$W/bin1/tool")$nl$(d "$W/bin2/tool")$nl$(d "$W/bin1/toolbox")$nl" tool tool 'tool*x'
RUN_PATH="$P1:$W/bin1" check "PATH twice" 0 \
    "$(d "$W/cur/tool")$nl$(d "$W/bin1/tool")$nl$(d "$W/bin2/tool")$nl" tool
RUN_PATH="$P1" check_both "a directory is not a file" 1 '' "$notfound" tooldir
RUN_PATH="$P1" check_both "not found" 1 '' "$notfound"           nothing
RUN_PATH="$P1" check_both "/Q found"  0 '' ''                    /Q tool
RUN_PATH="$P1" check_both "/Q not found" 1 '' ''                 -q nothing
RUN_PATH="$P1" check_both "pattern after --" 1 '' "$notfound"    -- -x

# $ENV:pattern and path:pattern search only the directories they name.
BINS="$W/bin2" check "\$ENV:pattern" 0 "$(d "$W/bin2/other.cmd")$nl$(d "$W/bin2/tool")$nl" '$BINS:*'
BINS="$W/bin2;$W/bin1" check "lower-case variable" 0 "$(d "$W/bin2/tool")$nl$(d "$W/bin1/tool")$nl" '$bins:tool'
check_both "unknown variable"      2 '' $'ERROR: Environment variable "NOPE_X" is not found.\n' '$NOPE_X:tool'
check      "path:pattern"          0 "$(d "$W/bin1/tool")$nl$(d "$W/bin2/tool")$nl" "$W/bin1;$W/bin2:tool"
check      "colon-separated paths" 0 "$(d "$W/bin2/tool")$nl$(d "$W/bin1/tool")$nl" "$W/bin2:$W/bin1:tool"
check      "relative path:pattern" 0 "$(d "$W/bin1/toolbox")$nl"   '..\bin1:*box'

# /R: a directory tree, in /S order, without following directory links.
txt="$(d "$W/tree/a.txt")$nl$(d "$W/tree/b/b.TXT")$nl$(d "$W/tree/b/link.txt")$nl$(d "$W/tree/sub/c.txt")$nl$(d "$W/tree/sub/deep/d.txt")$nl"
check_both "/R tree"               0 "$txt" ''                   /R ../tree '*.txt'
check      "/R backslash dir"      0 "$txt"                      /r '..\tree' '*.TXT'
check      "/R:dir"                0 "$(d "$W/tree/sub/deep/e.log")$nl" '/R:../tree' '*.log'
check      "/R absolute dir"       0 "$(d "$W/tree/sub/c.txt")$nl" /R "$W/tree/sub/" c.txt
check      "/R several patterns"   0 "$(d "$W/tree/sub/deep/d.txt")$nl$(d "$W/tree/sub/deep/e.log")$nl" /R ../tree/sub/deep d.txt '*.log'
check_both "/R not found"          1 '' "$notfound"              /R ../tree '*.zip'
check_both "/R missing directory"  2 '' $'ERROR: The system cannot find the file specified.\n' /R ../nope x
check_both "/R a file"             2 '' $'ERROR: Invalid directory is specified.\n' /R notes.txt x
check_both "/R with \$ENV"         2 '' $'ERROR: "$env:pattern" cannot be used with /R.\n' /R . '$PATH:x'
check_both "/R with path:pattern"  2 '' $'ERROR: "path:pattern" format cannot be used with /R.\n' /R . '/bin:x'

# Usage errors (ERRORLEVEL 2).
check_both "no pattern"            2 '' "ERROR: Invalid syntax.$nl$syntax"
check_both "unknown option"        2 '' "ERROR: Invalid argument/option - '/x'.$nl$syntax" tool /x
check_both "unknown dash option"   2 '' "ERROR: Invalid argument/option - '-zz'.$nl$syntax" -zz
check_both "/R without a value"    2 '' "ERROR: Invalid syntax. Value expected for '/R'.$nl$syntax" tool /R
check_both "switch twice"          2 '' "ERROR: Invalid syntax. '/f' option is not allowed more than '1' time(s).$nl$syntax" /F tool /f
check_both "/T"                    2 '' $'ERROR: /T is not supported: Loup 1.26.0 cannot read file sizes and times.\n' /T tool
check_both "pattern with a path"   2 '' $'ERROR: Invalid pattern is specified in "path:pattern" search format.\n' 'sub\tool'
check_both "/Q hides errors"       2 '' ''                       /Q '$NOPE_X:tool'

echo "e2e: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
