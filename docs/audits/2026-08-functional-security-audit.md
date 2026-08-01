# 2026-08 functional and security audit

## Scope and baseline

This was an independent, adversarial audit of the SpaceMouse repository at
main commit `ee507dc84155bc583952dee33012960623dae273` (tree
`a7300bd946953a9147e2c0343392a41bedf75ee3`). Existing documentation and tests
were treated as claims to reproduce, not as proof. The starting repository had
26 tracked files and no GitHub Actions workflow. The GPL-3.0 license hash was
`3972dc9744f6499f0f9b2dbf76696f2ae7ad8af9b23dde66d6af86c9dfb36986`.

The audit branch is `audit/deep-functional-security-2026-08`. Testing used
synthetic sysfs/device trees, isolated Udev roots, isolated profile directories,
Nix builds, NixOS module evaluation, fixed-seed property tests, static tools,
and failure injection. It did not install or reload a real Udev rule, consume
device events, change an ACL, change group membership, start Wine or a game, or
modify a game file.

Live read-only testing was completed after explicit confirmation that the
tested USB SpaceMouse was connected and the game and launcher were closed. No
device event or raw report was consumed.

## Methodology

The audit mapped documentation to implementation, reviewed every shell script
and original assertion, built independent fixtures, tested success and
fail-closed behavior, injected failures and signals around publication, checked
the immutable profile semantically and byte-for-byte, evaluated the NixOS
module, and manually reviewed scanner output. A private cross-project contract
test compares the SpaceMouse policy with Citizen Input Manager without creating
a runtime dependency.

## Live read-only hardware validation

On 2026-08-01, repository commit
`8f1fa0654f3110452993a367c734b4ef2d6a835b` was tested read-only with one
connected USB SpaceMouse. VID:PID `256f:c63a` was confirmed through its
canonical USB ancestor. HIDRAW, event, and joystick node types were associated
dynamically, with no ambiguous HIDRAW match. Effective HIDRAW read and write
access both succeeded for the active desktop user.

The active rule was byte-identical to the repository's scoped HIDRAW
`TAG+="uaccess"` policy and contained no `MODE`, `GROUP`, `OWNER`, executable,
global HIDRAW, or input-subsystem permission directive. No device event,
joystick event, or raw HID report was consumed. No system configuration, Udev
rule, ACL, group, Wine state, Star Citizen file, or game state was changed.
Gameplay was not retested during this phase; the earlier gameplay reference
remains historical manual evidence only.

## Functional claim matrix

| Claim | Documentation | Implementation | Evidence | Result | Remaining limitation |
| --- | --- | --- | --- | --- | --- |
| Discovery identifies `256f:c63a` through a canonical USB ancestor rather than leaf identity properties. | `README.md`, `docs/security.md` | `scripts/spacemouse-detect`, `scripts/lib/spacemouse-device.sh` | Synthetic ancestor-only, wrong-ID, missing-attribute, escaping-link, stale-node, and depth-limit fixtures plus live USB-ancestor validation | VERIFIED | The USB reference path was tested; Bluetooth and Universal Receiver remain unverified. |
| Node numbers are dynamic and HIDRAW ambiguity fails closed for access verification. | `docs/troubleshooting.md` | discovery and verification scripts | Nonzero node numbers, multiple HIDRAW nodes, zero matches, and wrong IDs | VERIFIED | Multiple nodes from one physical USB device remain deliberately ambiguous for the access command. |
| Access output reports mode, owner, group, ACL, and effective read and write separately. | CLI help and `docs/generic-linux.md` | `scripts/spacemouse-verify-access` | Read/write and read-only fixture modes plus live mode, ownership, ACL, and effective access validation | VERIFIED | Access is a point-in-time session result and can change after verification. |
| The Udev policy is only HIDRAW `256f:c63a` with `TAG+="uaccess"`. | README and security documentation | rule file, installer, NixOS module | Exact byte comparison, forbidden-directive scan, and `udevadm verify` | VERIFIED | No real rule was installed or reloaded. |
| Udev publication is transactional and recoverable. | `docs/generic-linux.md` | install/remove scripts and secure-file helpers | Empty/replacement/repeat/remove/restore flows; links, special files, canonical roots; all failpoints; INT/TERM/HUP; rollback-failure recovery | VERIFIED | A hostile mount namespace is outside the shell tool's trust model. |
| The exported profile is the documented immutable delta. | profile README and Star Citizen guide | exported XML and profile scripts | Required SHA-256, `SHA256SUMS`, XML parse, exact eight-entry delta, name consistency, inversion, and forbidden-rebind scan | VERIFIED | Gameplay and import behavior were not repeated because live events/game startup are out of scope. |
| Profile installation is validated and transactional. | profile README | install/remove scripts | Install, replace, backup, restore, removal, malformed/oversized/invalid UTF-8/DTD/entity inputs, link/special-file defenses, all failpoints and signals | VERIFIED | Only isolated directories were used. |
| Installation discovery is bounded to explicit and known paths. | `docs/star-citizen.md` | finder script | Nix-Citizen, Wine, Lutris, UMU/Proton, LUG Helper, explicit paths, duplicates, symlinks, noncanonical and inaccessible paths | VERIFIED | Actual third-party layouts may change. |
| Documented commands agree with the implemented CLI. | README and guides | all scripts and flake outputs | Help/dry-run paths, copy-safe profile preview, development commands, and synthetic equivalents of hardware commands | PARTIALLY_VERIFIED | Real-root installation commands were not executed because this audit prohibits system changes. |
| The NixOS module installs the CLI and exact early Udev rule only when enabled. | `docs/nixos.md` | module and flake checks | Enabled/disabled/empty/duplicate evaluation; exact early-rule file; no service, user service, user/group, or tmpfiles integration | VERIFIED | Evaluated on both declared systems; built on `x86_64-linux`; no booted VM. |
| Generic Linux support is universal. | No longer claimed | generic scripts | Nix-built fixture tests only | NOT_VERIFIED | Distribution-specific Udev, shell, filesystem, and game layouts were not tested. |
| Six axes and gameplay behavior work in the historical reference environment. | README and profile README | immutable profile | Profile semantics reproduced; no live event or gameplay test permitted | NOT_VERIFIED | Requires a separate event-consumption decision and game-side manual test. |

