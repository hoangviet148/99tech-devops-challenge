# ADR-P5-0011: Signed images admitted by Kyverno

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-P5-1 |
| Principles | SEC-DP4, FSI-DP3, FSI-DP2 |
| Supersedes | none |

## Context

Problem 1 deploys to EKS through GitOps with Argo CD, so a pushed image or a changed manifest is the shortest path from a supply chain compromise to production. Problem 4 attests build provenance for its EC2 and S3 artifacts, which does not cover EKS images. The Kyverno 1.19 documentation read on 2026-11-04 says `verifyImages` checks keyless signatures against an issuer and a subject, rewrites tags to digests by default, and fails the request when no matching signature exists. The Sigstore security model says the OIDC identity goes into a short-lived certificate, and every certificate goes into a public transparency log.

## Decision

CI builds images and signs them keyless with Sigstore under the build workflow's identity. Kyverno `verifyImages` admits only digest references signed by that identity, production namespaces fail closed, and an emergency exception is a time-limited policy exception approved by two people.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| Signing with a long-lived key pair in KMS | Nothing goes to a public log | A key to protect and rotate, and any principal allowed to use it can sign | Keyless binds each signature to one workflow on one ref |
| Registry scanning and tag immutability only | No admission changes | Proves nothing about who built the image | Fails TH-16 |
| Trust the GitOps repository and skip admission | Simplest | A direct push to the registry or to the cluster bypasses review | Leaves TB6 open |

## Trade-offs

The public transparency log reveals the repository and workflow names that sign images, which gives up some metadata privacy (SEC-DP6). Fail-closed admission can block an emergency fix, and the two-person exception covers that case. Deploys take a few seconds longer.

## Consequences

### Positive

- Only images from the approved workflow run in production.

### Negative

- Signing depends on the Sigstore services at build time.

### Risks

- A compromised build workflow signs a malicious image. The identity is pinned to one workflow path on the main branch, and changes to that workflow need review.

## Verification

Cloud run: admission denial tests for an unsigned image and for an image signed by another workflow.

## Reopen when

The signing identity in the public log is judged sensitive, which points to a private Sigstore deployment, or a policy exception is used outside a declared incident.
