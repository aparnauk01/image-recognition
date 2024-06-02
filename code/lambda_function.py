import boto3
def lambda_handler(event, context):
    result = "Hello World"
    print(result)
    client = boto3.client('rekognition',region_name='us-east-1')
    object_name = event['Records'][0]['s3']['object']['key']
    print(f"Image ename is {object_name}")
    bucket_name = event['Records'][0]['s3']['bucket']['name']
    print(f"Image ename is {bucket_name}")
    
    # with open(object_name, 'rb') as image_file:
    #     sourcebytes =  image_file.read()

    response = client.detect_labels(
    Image={'S3Object': {
            'Bucket': bucket_name,
            'Name': object_name
        }
    }
)
    print(response)

    return {
        'statusCode' : 200,
        'body': result
    }