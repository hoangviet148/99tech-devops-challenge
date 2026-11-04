#!/usr/bin/env bash
set -euo pipefail

TERRAFORM_IMAGE="hashicorp/terraform:1.16.6@sha256:bfffc1ded5fbf0a17beaaf22eb4793980abdb19d0761ff6a3a0efb2ab4d9b316"
TFLINT_IMAGE="ghcr.io/terraform-linters/tflint:v0.61.0@sha256:b835d64d66abfdbc146694b918eb3cd733ec772465ad511464d4e8bebbdd6732"
TRIVY_IMAGE="aquasec/trivy:0.76.1@sha256:790fd66d1697395d8693d1acaa1ea702406a20f109b6fc7bac8db623eca6c06c"
ACCEPTED_FINDINGS="AWS-0053|modules/backend/main.tf|public API called by browsers
AWS-0132|modules/delivery/main.tf|SSE-S3, cross-account readers hold no KMS grant
AWS-0011|modules/frontend/cdn.tf|static files only, private origin behind OAC
AWS-0132|modules/frontend/main.tf|SSE-S3, no KMS grant for OAC or deploy roles"
ENDPOINTS_WITHOUT_POLICY="ssmmessages|endpoint policy support is not confirmed without an account
codedeploy|endpoint policy support is not confirmed without an account
codedeploy-commands-secure|endpoint policy support is not confirmed without an account"
EXTERNAL_ROLES="retention-admin|deletes in the delivery buckets, created outside this folder
frontend-asset-cleanup|the cleanup job that SOLUTION.md section 7 leaves out"

usage() {
  cat >&2 <<'EOF'
Usage: bash scripts/terraform-check.sh [--update-lock]

Checks infra/terraform without AWS: version pins, fmt, the policy tests, init against the committed lock
files, validate, an offline plan of the delivery root and of the environment root per tfvars file, every
policy document in those plans against its source in infra/policies, the ARNs the documents name against
the planned resources, the user data, tflint, and trivy against ACCEPTED_FINDINGS. --update-lock rewrites
both .terraform.lock.hcl files with the hashes of linux_amd64 and linux_arm64 instead of verifying them.
Exit codes: 0 every step passed, 1 a step failed or a host tool is missing, 2 wrong arguments.
EOF
}

update_lock=0
if [ "$#" -gt 1 ]; then
  usage
  exit 2
fi
if [ "$#" -eq 1 ]; then
  case "$1" in
    --update-lock) update_lock=1 ;;
    *) usage; exit 2 ;;
  esac
fi

for tool in docker jq shellcheck python3; do
  command -v "$tool" > /dev/null 2>&1 || { echo "terraform-check: $tool is required" >&2; exit 1; }
done
[ "$(jq -nr '"b2s=" | @base64d' 2> /dev/null)" = "ok" ] || { echo "terraform-check: jq 1.6 or later is required" >&2; exit 1; }
docker info > /dev/null 2>&1 || { echo "terraform-check: a running docker daemon is required" >&2; exit 1; }

root="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/plugins" "$work/data/delivery" "$work/data/environment"
: > "$work/results"

detail=""
initialized=""
planned=""

tf() {
  local data="$1" network="$2" mode="$3"
  shift 3
  docker run --rm --network "$network" --user "$(id -u):$(id -g)" \
    -e HOME=/work -e CHECKPOINT_DISABLE=1 -e TF_IN_AUTOMATION=1 -e TF_INPUT=0 \
    -e TF_PLUGIN_CACHE_DIR=/work/plugins -e "TF_DATA_DIR=/work/data/$data" -e AWS_EC2_METADATA_DISABLED=true \
    -v "$root:/src:$mode" -v "$work:/work" "$TERRAFORM_IMAGE" "$@"
}

# set -e is off inside functions called from an if, so every step function ends each command with || return 1
step() {
  local label="$1" status
  shift
  detail=""
  echo "== $label"
  if "$@"; then status=PASS; else status=FAIL; fi
  printf '%s|%s|%s\n' "$label" "$status" "$detail" >> "$work/results"
}

