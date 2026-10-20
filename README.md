# loup-cmd-where

The Windows `where` command recreated in [Loup](https://code-craft.ai/references/loup):
find files by name pattern on `PATH`, in listed directories or under a
directory tree, with where's pattern forms, switches, messages and
ERRORLEVELs, on Linux.

Part of the **loup-cmd** series of example applications: classic Linux and
Windows commands, and projects for each Loup execution mode, each in its own
repository under [myronccai](https://github.com/myronccai?tab=repositories&q=loup-cmd).
This one is `host.dual` Loup built as a native binary. It uses the shared
Windows code in [`source/win/`](source/win/) (switch parser, wildcard
matcher, path helpers, messages), copied from
[loup-cmd-type](https://github.com/myronccai/loup-cmd-type).

## Requirements

- [Loup Lite](https://github.com/code-craft-ai-company/loup-releases) 1.26.0
  or later; see [Installing Loup Lite](#installing-loup-lite).
- `make`, and `clang` 17 or later for the native build.

## Installing Loup Lite

This example is built and tested with **Loup Lite**, the free public build of
the Loup toolchain from [Code Craft AI](https://code-craft.ai), meant for
education and training. Code Craft AI publishes the official builds,
installers and signed checksums at
**<https://github.com/code-craft-ai-company/loup-releases>**, for Linux
(x86-64, arm64), macOS (Apple silicon, Intel) and Windows (x86-64).

Linux and macOS:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.sh | sh
```

Windows (PowerShell):

```powershell
irm https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.ps1 | iex
```

The installer picks the archive for your machine, checks it against the
release's `SHA256SUMS`, unpacks it into `~/.loup`
(`%LOCALAPPDATA%\Programs\Loup` on Windows) and puts its `bin` directory on
your `PATH`; it needs no administrator rights. You get `loup`, the Stage0
compiler `loup-bootstrap` and the Wasm runtime `loup-launcher`. Open a new
shell and check:

```sh
loup --version             # loup 1.26.0 or later
```

CI installs the exact version it tests with, 1.26.0. To do the same:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/download/v1.26.0/loup-install.sh | sh -s -- --version 1.26.0
```

To install by hand, download your platform's archive from the
[releases page](https://github.com/code-craft-ai-company/loup-releases/releases),
check it against `SHA256SUMS`, unpack it anywhere and add its `bin` directory to
`PATH`. The [loup-releases README](https://github.com/code-craft-ai-company/loup-releases#verify-a-download)
explains how to verify the Sigstore signature on `SHA256SUMS`.

Loup Lite leaves out Loup's cryptography library and the full set of Loup
packages; this example needs neither. The full release is at
<https://code-craft.ai/loup/download>, and commercial use of Loup needs a
license: <https://code-craft.ai/loup/license>.

## Usage

```sh
make build                    # native binary: build/where
make ci                       # check, unit tests, build, end-to-end tests
make run ARGS="ls"            # run from source with loup run
```

Quote patterns that contain `*`, `?`, `$` or `;` so that the Linux shell
passes them through. Run in `/usr/share/doc` with
`PATH=/usr/local/bin:/usr/bin:/bin`:

```text
$ build/where ls
\usr\bin\ls
\bin\ls
$ build/where '$PATH:gcc-1?'
\usr\bin\gcc-13
\usr\bin\gcc-15
\bin\gcc-13
\bin\gcc-15
$ build/where /F python3
"\usr\bin\python3"
"\bin\python3"
$ PATHEXT='.10;.12' build/where python3
\usr\bin\python3
\usr\bin\python3.10
\bin\python3
\bin\python3.10
$ build/where '/usr/sbin;/sbin:ip*tables'
\usr\sbin\ip6tables
\usr\sbin\iptables
\sbin\ip6tables
\sbin\iptables
$ build/where /R git '*.gz'
\usr\share\doc\git\changelog.Debian.gz
\usr\share\doc\git\NEWS.Debian.gz
$ build/where /Q nosuchtool; echo "ERRORLEVEL $?"
ERRORLEVEL 1
$ build/where nosuchtool; echo "ERRORLEVEL $?"
INFO: Could not find files for the given pattern(s).
ERRORLEVEL 1
$ build/where /x; echo "ERRORLEVEL $?"
ERROR: Invalid argument/option - '/x'.
Type "WHERE /?" for usage.
ERRORLEVEL 2
$ build/where --version
where (loup-cmd-where) 0.1.0
```

```text
WHERE [/R dir] [/Q] [/F] [/T] pattern...
```

| Pattern or switch | Effect |
|---|---|
| `pattern` | a file name; `*` and `?` are wildcards (Win32 rules, case-insensitive). Searched in the current directory, then in each directory of `PATH` |
| `$ENV:pattern` | search only the directories listed in environment variable `ENV` |
| `dir1;dir2:pattern` | search only the directories given (split at the last `:`) |
| `/R dir` | search `dir` and every directory below it (also `/R:dir`) |
| `/Q` | print nothing; only set the ERRORLEVEL |
| `/F` | print each path in double quotes |
| `/T` | not supported (see below) |
| `/?` | a summary of the syntax and switches |

In each directory the pattern is tried as given, then with each extension
in `PATHEXT` appended (`PATHEXT=.EXE;.BAT` makes `tool` also find
`tool.exe` and `Tool.bat`); each group of matches is sorted by name. Only
files are listed, each one once, as a full path written with `\`.
Directory lists may use `;` or `:` between entries. Switches start with `/`
or `-`, in any case; `--` ends switch parsing.

Exit status (ERRORLEVEL): `0` if a file was found, `1` if nothing matched
(`INFO: Could not find files for the given pattern(s).` on standard error),
`2` for errors (`ERROR: ...`).

## Differences from the original

- Paths are printed with `\` (`\usr\bin\ls`), like every path in this
  series of Windows commands; there are no drive letters.
- `/T` (size, date and time of each file) is not supported: Loup 1.26.0 has
  no `stat()` (roadmap constraint T1). `where /T` says so and exits with 2.
- Directory lists accept `:` as well as `;`, because Linux's `PATH` uses
  `:`. Relative entries are resolved against the current directory.
- With `PATHEXT` unset, as it usually is on Linux, only the pattern itself
  is searched.
- `$ENV:pattern` tries the variable name as given, then in upper case
  (`$path:x` finds `PATH`), since Linux names are case-sensitive.
- `/R` does not descend into symbolic links to directories (they can form
  loops, and without `lstat()` they are found with one `find` call).
- A missing `$ENV` variable is reported and the other patterns are still
  searched; the exit status is then 2.
- `/?` prints this project's own short summary of the syntax and switches,
  not Microsoft's help text.
- `--help` and `--version` as the only argument are series conventions.

## Layout

```text
source/main.loup                # entry point
source/appinfo.loup             # name, version, exit statuses 0/1/2
source/cli/args.loup            # where's switches and usage errors via win.switches
source/cli/usage.loup           # /? and --version text
source/cli/app.loup             # run(): parse, run, exit status
source/commands/wherefile.loup  # pattern forms, directory lists, matching, /R walk (`where` is a Loup reserved word)
source/win/                     # shared Windows code: switches, wildcards, paths, messages
tests/*_test.loup               # unit tests (make test)
tests/e2e.sh                    # end-to-end tests of build/where (make e2e)
specs/where/                    # requirements, design, tasks
```

`source/win/wildcard.loup` differs from the master copy in one function:
`sort_names` sorts precomputed upper-case keys, which is much cheaper in
native builds (see [the design](specs/where/design.md#shared-code-change)).

[AGENTS.md](AGENTS.md) has every build and test command and the conventions
for changing the code.

## License

[MIT](LICENSE), copyright 2026 Code Craft AI LLC. The Loup skill in
[`skills/loup-programmer/`](skills/loup-programmer/) is copied from the Loup
project and is not covered by this license; it keeps the Loup project's terms.
