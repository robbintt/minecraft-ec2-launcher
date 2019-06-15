''' Flask service to provide webpage

consider async await with flask -- no idea about support...
'''
import json
from flask import Flask, jsonify
import boto3
import aws_secrets

app = Flask(__name__)

client = boto3.client(
    'ec2',
    aws_access_key_id=aws_secrets.aws_access_key_id,
    aws_secret_access_key=aws_secrets.aws_secret_access_key,
    region_name=aws_secrets.region_name)

minecraft_instance_ids = [aws_secrets.instance_id]


def start_ec2_instance(instance_ids, addl_info='', dry_run=True):
    ''' Start the ec2 instance

    Consider polling the instance to see its state.

    documentation: 
        - https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/ec2.html#EC2.Client.start_instances
    '''

    response = client.start_instances(
            InstanceIds=instance_ids,
            AdditionalInfo=addl_info,
            DryRun=dry_run
            )

    return response


@app.route('/start/', methods=["GET", "POST"])
def start_webpage():
    ''' start the ec2 instance on page load
    this probably needs some sort of authentication
    otherwise any bots that hit the URL will load it

    i could just use the endpoint as validation, e.g. put a UUID in the route

    then i could even rotate UUIDs if there's an issue
    '''
    
    response = start_ec2_instance(minecraft_instance_ids, dry_run=False)

    return json.dumps(response)


if __name__ == '__main__':
    app.run(debug=True)