check_pins() {
  local dir rel file count=0 problems=0
  for dir in "$root"/infra/terraform/modules/* "$root"/infra/terraform/roots/*; do
    [ -d "$dir" ] || continue
    rel="${dir#"$root"/}"
    count=$((count + 1))
    if [ ! -f "$dir/versions.tf" ]; then
      echo "$rel has no versions.tf"
      problems=$((problems + 1))
      continue
    fi
    if ! grep -Eq '^[[:space:]]*required_version[[:space:]]*=[[:space:]]*"1\.16\.6"' "$dir/versions.tf"; then
      echo "$rel/versions.tf does not pin Terraform 1.16.6"
      problems=$((problems + 1))
    fi
    if ! grep -Eq '^[[:space:]]*version[[:space:]]*=[[:space:]]*"6\.69\.1"' "$dir/versions.tf"; then
      echo "$rel/versions.tf does not pin hashicorp/aws 6.69.1"
      problems=$((problems + 1))
    fi
  done
  if [ "$count" -eq 0 ]; then
    detail="no module or root directory under infra/terraform"
    return 1
  fi
  grep -rl --include='*.tf' --exclude-dir=.terraform 'required_providers' "$root/infra/terraform" > "$work/providers.txt" ||
    [ "$?" -eq 1 ] || { detail="grep failed over infra/terraform"; return 1; }
  while IFS= read -r file; do
    case "$file" in
      */versions.tf) continue ;;
    esac
    echo "required_providers outside versions.tf: ${file#"$root"/}"
    problems=$((problems + 1))
  done < "$work/providers.txt"
  if [ "$problems" -gt 0 ]; then
    detail="pin problems: $problems in $count directories"
    return 1
  fi
  detail="$count versions.tf pinned"
}

check_fmt() {
  tf delivery none ro fmt -check -recursive -diff -no-color /src/infra/terraform || { detail="unformatted files, run terraform fmt -recursive"; return 1; }
  detail="canonical format"
}

init_root() {
  local name="$1"
  if [ "$update_lock" -eq 1 ]; then
    tf "$name" bridge rw "-chdir=/src/infra/terraform/roots/$name" init -backend=false -input=false -no-color || { detail="terraform init failed"; return 1; }
    # plan rejects an unpacked provider whose platform has no h1 hash in a read-only lock file
    tf "$name" bridge rw "-chdir=/src/infra/terraform/roots/$name" providers lock -no-color -platform=linux_amd64 -platform=linux_arm64 ||
      { detail="terraform providers lock failed"; return 1; }
    echo "commit infra/terraform/roots/$name/.terraform.lock.hcl"
    detail="lock file written for linux_amd64 and linux_arm64"
  else
    tf "$name" bridge ro "-chdir=/src/infra/terraform/roots/$name" init -backend=false -input=false -no-color -lockfile=readonly ||
      { detail="lock file missing or stale, rerun with --update-lock"; return 1; }
    detail="lock file verified"
  fi
  initialized="$initialized $name"
}

validate_root() {
  local name="$1"
  case " $initialized " in
    *" $name "*) ;;
    *) detail="init failed"; return 1 ;;
  esac
  tf "$name" none ro "-chdir=/src/infra/terraform/roots/$name" validate -no-color || { detail="terraform validate failed"; return 1; }
  detail="configuration valid"
}

plan_label() {
  local label="$1" name="$2" varfile="$3" adds
  case " $initialized " in
    *" $name "*) ;;
    *) detail="init failed"; return 1 ;;
  esac
  [ -f "$root/infra/terraform/common.tfvars" ] || { detail="infra/terraform/common.tfvars is missing"; return 1; }
  if [ -n "$varfile" ] && [ ! -f "$root/infra/terraform/roots/$name/$varfile" ]; then
    detail="infra/terraform/roots/$name/$varfile is missing"
    return 1
  fi
  tf "$name" none ro "-chdir=/src/infra/terraform/roots/$name" plan -input=false -lock=false -refresh=false -no-color \
    -var=offline=true -var-file=/src/infra/terraform/common.tfvars \
    ${varfile:+"-var-file=/src/infra/terraform/roots/$name/$varfile"} "-out=/work/$label.tfplan" ||
    { detail="terraform plan failed"; return 1; }
  tf "$name" none ro "-chdir=/src/infra/terraform/roots/$name" show -json "/work/$label.tfplan" > "$work/$label.json" ||
    { detail="terraform show failed"; return 1; }
  adds="$(jq '[.resource_changes[] | select(.change.actions == ["create"])] | length' < "$work/$label.json")" ||
    { detail="the plan JSON is unreadable"; return 1; }
  planned="$planned $label"
  detail="$adds to add"
}

