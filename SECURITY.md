# Security Policy

## Supported versions

ClipHist is a single-developer project. Only the latest `0.x` release line receives security fixes.

| Version | Supported |
|---------|-----------|
| 0.2.x   | ✅        |
| < 0.2   | ❌        |

## Reporting a vulnerability

**Please do not file public GitHub issues for security problems.**

Use GitHub's private vulnerability reporting:
[https://github.com/arseniy-pplx/clip-hist/security/advisories/new](https://github.com/arseniy-pplx/clip-hist/security/advisories/new)

Include:

- Affected version (e.g. `v0.2.0`, commit SHA, or built artifact SHA-256)
- Reproduction steps
- Impact assessment (data exposure, code execution, sandbox escape, etc.)
- Suggested mitigation if you have one

I aim to acknowledge new reports within **5 business days** and to ship a fix or
mitigation within **30 days** for high-severity issues. Lower-severity reports
will be handled on a best-effort basis.

## Scope

In scope:

- The `ClipHist` macOS application binary distributed via this repository's
  GitHub Releases or CI artifacts.
- The source code in this repository.
- The CI/CD configuration in `.github/workflows/`.

Out of scope:

- Third-party forks or repackaged distributions.
- Issues that require physical access to the user's unlocked machine.
- Theoretical issues that depend on the user disabling macOS Accessibility,
  Gatekeeper, or other built-in protections.

## Threat model notes

- ClipHist stores clipboard history in plain JSON at
  `~/Library/Application Support/ClipHist/history.json`. By design, it follows
  whatever filesystem protections the user's home directory has — there is no
  additional at-rest encryption.
- ClipHist honors the `org.nspasteboard.ConcealedType` pasteboard hint and the
  configurable ignored-bundle-ID list. Bypassing these is treated as a bug.
- Synthetic `⌘V` requires Accessibility permission, granted explicitly by the user.
