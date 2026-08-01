# Contributing

Contributions are welcome when they preserve the project's tested scope,
security boundaries, and documented provenance.

## Repository language

English is the mandatory language for all public repository content. Public
documentation, CLI help and error output, source-code comments, tests and test
output, Nix option descriptions, issues, pull requests, review replies, and
release notes must be written in English.

Keep command names, paths, identifiers, hashes, manufacturer and product names,
proper names, and public project names unchanged when they are not natural
language text.

## AI-assisted contributions

AI-assisted contributions are permitted. Substantial AI assistance must be
disclosed in the contribution, issue, or pull request. Generated content must
be reviewed before merge.

The human contributor or maintainer remains responsible for correctness,
security, licensing, provenance, testing, and merge decisions.

## Security, privacy, and support claims

- Do not commit secrets, private paths, logs, account data, serial numbers, or
  personal data.
- Do not present unverified hardware support as tested.
- Do not add a world-writable HIDRAW rule or `MODE="0666"`.
- Do not add a global HIDRAW permission rule.
- Do not add automatic Wine registry manipulation.
- Preserve explicit VID:PID scoping and validate behavioral changes against
  the relevant hardware before presenting them as supported.