plan_policies() {
  local args=() entry
  while IFS='|' read -r entry _; do args+=(--default-endpoint "$entry"); done <<< "$ENDPOINTS_WITHOUT_POLICY"
  while IFS='|' read -r entry _; do args+=(--external-role "$entry"); done <<< "$EXTERNAL_ROLES"
  python3 -I "$root/scripts/plan-policies.py" --policies "$root/infra/policies" "${args[@]}" "$@"
}

check_policy_tests() {
  python3 -I "$root/infra/policies/test_policies.py" > "$work/policy-tests.log" 2>&1 ||
    { cat "$work/policy-tests.log"; detail="infra/policies/test_policies.py failed"; return 1; }
  detail="$(sed -n 's/^Ran \([0-9]*\) tests.*/\1/p' "$work/policy-tests.log") tests pass"
}

check_policies() {
  local label="$1" output status=0
  case " $planned " in
    *" $label "*) ;;
    *) detail="plan failed"; return 1 ;;
  esac
  output="$(plan_policies --plan "$label=$work/$label.json")" || status=$?
  printf '%s\n' "$output"
  if [ "$status" -ne 0 ]; then
    detail="$(printf '%s\n' "$output" | grep -c '^problem') problems against infra/policies"
    return 1
  fi
  detail="$(printf '%s\n' "$output" | sed -n "s/^summary   $label: //p")"
}

check_policy_links() {
  local label output status=0 args=()
  for label in delivery staging production; do
    case " $planned " in
      *" $label "*) args+=(--plan "$label=$work/$label.json") ;;
      *) detail="plan $label failed"; return 1 ;;
    esac
  done
  printf '%s\n' "$ENDPOINTS_WITHOUT_POLICY" | awk -F'|' '{ print "accepted  endpoint " $1 " keeps the default policy: " $2 }' || return 1
  printf '%s\n' "$EXTERNAL_ROLES" | awk -F'|' '{ print "accepted  role " $1 " is not planned: " $2 }' || return 1
  output="$(plan_policies --links "${args[@]}")" || status=$?
  printf '%s\n' "$output" | grep -Ev '^(equal|deferred|accepted)|^summary   [a-z]+: [0-9]+ equal' || true
  if [ "$status" -ne 0 ]; then
    detail="$(printf '%s\n' "$output" | grep -c '^problem') problems"
    return 1
  fi
  detail="$(printf '%s\n' "$output" | sed -n 's/^summary   links: //p')"
}

check_user_data() {
  local label="$1" script
  script="$work/$label.user-data.sh"
  case " $planned " in
    *" $label "*) ;;
    *) detail="plan failed"; return 1 ;;
  esac
  jq -r '[.resource_changes[] | select(.type == "aws_launch_template") | .change.after.user_data]
    | if length == 1 and .[0] != null then .[0] | @base64d else error("user data is not known at plan time") end' \
    < "$work/$label.json" > "$script" || { detail="user data is not known at plan time"; return 1; }
  shellcheck -s bash - < "$script" || { detail="shellcheck findings in the rendered user data"; return 1; }
  detail="$(wc -l < "$script" | tr -d ' ') lines, shellcheck clean"
}

check_tflint() {
  docker run --rm --network none -v "$root:/src:ro" -w /src/infra/terraform "$TFLINT_IMAGE" \
    --recursive --config /src/infra/terraform/.tflint.hcl --format compact || { detail="tflint findings"; return 1; }
  detail="no finding"
}

trivy_config() {
  local tree="$1"
  shift
  docker run --rm --network none -e TRIVY_NO_PROGRESS=true -v "$root:/src:ro" -v "$tree:/src/infra/terraform:ro" \
    "$TRIVY_IMAGE" config --skip-check-update --quiet --severity HIGH,CRITICAL "$@" /src/infra/terraform
}

