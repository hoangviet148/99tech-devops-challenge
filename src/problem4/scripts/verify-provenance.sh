#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

usage() { echo "Usage: verify-provenance.sh --artifact FILE --repo OWNER/REPO --signer-workflow PATH [--source-ref REF]" >&2; }

artifact=""
repo=""
signer=""
ref="refs/heads/main"
while [ $# -gt 0 ]; do
  case "$1" in
    --artifact) artifact="${2:-}"; shift 2 ;;
    --repo) repo="${2:-}"; shift 2 ;;
    --signer-workflow) signer="${2:-}"; shift 2 ;;
    --source-ref) ref="${2:-}"; shift 2 ;;
    *) usage; exit 2 ;;
  esac
done
[ -f "$artifact" ] && [ -n "$repo" ] && [ -n "$signer" ] || { usage; exit 2; }

result="$(mktemp)"
trap 'rm -f "$result"' EXIT
gh attestation verify "$artifact" --repo "$repo" --signer-workflow "$repo/$signer" --source-ref "$ref" \
  --deny-self-hosted-runners --format json > "$result" || die "no valid attestation for $artifact from $repo/$signer on $ref"
jq -e --arg signer "https://github.com/$repo/$signer@$ref" --arg ref "$ref" '
  length > 0 and all(.[]; .verificationResult.signature.certificate as $c
    | $c.buildSignerURI == $signer and $c.sourceRepositoryRef == $ref and $c.runnerEnvironment == "github-hosted")
' "$result" > /dev/null || die "the attestation for $artifact was not signed by $repo/$signer on $ref from a GitHub-hosted runner"
log "provenance of $(basename "$artifact") verified: $repo/$signer on $ref"
