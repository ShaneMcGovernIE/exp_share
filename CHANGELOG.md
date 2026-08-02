# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.2] - 2026-08-02

### Changed

- The shared-exp line now reads "EXP is shared amongst the party!" (EXP
  capitalised).

## [0.1.1] - 2026-08-02

### Fixed

- The "Exp is shared amongst the party" line now appears right after the participating Pokemon's own gains, before the bench Pokemon's level-up and move-learn messages (previously the bench level-ups queued before the share announcement).

## [0.1.0] - 2026-08-02

### Added

- EXP SHARE row in the OPTIONS menu cycling OFF / GEN 1 / GEN 5+.
- GEN 1 mode: the fighters split half the exp, the whole party splits the other half (vanilla Exp. All behavior, division bug included).
- GEN 5+ mode: the fighters keep the full exp; every alive bench mon gets half a fighter's share.
- One "Exp is shared amongst the party" line replaces the per-mon gain messages for shared exp; level-ups and move learning still show per mon.
