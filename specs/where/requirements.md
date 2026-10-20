# Requirements: where

## Introduction

`where` is the Windows command that finds files by name pattern, by default
in the current directory and the directories of `PATH`, and prints their
full paths. This repository recreates it in Loup for Linux, keeping its
pattern forms, switches, messages and ERRORLEVELs, with the Windows
conventions from the shared code in `source/win/` (master copy:
loup-cmd-type).

## Requirements

### Requirement 1: Default search

**User Story:** As a cmd user, I want to know which file a command name
runs, and where other copies are.

#### Acceptance Criteria

1. WHEN a pattern is given without `/R`, THE program SHALL search the
   current directory, then each directory of `PATH` in order, and print
   the full path of each matching file, one per line, with `\` separators.
2. THE program SHALL accept `;` and `:` as separators in `PATH` and in other
   directory lists, and resolve relative entries against the current
   directory.
3. IN each directory, THE program SHALL try the pattern as given, then with
   each extension of `PATHEXT` (`;`-separated) appended, and print each
   group of matches sorted by name.
4. THE program SHALL match names case-insensitively, with `*` and `?`
   following the Win32 wildcard rules, and SHALL list files only.
5. THE program SHALL print each file once, even when several patterns or
   directories find it.

### Requirement 2: Pattern forms and switches

**User Story:** As a cmd user, I want where's search forms and switches.

#### Acceptance Criteria

1. WHEN a pattern has the form `$ENV:pattern`, THE program SHALL search only
   the directories listed in variable ENV (trying the name as given, then in
   upper case); WHEN the variable is not set, it SHALL print
   `ERROR: Environment variable "ENV" is not found.`, go on, and exit with
   status 2.
2. WHEN a pattern has the form `dir1;dir2:pattern` (split at its last `:`),
   THE program SHALL search only the directories listed.
3. WHEN `/R dir` is given, THE program SHALL search dir and every directory
   below it, depth first in sorted order, without following symbolic links
   to directories, and print full paths.
4. WHEN `/Q` is given, THE program SHALL print nothing and only set the
   exit status. WHEN `/F` is given, it SHALL print each path in double
   quotes.
5. THE program SHALL accept switches with `/` or `-` in any case, `/R dir`,
   `/R:dir`, and `--` to end switch parsing; WHEN `/?` is given it SHALL
   print a short summary of the syntax and switches and exit with status 0.

### Requirement 3: Errors and exit statuses

**User Story:** As a script author, I want where's ERRORLEVELs and messages.

#### Acceptance Criteria

1. THE exit status SHALL be 0 when a file was found, 1 when nothing matched
   (with `INFO: Could not find files for the given pattern(s).` on standard
   error), and 2 for errors.
2. WHEN an argument before `--` looks like an option and is not one, no
   pattern is given, `/R` has no value, or a switch is repeated, THE program
   SHALL print the matching `ERROR: Invalid ...` message and
   `Type "WHERE /?" for usage.` and exit with status 2.
3. WHEN `/R` names a missing path or a file, or is combined with
   `$ENV:pattern` or `path:pattern`, or a pattern contains a path
   separator, THE program SHALL print where's error message and exit with
   status 2.
4. WHEN `/T` is given, THE program SHALL say that it is not supported and
   exit with status 2.
