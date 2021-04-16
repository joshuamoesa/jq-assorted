#!/bin/bash

CURPWD=$(pwd)
VERSION=$(cat version-{{_comp.name}}/version)

cd code-{{_comp.name}}

if [ -f Dockerfile ]; then
    BASEIMAGE=$(grep 'FROM.*component' Dockerfile | sed -E 's/.*(esb-bwcebase.*) as component/\1/' | sed 's/\r$//')
else
    BASEIMAGE="N/A"
fi
if [ -f {{_comp.name}}.yml ]; then
    plugin_length=$(cat {{_comp.name}}.yml | yq -r ' .SharedResources | length')
    if (( $plugin_length > 0 )); then
        PLUGINS=$(cat {{_comp.name}}.yml | yq -r '.SharedResources | to_entries | .[] | select (.value == true) | .key')
    fi
    template_length=$(cat {{_comp.name}}.yml | yq -r '.Component.Processes | length')
    if (( $template_length > 0 )); then
        TEMPLATES=$(cat {{_comp.name}}.yml | yq -r '.Component.Processes | keys []')
    fi
else
    TEMPLATES="N/A"
    PLUGINS="N/A"
fi

# create JSON file with record for dynamodb
jq -n \
    --arg cm "{{_comp.name}}" \
    --arg vs "$VERSION" \
    --arg bi "$BASEIMAGE" \
    '{ component: {S: $cm}, version: {S: $vs}, baseimage: {S: $bi}, templates: {L: []}, plugins: {L: []} }' > $CURPWD/input.json


# check templates used in yml and add item per template to list in json file
if [[ $TEMPLATES ]]; then
    for template in $TEMPLATES
    do
        jq --arg v "$template" '.templates.L[.templates.L | length] |= . + {"S": $v}'  $CURPWD/input.json > $CURPWD/tmp.json
        mv $CURPWD/tmp.json $CURPWD/input.json
    done
else
    jq '.templates.L[.templates.L | length] |= . + {"S": "N/A"}' $CURPWD/input.json > $CURPWD/tmp.json
    mv $CURPWD/tmp.json $CURPWD/input.json
fi

# check plugins used in yml and add item per plugin to list in json file
if [[ $PLUGINS ]]; then
    for plugin in $PLUGINS
    do
        jq --arg v "$plugin" '.plugins.L[.plugins.L | length] |= . + {"S": $v}' $CURPWD/input.json > $CURPWD/tmp.json
        mv $CURPWD/tmp.json $CURPWD/input.json
    done
else
    jq '.plugins.L[.plugins.L | length] |= . + {"S": "N/A"}' $CURPWD/input.json > $CURPWD/tmp.json
    mv $CURPWD/tmp.json $CURPWD/input.json
fi

# Getting creds (TST)
echo "Assuming role to TST env"
tmp_role=$(echo cc-flow-{{_comp.name}}-acc | cut -c1-60)
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
tmp_role=$(echo cc-flow-{{_comp.name}}-acc | cut -c1-60)
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
