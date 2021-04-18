#!/bin/bash
#
# Extract meta information from Docker and yml files and create an item in DynamoDB.

CURPWD=$(pwd)

#cd code-esb-ces-led-trackingevent

VERSION=1.0.0
TIMESTAMP=`date +"%Y%m%d%H%M%S"`
DOCKERFILE="Dockerfile"
COMPONENTYML="esb-ces-led-trackingevent.yml"
PLUGINS=""
TEMPLATES=""
SHAREDMODULES=""

if [ -f $DOCKERFILE ]; then
    BASEIMAGE=$(grep 'FROM.*component' Dockerfile | sed -E 's/.*(esb-bwcebase.*) as component/\1/' | sed 's/\r$//')
else
    BASEIMAGE="N/A"
fi

if [ -f $COMPONENTYML ]; then
    plugin_length=$(cat $COMPONENTYML | yq -r ' .SharedResources | length')
    if (( $plugin_length > 0 )); then
        PLUGINS=$(cat $COMPONENTYML | yq -r '.SharedResources | to_entries | .[] | select (.value == true) | .key')
    fi
    template_length=$(cat $COMPONENTYML | yq -r '.Component.Processes | length')
    if (( $template_length > 0 )); then
        TEMPLATES=$(cat $COMPONENTYML | yq -r '.Component.Processes | to_entries | map( {"S": .key} )')
    fi
    sharedmodules_length=$(cat $COMPONENTYML | yq -r '.Component.Processes | length')
    if (( $sharedmodules_length > 0 )); then
        SHAREDMODULES=$(cat $COMPONENTYML | yq -r '[.SharedModules | to_entries[] | .value = .value.Version ] | map( {"S": (.key + "_V"+ .value)} )')
    fi
else
    TEMPLATES="N/A"
    PLUGINS="N/A"
    SHAREDMODULES="N/A"
fi

jq -n \
    --arg cm "esb-ces-led-trackingevent" \
    --arg vs "$VERSION" \
    --arg bi "$BASEIMAGE" \
    --arg tp "$TEMPLATES" \
    --arg pl "$PLUGINS" \
    --arg sm "$SHAREDMODULES" \
    --arg dt "$TIMESTAMP" \
    '{ component: {S: $cm}, version: {S: $vs}, baseimage: {S: $bi}, templates: {L: $tp}, plugins: {L: $pl}, sharedmodules: {L: $sm}, timestamp: {S: $dt}}' > $CURPWD/input.json

exit 1

# Getting creds (TST)
echo "Assuming role to TST env"
tmp_role=$(echo cc-flow-esb-ces-led-trackingevent-acc | cut -c1-60)
export temp_credentials=$(aws sts assume-role --role-arn {{ aws_test_env_role }} --role-session-name $tmp_role)
export AWS_ACCESS_KEY_ID=$(echo ${temp_credentials} | jq -r '.Credentials.AccessKeyId')
export AWS_SESSION_TOKEN=$(echo ${temp_credentials} | jq -r '.Credentials.SessionToken')
export AWS_SECRET_ACCESS_KEY=$(echo ${temp_credentials} | jq -r ' .Credentials.SecretAccessKey')
export AWS_DEFAULT_REGION={{default_aws_region}}
eval "$(aws ecr get-login --no-include-email)" >/dev/null

# check if table exists in aws, create if not
if aws dynamodb list-tables | grep "pnlt-esb-custom-componentdata"; then
    echo "Table found, sending component data to database on tst"
    aws dynamodb put-item \
        --table-name pnlt-esb-custom-componentdata \
        --item file://$CURPWD/input.json
else
    echo "Table not found, creating table"
    aws dynamodb create-table \
        --table-name pnlt-esb-custom-componentdata \
        --attribute-definitions AttributeName=component,AttributeType=S AttributeName=version,AttributeType=S \
        --key-schema AttributeName=component,KeyType=HASH AttributeName=version,KeyType=RANGE \
        --billing-mode PAY_PER_REQUEST
    echo "Waiting for table to be created"
    aws dynamodb wait table-exists \
        --table-name pnlt-esb-custom-componentdata
    echo "Sending component data to database on tst"
    aws dynamodb put-item \
        --table-name pnlt-esb-custom-componentdata \
        --item file://$CURPWD/input.json
fi

# Getting creds (ACC/PRD)
echo "Assuming role to SERVICES env"
unset AWS_ACCESS_KEY_ID
unset AWS_SESSION_TOKEN
tmp_role=$(echo cc-flow-esb-ces-led-trackingevent-acc | cut -c1-60)
export temp_credentials=$(aws sts assume-role --role-arn {{ aws_services_env_role }} --role-session-name $tmp_role)
export AWS_ACCESS_KEY_ID=$(echo ${temp_credentials} | jq -r '.Credentials.AccessKeyId')
export AWS_SESSION_TOKEN=$(echo ${temp_credentials} | jq -r '.Credentials.SessionToken')
export AWS_SECRET_ACCESS_KEY=$(echo ${temp_credentials} | jq -r ' .Credentials.SecretAccessKey')
export AWS_DEFAULT_REGION={{default_aws_region}}
eval "$(aws ecr get-login --no-include-email)" >/dev/null

# check if table exists in aws, create if not
if aws dynamodb list-tables | grep "pnla-esb-custom-componentdata"; then
    echo "Table found, sending component data to database on acc"
    aws dynamodb put-item \
        --table-name pnla-esb-custom-componentdata \
        --item file://$CURPWD/input.json
else
    echo "Table not found, creating table"
    aws dynamodb create-table \
        --table-name pnla-esb-custom-componentdata \
        --attribute-definitions AttributeName=component,AttributeType=S AttributeName=version,AttributeType=S \
        --key-schema AttributeName=component,KeyType=HASH AttributeName=version,KeyType=RANGE \
        --billing-mode PAY_PER_REQUEST
    echo "Waiting for table to be created"
    aws dynamodb wait table-exists \
        --table-name pnla-esb-custom-componentdata
    echo "Sending component data to database on acc"
    aws dynamodb put-item \
        --table-name pnla-esb-custom-componentdata \
        --item file://$CURPWD/input.json
fi

# check if table exists in aws, create if not
if aws dynamodb list-tables | grep "pnlp-esb-custom-componentdata"; then
    echo "Table found, sending component data to database on prd"
    aws dynamodb put-item \
        --table-name pnlp-esb-custom-componentdata \
        --item file://$CURPWD/input.json
else
    echo "Table not found, creating table"
    aws dynamodb create-table \
        --table-name pnlp-esb-custom-componentdata \
        --attribute-definitions AttributeName=component,AttributeType=S AttributeName=version,AttributeType=S \
        --key-schema AttributeName=component,KeyType=HASH AttributeName=version,KeyType=RANGE \
        --billing-mode PAY_PER_REQUEST
    echo "Waiting for table to be created"
    aws dynamodb wait table-exists \
        --table-name pnlp-esb-custom-componentdata
    echo "Sending component data to database on prd"
    aws dynamodb put-item \
        --table-name pnlp-esb-custom-componentdata \
        --item file://$CURPWD/input.json
fi
