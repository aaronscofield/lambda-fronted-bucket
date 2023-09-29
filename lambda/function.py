import boto3

def handler(event, context):
    s3 = boto3.client('s3')
    response = s3.get_object(Bucket='lambda-fronted-bucket', Key="htmltest.html")
    data = response['Body'].read().decode('utf-8')
    return {
        "statusCode": 200,
        "body": data,
        "headers": {"Content-Type": "text/html"}
    }

    