# yml-dockerfile-parsing

Parse Dockerfile and ymlfile and put item in a AWS DynamoDB table.

## Example DynamoDB input data

```
{
    "component": {
        "S": "esb-ces-led-trackingevent"
    },
    "version": {
        "S": "1.0.0"
    },
    "baseimage": {
        "S": "esb-bwcebase:2.5.4.4"
    },
    "templates": {
        "L": "[ { S: SubscribeToEsbFtlMessageStore_V2.1.0 }, { S: ParseMap_V2.0.0 }, { S: SQSRequest_V1.1.0 }, { S: ActivatorProcess_V1.0.0 }]"
    },
    "plugins": {
        "L": "[ { S: sqs }, { S: jms }]"
    },
    "sharedmodules": {
        "L": "[ { S: Logging_V2.0.1 }, { S: Messagebroker_V1.0.6 }, { S: Messagestore_V1.8.4 }, { S: Monitoring_V1.2.0 }]"
    },
    "datetime": {
        "S": "2021-04-19T13:47:52Z"
    }
}
```

## References

- AWS DynamoDB Tutorial | AWS Services | AWS Tutorial For Beginners | AWS Training Video | Simplilearn https://www.youtube.com/watch?v=2mVR_Qgx_RU
- DynamoDB Advanced Queries: A Cheat Sheet https://www.bmc.com/blogs/dynamodb-advanced-queries/