## Findings and fixes

No CRITICAL or HIGH finding was found in this project. All MEDIUM findings were
fixed on the audit branch.

### A-01 — MEDIUM — incomplete transactional rollback

- Affected: Udev and profile installers/removers.
- Root cause: backups existed, but ordinary failures and signals around
  publication did not consistently restore the prior target or clean candidate
  files.
- Reproduction: inject failures before and after rename and send INT, TERM, and
  HUP in isolated destinations.
- Impact: an interrupted operation could leave a changed target or incomplete
  recovery state.
- Fix: same-directory candidates, unique backups, pre-publication rechecks,
  signal traps, rollback after publication, cleanup, and explicit validated
  restore paths.
- Regression: the complete failure matrix also injects cleanup and rollback
  failures and proves either restoration or a preserved recovery backup.
- Residual risk: mount replacement by a privileged concurrent adversary is not
  eliminated by shell path checks.

### A-02 — MEDIUM — profile input and target validation gaps

- Affected: profile installation and removal.
- Root cause: XML size/encoding/DTD constraints and hardlink/canonical-path
  defenses were incomplete.
- Reproduction: supply malformed, oversized, invalid UTF-8, DTD/entity,
  noncanonical, symlinked, hard-linked, special-file, or injected-name inputs.
- Impact: unsafe file handling, unintended target selection, or unbounded parser
  work.
- Fix: a 2 MiB NUL-free UTF-8 limit, DTD/entity rejection, non-network XML
  validation, consistent safe names, canonical paths, and target link/type
  checks.
- Regression: deterministic adversarial and property tests cover each input
  class and empty explicit names.
- Residual risk: the validator proves structural safety, not game acceptance of
  arbitrary third-party profiles.

### A-03 — MEDIUM — rollback tests did not reach their intended path

- Affected: the original profile rollback assertions.
- Root cause: a symlink-attack fixture was left in place; later tests failed at
  the initial symlink check and were incorrectly interpreted as failpoint
  success.
- Reproduction: trace the original test sequence and observe that no publication
  failpoint executes.
- Impact: green tests overstated transactional coverage.
- Fix: remove the attack fixture before rollback cases and assert the specific
  rollback-failure marker plus recovery-backup content.
- Regression: all publication failpoints are now demonstrably reached.
- Residual risk: none known within the isolated filesystem model.

### A-04 — LOW — incomplete release and Nix validation surface

- Affected: the original flake and missing CI workflow.
- Root cause: only the module was exposed; packages, apps, lock data, checks, and
  CI coverage were absent.
- Impact: documented commands and module behavior were not continuously built.
- Fix: pinned Nixpkgs, packages/apps, both-system evaluation, module assertions,
  local checks, a development shell, and least-privilege SHA-pinned CI.
- Regression: `nix flake check`, all exposed `x86_64-linux` builds, app help, and
  all-system output evaluation.
- Residual risk: `aarch64-linux` was evaluated but not built on native hardware.

### A-05 — LOW — overbroad wording and incomplete access output

- Affected: README title and access verifier output.
- Root cause: “Universal” exceeded tested evidence, and a combined read/write
  result obscured which permission failed.
