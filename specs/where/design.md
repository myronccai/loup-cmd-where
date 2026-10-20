# Design: where

## Overview

`main()` passes `runtime.args()` to `cli.app.run`, which parses them with
the shared switch parser (`win.switches`), handles `/?` and `--version`, and
calls `commands.wherefile.run_where` (`where` is a reserved word in Loup and
cannot be a module name). `run_where` takes each pattern apart
(`parse_query`), picks the directories to search, collects matches with the
pure-ish `search_*` functions, and prints each new one.

## Modules

| Module | Contents |
|---|---|
| `source/main.loup` | entry point: `run(runtime.args())` |
| `source/appinfo.loup` | name, version, summary, exit statuses 0, 1, 2 |
| `source/cli/args.loup` | `Options`, `where_switches()`, `parse_args`, where's usage errors |
| `source/cli/usage.loup` | `usage()` (the `/?` summary), `version_line()` |
| `source/cli/app.loup` | `run()`: parse, help/version, run, exceptions to status 2 |
| `source/commands/wherefile.loup` | `parse_query`, `split_dir_list`, `resolve_dir`, `extensions`, `search_dir`, `search_dirs`, `walk_tree`, `search_tree`, `current_dir`, `run_where` |
| `source/win/` | the shared Windows code: switches, wildcards, paths, messages |

### Arguments

`where_switches()` declares `/R` (`required_value`), `/Q`, `/F` and `/T`.
`parse_args` then checks, in order: help or version; arguments before `--`
that look like options (`/x`, `-x`, without a `:`, so `/usr/bin:ls` stays a
pattern); repeated switches; no pattern; `/T`. Each error is the full text
to print, ending with `Type "WHERE /?" for usage.` where where.exe adds it.

### Searching

- `parse_query` splits an operand at its last `:`: `$ENV` before it means
  `SEARCH_ENV`, anything else `SEARCH_PATHS`; no `:` is `SEARCH_DEFAULT`.
- `split_dir_list` splits at `;` and `:` (Windows and Linux list
  separators), drops quotes and empty entries; `resolve_dir` makes each
  entry absolute against the current directory and normalizes it.
- `extensions(PATHEXT)` is `[""]` followed by PATHEXT's entries.
- `search_dir(dir, pattern, exts)` lists the directory once and, for each
  extension, collects the names that match (`name_matches`), sorts them
  with `sort_names` and keeps the files. `name_matches` compares upper-case
  forms for patterns without wildcards and checks the literal prefix and
  suffix of a wildcard pattern before calling `wild_match`: native builds
  never free the matcher's allocations, so it only sees likely candidates.
- `current_dir()` runs `pwd -L` (`runtime.fs().cwd()` does not build
  natively in Loup 1.26.0), falling back to `$PWD`; `tool_output` also tries
  `/usr/bin/` and `/bin/`, since PATH is what where searches and may not
  list them.
- `/R`: `symlinks_under(root)` runs `find -H ROOT -type l` once (Loup has no
  `lstat()`), and `walk_tree` walks the tree in `/S` order, skipping those
  links (directory links can loop), up to `MAX_DEPTH` levels.

`run_where` prints each path (`format_path`: `display_path`, quoted for
`/F`) the first time it is found. A missing `$ENV` variable is reported and
the next pattern searched; the other errors stop the run with status 2.

### Shared code change

`win/wildcard.loup`'s `sort_names` sorts keys `UPPER<NUL>name` with a
plain comparison instead of calling `compare_names` (which upper-cases both
names) in the comparator: the same order, but a comparator that calls
`toUpperCase()` costs about 5 KB per comparison natively, so sorting a
2,900-name directory took 347 MB. To be merged into the master copy.

## Differences from the original

- Paths are printed with `\` (`\usr\bin\ls`), as every Windows command in
  this series prints paths; there are no drive letters.
- `/T` (size, date and time) is not supported: Loup 1.26.0 has no `stat()`
  (roadmap constraint T1).
- Directory lists accept `:` as well as `;`, since Linux's `PATH` uses `:`;
  so a directory whose name contains `:` cannot be listed.
- With PATHEXT unset (the usual case on Linux), only the pattern itself is
  searched.
- Environment variable names are tried as given, then in upper case (Linux
  names are case-sensitive).
- `/R` does not descend into symbolic links to directories.
- Relative entries in `PATH` and in `dir:pattern` lists are resolved
  against the current directory.
- `/?` prints this project's own short summary, not Microsoft's help text.
- `--version` and `--help` (alone) are series conventions.

## Error handling

Usage errors stop before searching (status 2). Run-time errors for `/R`
and patterns are printed (unless `/Q`) and give status 2; nothing found
gives status 1 and the `INFO:` line. An unexpected exception is printed as
`ERROR: message` with status 2.

## Testing

- `tests/args_test.loup`: switches, `/R` values, `path:pattern` versus
  options, every usage error, `--`, help and version.
- `tests/wherefile_test.loup`: `parse_query`, `valid_pattern`,
  `split_dir_list`, `resolve_dir`, `extensions`, prefix and suffix,
  `format_path`, `default_dirs`, and `search_dir`/`search_dirs`/
  `search_tree` against a fixture tree in `build/tmp/`.
- `tests/app_test.loup`: exit statuses through `run()`.
- `tests/win_*_test.loup`: the shared Windows code.
- `tests/e2e.sh`: the native binary in a fixture tree under `$TMP` with
  `PATH` set to fixture directories (`RUN_PATH`), including a symbolic
  link loop under `/R`.
