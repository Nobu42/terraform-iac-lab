import os

def lambda_handler(event, context):
    greet = os.environ['GREET']
    print(greet, ', LocalStack!')
