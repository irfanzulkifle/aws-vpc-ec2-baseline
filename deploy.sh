#!/usr/bin/env bash
#
# Deploy the baseline CloudFormation stack.
# Usage: ./deploy.sh [environment] [param-file]
#   environment  defaults to "dev"
#   param-file   defaults to "params/dev.json" (create-stack parameter format)
#
set -euo pipefail

ENVIRONMENT="${1:-dev}"
PARAM_FILE="${2:-params/dev.json}"
STACK_NAME="${ENVIRONMENT}-vpc-ec2-baseline"

# Build parameter overrides (Key=Value ...) from the JSON param file if present.
if [[ -f "$PARAM_FILE" ]]; then
  OVERRIDES=$(python3 -c "import json,sys; d=json.load(open('$PARAM_FILE')); print(' '.join(f\"{p['ParameterKey']}={p['ParameterValue']}\" for p in d))")
else
  OVERRIDES="Environment=${ENVIRONMENT}"
fi

echo "Deploying stack '${STACK_NAME}' (environment=${ENVIRONMENT})..."

aws cloudformation deploy \
  --template-file template.yaml \
  --stack-name "${STACK_NAME}" \
  --parameter-overrides ${OVERRIDES} \
  --capabilities CAPABILITY_IAM \
  --no-fail-on-empty-changeset

echo "Done. Stack: ${STACK_NAME}"
echo "InstanceId:"
aws cloudformation describe-stacks \
  --stack-name "${STACK_NAME}" \
  --query "Stacks[0].Outputs[?OutputKey=='InstanceId'].OutputValue" \
  --output text