- Impact: misleading portability and weaker diagnostics.
- Fix: narrow the support wording and report read and write independently.
- Regression: documentation and permission-mode assertions.
- Residual risk: generic distribution compatibility remains unverified.

## Shared threat model

`PREVENTED` means attacker-controlled data is not interpreted as code or cannot
reach the boundary. `DETECTED_AND_REJECTED` means validation fails closed.
`OUT_OF_SCOPE_WITH_JUSTIFICATION` records a trust boundary; it is not a claim of
protection against that actor.

| Threat | Status | Evidence or justification |
| --- | --- | --- |
| Command injection through CLI arguments | DETECTED_AND_REJECTED | Fixed option parsers, quoting, identifier allowlists, and property tests. |
| Command injection through JSON manifest values | OUT_OF_SCOPE_WITH_JUSTIFICATION | Project A has no JSON manifest parser or renderer. |
| Command injection through manufacturer/product strings | PREVENTED | Device metadata is printed as data and never evaluated. |
| Command injection through filenames and paths | DETECTED_AND_REJECTED | Quoted arguments, canonical paths, and safe output-name allowlists. |
| Command injection through Game.log or XML content | DETECTED_AND_REJECTED | No Game.log parser; XML is data-only, bounded, and DTD/entity declarations are rejected. |
| Use of eval, unsafe source, indirect expansion, or executable data | PREVENTED | No `eval`; only fixed adjacent packaged libraries are sourced; input data is never sourced. |
| Unquoted word splitting and glob expansion | PREVENTED | Manual review plus ShellCheck; deliberate globs are array-bounded. |
| Malicious PATH and command shadowing | OUT_OF_SCOPE_WITH_JUSTIFICATION | Packaged tools prepend pinned Nix store programs; source-checkout execution requires a trusted developer PATH. |
| Hostile IFS, locale, TMPDIR, HOME, XDG variables, and umask | DETECTED_AND_REJECTED | Canonical path checks, explicit modes, randomized `mktemp`, bounded HOME candidates, and locale-stable parsing; trusted process environment remains required. |
| Path traversal | DETECTED_AND_REJECTED | Absolute canonical paths and safe basenames. |
| Symlink traversal | DETECTED_AND_REJECTED | Roots, ancestors, sources, directories, and targets are checked. |
| Hardlink abuse | DETECTED_AND_REJECTED | Mutable targets must have link count one. |
| Mountpoint confusion | OUT_OF_SCOPE_WITH_JUSTIFICATION | The invoking administrator must provide a stable trusted mount namespace. |
| Canonicalization mismatch | DETECTED_AND_REJECTED | Lexical input must equal its resolved canonical path. |
| Time-of-check/time-of-use races | OUT_OF_SCOPE_WITH_JUSTIFICATION | Targets are rechecked immediately before rename; hostile concurrent mount/ancestor replacement requires a lower-level API than these shell tools. |
| Unsafe temporary files | PREVENTED | Random same-directory files, explicit modes, and trap cleanup. |
| Predictable backup names | PREVENTED | Timestamped names also contain random `mktemp` suffixes. |
| Backup overwrite | PREVENTED | `mktemp` creates each backup exclusively. |
| Partial write or interrupted rename | PREVENTED | Complete candidates are written before atomic same-directory rename. |
| Failure between backup and publication | PREVENTED | Original remains active and backup remains recoverable. |
| Rollback failure | DETECTED_AND_REJECTED | Injected rollback failure retains the original unique backup and reports failure. |
| Special files, FIFOs, sockets, block devices, and character devices | DETECTED_AND_REJECTED | Repository inputs/targets require the expected regular-file or directory type; live `/dev` nodes are read-only inputs. |
| Oversized JSON, XML, Game.log, and manifest inputs | DETECTED_AND_REJECTED | XML is limited to 2 MiB; the other parsers do not exist in Project A. |
| Excessive element/node counts | PREVENTED | The XML byte limit and non-huge libxml parser bound work; device traversal and candidates are bounded. |
| Deeply nested JSON or XML | DETECTED_AND_REJECTED | No JSON; libxml depth limits apply without huge-parser mode. |
| Malformed UTF-8 | DETECTED_AND_REJECTED | Profile bytes must decode strictly as UTF-8. |
| Embedded NULs where relevant | DETECTED_AND_REJECTED | Text validation rejects NUL bytes. |
| XML external entities and network entity resolution | DETECTED_AND_REJECTED | DTD/entity declarations are rejected and `xmllint --nonet` is used. |
| Regex denial of service | PREVENTED | Expressions are simple/anchored and operate on bounded fields/files. |
| Duplicate devices | DETECTED_AND_REJECTED | Duplicate module pairs fail assertions; multiple HIDRAW matches fail access verification. |
| Identical VID:PID devices | DETECTED_AND_REJECTED | Ambiguous HIDRAW selection cannot pass access verification. |
| Missing USB ancestor attributes | DETECTED_AND_REJECTED | No device match is produced. |
| Malicious or disappearing sysfs paths | DETECTED_AND_REJECTED | Paths must resolve within the selected root and missing paths fail closed. |
| More than 32 ancestor levels | DETECTED_AND_REJECTED | Traversal is capped and the deep fixture does not match. |
| Multiple matching HIDRAW nodes | DETECTED_AND_REJECTED | Access verification requires exactly one. |
| Stale `/dev` nodes | DETECTED_AND_REJECTED | A canonical node and matching current USB ancestor are required. |
| Permission changes between discovery and verification | OUT_OF_SCOPE_WITH_JUSTIFICATION | Verification reports effective access at its own check time and never promises a lease. |
| Privacy leakage | PREVENTED | Public repository scans reject private markers; finder output remains local and explicit. |
| Secret leakage | PREVENTED | Gitleaks, Trivy secret scanning, and manual review found none. |
| GitHub Actions supply-chain risks | PREVENTED | Minimal permissions, hosted runner, no fork secrets or untrusted context interpolation. |
| Unpinned Actions | PREVENTED | All Actions use independently tag-verified full commit SHAs. |
| Excessive workflow permissions | PREVENTED | Workflow grants only `contents: read`. |
| Nix evaluation-time network access | PREVENTED | Locked local evaluation completed offline. |
| Import-from-derivation | PREVENTED | No IFD mechanism is used. |
| Accidental inclusion of private files in Flake sources | PREVENTED | An untracked sentinel was absent from the Git-derived source closure. |
| Incorrect support-status escalation | DETECTED_AND_REJECTED | Documentation distinguishes the historical tested USB reference from unverified transports/builds. |
| Unsafe Udev output | PREVENTED | Exact static rule plus forbidden-directive scan and Udev parser verification. |
| Unexpected input-subsystem permission widening | PREVENTED | Only `SUBSYSTEM=="hidraw"` is emitted. |

