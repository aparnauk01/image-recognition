import io
import boto3
from PIL import Image, ImageDraw, ImageFont
def lambda_handler(event, context):
    result = "Hello World"
    print(result)
    client = boto3.client('rekognition',region_name='us-east-1')
    object_name = event['Records'][0]['s3']['object']['key']
    print(f"Image ename is {object_name}")
    bucket_name = event['Records'][0]['s3']['bucket']['name']
    print(f"Image ename is {bucket_name}")
    print(type(bucket_name))
    print(type(object_name))
    
    s3client = boto3.client('s3')
    cur_image = s3client.get_object(Bucket=bucket_name, Key = object_name)['Body'].read()
    loaded_image = Image.open(io.BytesIO(cur_image))
    draw = ImageDraw.Draw(loaded_image)
    response = client.detect_labels(
    Image={'S3Object': {
            'Bucket': bucket_name,
            'Name': object_name
        }
    }
)
    print(response)
    for label in response['Labels']:
        print(f"Instance: {label['Name']}")
        for instances in label['Instances']:
            if instances['BoundingBox']:
                print(f"instance: {instances['BoundingBox']['Width']}")
                box = instances['BoundingBox']
                left = image.width * box["left"]
                top = image.height * box["top"]
                width = image.width * box["width"]
                height = image.height * box["height"]





    return {
        'statusCode' : 200,
        'body': result
    }