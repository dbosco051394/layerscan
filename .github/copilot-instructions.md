# Copilot instructions: LayerScan scanner (working name)

## What this project is

A Go tool, packaged as a small container image, that scans a published container image and reports layer-aware findings. It wraps Trivy, Syft, Grype, and Dive, normalizes their output into one schema, and applies a pass/fail policy. The same normalized result feeds a GitHub Action and a REST API (separate repos).

- The product name is a working name. Define it in exactly one place (a constant and the Go module path) and never hardcode it elsewhere, so renaming is a single change.
- The contract is `schema/scan-result.v1.schema.json`. Every normalized output must validate against it.

## Current phase: spike

Until the exit criteria in `docs/SPIKE.md` are met:

- Do not write production parsers, runners, or APIs. Throwaway scripts are fine.
- Follow the tasks and ground rules in `docs/SPIKE.md`.
- If real tool output contradicts the docs or the schema, do not guess. Record the contradiction in `docs/SPIKE-FINDINGS.md` and propose a schema change.
- Treat every `provisional` marker in the schema as unconfirmed.

## Architecture rules (do not break these)

1. **Never run a scanned image.** Only read it. No `docker run`, no container execution of untrusted images, anywhere in the code, tests, or CI.
2. **No Docker daemon in the service.** Pull the image once into a local archive (use `go-containerregistry`) and have every tool read that same archive. Local Docker is allowed only for building test images during development.
3. **Wrap, don't reimplement.** Each tool lives behind an adapter that implements a small interface and returns normalized findings. Scanner names are open strings so new tools can be added without schema changes.
4. **Prefer layer attribution over scanning isolated layer diffs.** Scan once, then record the first layer where each finding appears. Package databases are cumulative, so isolated diff scans mislead.
5. **One policy implementation.** Pass/fail logic lives in a single package used by the CLI, the Action, and the API. Do not duplicate it.
6. **A tool failure is explicit.** A scanner that crashes or times out is recorded in `scanners[]` and sets `verdict.complete=false`. Never silently drop it.

## Security rules

- **Never log, print, or store a raw secret.** Redact matches before they leave the scanner process. `match_redacted` must never contain the secret value. Do not log request bodies, tool stdout containing matches, or registry credentials.
- **Treat all input as untrusted:** image references, registry responses, image contents, and tool output.
- **Run subprocesses safely.** Use `exec.CommandContext` with an argument slice, never a shell string. Always set a context timeout and cap captured output size.
- **Never pass credentials on the command line.** They leak via process listings and logs.
- **Pin every external tool by exact version and checksum.** No `latest`. Verify checksums in the Dockerfile.
- **Fixtures use only documented fake credentials** (such as the AWS example keys). Create fake secrets inside `RUN` steps, not as committed files. Never commit image archives.
- **GitHub Actions workflows:** pin third-party actions to a full commit SHA and declare least-privilege `permissions`.

## Go conventions

- Idiomatic Go, current stable version declared in `go.mod`. Standard library first; justify each new dependency in the PR description.
- Wrap errors with `fmt.Errorf("doing x: %w", err)`. Return errors; no panics in library code. Pass `context.Context` as the first parameter.
- Define small interfaces where they are consumed, not where they are implemented.
- Keep functions short and packages focused. Exported identifiers get doc comments.
- The maintainer is learning Go. For any non-obvious idiom (interfaces, goroutines, error wrapping, generics), add a brief "why" comment or an explanation in the PR description.
- `golangci-lint` and `govulncheck` must pass before a change is considered done.

## Testing

- Table-driven tests with the standard `testing` package. `testify` is allowed for assertions.
- Parser tests run against real captured output in `testdata/raw/`, with golden files for normalized results. Do not hand-write tool output when real output is available.
- Unit tests must not use the network or a Docker daemon.
- Every normalized result produced in a test is validated against the JSON Schema.
- Cover edge cases: empty results, a scanner crash, a timeout, a missing layer identifier, and a shadowed finding.

## Workflow

- Small, focused PRs with conventional-commit messages and a description explaining the decision, not just the change.
- Any decision listed under "ADRs to write afterward" in `docs/SPIKE.md` gets an ADR in `docs/adr/` before the code that depends on it merges.
- A schema change requires: updating the schema, updating the example, bumping `schema_version` if breaking, and passing the schema validation test.
- Do not add a new scanner, dependency, or feature outside the current scope without asking first.
- When uncertain, ask. A short question costs less than a wrong assumption.