## Tooling and test results

The final local matrix passed with Nix 2.34.8, Bash 5.3.15, ShellCheck 0.11.0,
shfmt 3.13.1, jq 1.8.2, Python 3.14.6, libxml 2.15.3, Udev 260,
actionlint 1.7.12, zizmor 1.28.0, gitleaks 8.30.1, Trivy 0.72.0, and
Semgrep 1.164.0. Semgrep ran three local shell rules and found nothing. Trivy's
secret scan was clean; its misconfiguration scanner recognized no supported
configuration files, so workflow conclusions rely on actionlint, zizmor, and
manual review rather than that scanner. Gitleaks found no secret.

`nix flake metadata --offline`, all-system `nix flake show`,
`nix flake check --no-write-lock-file`, the exposed `x86_64-linux` package
build, and the app help path passed. The lock hash remained
`9f7c125146ac516be8b1ed04433e83871bf512ae54b567e60ca3859dade87f87`.
`aarch64-linux` outputs evaluated but were not built. No booted NixOS VM was
needed because the module evaluation check directly proves exact output and
absence properties without hardware.

The profile hash remains
`f76f84c085702a0aca2a0ae174f9ac2fc8d4221dbf2f6d051e9bd4820ec4c5db`.

## GitHub Actions review

The added workflow has minimal permissions, no `pull_request_target`, no
self-hosted runner, no artifact upload, no mutable download, no untrusted
context in shell, and disables checkout credential persistence. The pinned
`actions/checkout` SHA corresponds to upstream tag `v5.1.0`; the pinned
`cachix/install-nix-action` SHA corresponds to upstream tag `v31`. Actionlint
and offline pedantic zizmor report no finding. CI runs the same core
`nix flake check --no-write-lock-file` matrix used locally.

## Unverified boundaries and readiness

- Live USB discovery and effective HIDRAW read/write access passed for the
  tested reference device.
- No device event was read; six-axis/gameplay behavior was not retested.
- Bluetooth and Universal Receiver operation remain unverified.
- No Wine runner, launcher, game build, generic Linux distribution, or
  `aarch64-linux` machine was exercised.
- Pre-live follow-up CI passed. CI for this live-documentation commit and
  automated pull-request review remain pending.

Current state: `SPACEMOUSE_AUDIT_READY=NO`. The reasons are the pending live
documentation CI/review, not an unresolved CRITICAL/HIGH/MEDIUM code finding or
a failed live check.

## AI-assisted audit

This audit and its supporting test development were performed with
substantial assistance from OpenAI Codex. The human maintainer remains
responsible for reviewing the findings, validating fixes, assessing residual
risk, and making release and merge decisions.