copy_without_ignores() {
  local dest="$1" file
  (cd "$root/infra/terraform" && find . -name .terraform -prune -o -type f -print) > "$work/tf-files.txt" || return 1
  while IFS= read -r file; do
    mkdir -p "$(dirname "$dest/$file")" || return 1
    case "$file" in
      *.tf) sed '/^[[:space:]]*#trivy:ignore:/d' "$root/infra/terraform/$file" > "$dest/$file" || return 1 ;;
      *) cp "$root/infra/terraform/$file" "$dest/$file" || return 1 ;;
    esac
  done < "$work/tf-files.txt"
}

check_trivy() {
  local problems count
  trivy_config "$root/infra/terraform" --exit-code 1 || { detail="HIGH or CRITICAL misconfiguration"; return 1; }
  copy_without_ignores "$work/unsuppressed" || { detail="could not copy infra/terraform"; return 1; }
  trivy_config "$work/unsuppressed" --format json > "$work/trivy.json" || { detail="trivy failed without the inline ignores"; return 1; }
  jq -r '.Results[]? | .Target as $t | .Misconfigurations[]? | select(.Status == "FAIL") | "\(.ID) in \($t)"' \
    < "$work/trivy.json" | LC_ALL=C sort -u > "$work/fired.txt" || { detail="the trivy JSON is unreadable"; return 1; }
  (cd "$root/infra/terraform" && grep -rHo --include='*.tf' --exclude-dir=.terraform '#trivy:ignore:[A-Z0-9-]*' .) \
    > "$work/ignore-lines.txt" || [ "$?" -eq 1 ] || { detail="grep failed over infra/terraform"; return 1; }
  awk -F':#trivy:ignore:' '{ sub(/^\.\//, "", $1); print $2 " in " $1 }' "$work/ignore-lines.txt" |
    LC_ALL=C sort -u > "$work/ignored.txt" || return 1
  printf '%s\n' "$ACCEPTED_FINDINGS" | awk -F'|' '{ print $1 " in " $2 }' | LC_ALL=C sort -u > "$work/accepted.txt" || return 1
  printf '%s\n' "$ACCEPTED_FINDINGS" | awk -F'|' '{ print "accepted  " $1 " in " $2 ": " $3 }' || return 1
  problems="$(
    LC_ALL=C comm -23 "$work/fired.txt" "$work/accepted.txt" | sed 's/^/fires without the ignore lines and is not accepted: /'
    LC_ALL=C comm -13 "$work/fired.txt" "$work/accepted.txt" | sed 's/^/accepted but no longer fires: /'
    LC_ALL=C comm -23 "$work/ignored.txt" "$work/accepted.txt" | sed 's/^/ignore line without an accepted finding: /'
  )" || return 1
  count="$(wc -l < "$work/accepted.txt" | tr -d ' ')"
  if [ -n "$problems" ]; then
    echo "$problems"
    detail="accepted findings out of date: $(printf '%s\n' "$problems" | wc -l | tr -d ' ')"
    return 1
  fi
  detail="no HIGH or CRITICAL misconfiguration, $count accepted"
}

step pins check_pins
step fmt check_fmt
step "policy tests" check_policy_tests
for name in delivery environment; do
  step "init $name" init_root "$name"
  step "validate $name" validate_root "$name"
done
for entry in "delivery:delivery:" "staging:environment:staging.tfvars" "production:environment:production.tfvars"; do
  IFS=: read -r label rootname varfile <<< "$entry"
  step "plan $label" plan_label "$label" "$rootname" "$varfile"
  step "policies $label" check_policies "$label"
  if [ "$rootname" = environment ]; then
    step "user-data $label" check_user_data "$label"
  fi
done
step "policy links" check_policy_links
step tflint check_tflint
step trivy check_trivy

echo "== summary"
passed=0
failed=0
while IFS='|' read -r label status note; do
  printf '%-22s %-4s %s\n' "$label" "$status" "$note"
  if [ "$status" = PASS ]; then passed=$((passed + 1)); else failed=$((failed + 1)); fi
done < "$work/results"
echo "terraform-check: $passed passed, $failed failed"
[ "$failed" -eq 0 ] || exit 1
