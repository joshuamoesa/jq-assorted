#!/bin/bash
#
# Extract meta information from Docker and yml files and per environment create an item in the environment bound DynamoDB table.

CURPWD=$(pwd)
#cd code-esb-ces-led-trackingevent

VERSION=1.0.0
TIMESTAMP=`date -u +"%Y-%m-%dT%H:%M:%SZ"` 
DOCKERFILE="Dockerfile"
COMPONENTNAME="esb-ces-led-trackingevent"
COMPONENTYMLFILE="esb-ces-led-trackingevent.yml"
# TODO hieronder gebruiken: {{ aws_test_env_role }}
AWSTESTENVROLE="bla"
AWSDDBSTATEMENT=""
PLUGINS="[ { \"S\" : \"N/A\" } ]"
SHAREDMODULES="[ { \"S\" : \"N/A\" } ]"
TEMPLATES="[ { \"S\" : \"N/A\" } ]"

prepare_statement () {
    echo "Creating statement..."
    if [ -f $DOCKERFILE ];
    then
        BASEIMAGE=$(grep 'FROM.*component' Dockerfile | sed -E 's/.*(esb-bwcebase.*) as component/\1/' | sed 's/\r$//')
    else
        BASEIMAGE="N/A"
    fi
    if [ -f $COMPONENTYMLFILE ];
    then
        pluginlist_length=$(cat $COMPONENTYMLFILE | yq -r ' .SharedResources | length')
        if (( $pluginlist_length > 0 ));
        then
            pluginlist_enabled=$(cat $COMPONENTYMLFILE | yq -r '[.SharedResources | to_entries[] | select(.value == true)] | map( {"S": (.key)} )')
            if ! [ -z "$pluginlist_enabled" ] && [ ${#pluginlist_enabled} -gt 2 ]; 
            then
                PLUGINS=$pluginlist_enabled
            fi
        fi
        templatelist_length=$(cat $COMPONENTYMLFILE | yq -r '.Component.Processes | length')
        if (( $templatelist_length > 0 ));
        then
            templatelist=$(cat $COMPONENTYMLFILE | yq -r '.Component.Processes | to_entries | map( {"S": .key} )')
            if ! [ -z "$templatelist" ]
            then
                TEMPLATES=$templatelist
            fi
        fi
        sharedmoduleslist_length=$(cat $COMPONENTYMLFILE | yq -r '.SharedModules | length')
        if (( $sharedmoduleslist_length > 0 ));
        then
            sharedmoduleslist=$(cat $COMPONENTYMLFILE | yq -r '[.SharedModules | to_entries[] | .value = .value.Version ] | map( {"S": (.key + "_V"+ .value)} )')
            if ! [ -z "$sharedmoduleslist" ]
            then
                SHAREDMODULES=$sharedmoduleslist
            fi
        fi
    fi
    AWSDDBSTATEMENT=$(jq -n \
        --arg cm "$COMPONENTNAME" \
        --arg vs "$VERSION" \
        --arg bi "$BASEIMAGE" \
        --argjson tp "$TEMPLATES" \
        --argjson pl "$PLUGINS" \
        --argjson sm "$SHAREDMODULES" \
        --arg dt "$TIMESTAMP" \
        '{ component: {S: $cm}, version: {S: $vs}, baseimage: {S: $bi}, templates: {L: $tp}, plugins: {L: $pl}, sharedmodules: {L: $sm}, datetime: {S: $dt}}')    
    echo "Done"
}

get_aws_credentials () {
    echo "Assuming role to $1"

    unset TMP_ROLE_SESSION_NAME \
            TEMP_CREDENTIALS \
            AWS_ACCESS_KEY_ID \
            AWS_SESSION_TOKEN \
            AWS_SECRET_ACCESS_KEY \
            AWS_DEFAULT_REGION

    TMP_ROLE_SESSION_NAME=$(echo cc-flow-{{_comp.name}}-acc | cut -c1-60)

    export TEMP_CREDENTIALS=$(aws sts assume-role --role-arn arn:aws:iam::$1:role/$2-concourse-ci-operations --role-session-name $TMP_ROLE_SESSION_NAME)
    export AWS_ACCESS_KEY_ID=$(echo ${TEMP_CREDENTIALS} | jq -r '.Credentials.AccessKeyId')
    export AWS_SESSION_TOKEN=$(echo ${TEMP_CREDENTIALS} | jq -r '.Credentials.SessionToken')
    export AWS_SECRET_ACCESS_KEY=$(echo ${TEMP_CREDENTIALS} | jq -r ' .Credentials.SecretAccessKey')
    export AWS_DEFAULT_REGION={{ default_aws_region }}
    }

put_item () {
    # Determine prefix based on argument
    if [[ $1 = tst ]]
    then
        AWSECSENVPREFIX="pnlt"
    elif [[ $1 = acc ]]
    then
        AWSECSENVPREFIX="pnla"
    elif [[ $1 = prd ]]
    then
        AWSECSENVPREFIX="pnlp"
    fi

    TABLE=$AWSECSENVPREFIX"-esb-images"
    echo "Putting item in table" $TABLE
    if aws dynamodb list-tables | grep "$TABLE";
    then
        aws dynamodb put-item \
            --table-name $TABLE \
            --item "$AWSDDBSTATEMENT"
    else
        aws dynamodb create-table \
            --table-name $TABLE \
            --attribute-definitions AttributeName=component,AttributeType=S AttributeName=version,AttributeType=S \
            --key-schema AttributeName=component,KeyType=HASH AttributeName=version,KeyType=RANGE \
            --billing-mode PAY_PER_REQUEST
        aws dynamodb wait table-exists \ # Waiting for table to be created
            --table-name $TABLE
        aws dynamodb put-item \
            --table-name $TABLE \
            --item $AWSDDBSTATEMENT
    fi
    echo "Done"
}
prepare_statement
#get_aws_credentials {{ test_accountnr }} pnlt
put_item tst
#get_aws_credentials {{ services_accountnr }} pnlap
#put_item "acceptance"
#put_item "production"