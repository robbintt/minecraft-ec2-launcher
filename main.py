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


# common solution from: https://stackoverflow.com/a/22238613
from datetime import date, datetime
def json_serial(obj):
    """JSON serializer for objects not serializable by default json code"""

    if isinstance(obj, (datetime, date)):
        return obj.isoformat()
    raise TypeError ("Type %s not serializable" % type(obj))


def start_ec2_instance(instance_ids, addl_info='', dry_run=True):
    ''' Start the ec2 instance

    Consider polling the instance to see its state.

    documentation: 
        - https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/ec2.html#EC2.Client.start_instances
    '''

    start_response = client.start_instances(
            InstanceIds=instance_ids,
            AdditionalInfo=addl_info,
            DryRun=dry_run
            )

    # might move this to a separate section of the route
    # especially if i call describe before start and use a condition to start
    # i could also include a stop function since that is faster
    #   removes a roadblock
    # can dispatch a an email with SNS if it's running for more than a day
    # would still be nice to get a user count somehow before stopping
    # the instance does tell the minecraft client user count so maybe it has an api...
    # the api would have to be at the game port though.... ... hmmm...
    describe_response = client.describe_instances(
            InstanceIds=instance_ids,
            DryRun=dry_run
            )

    response = [start_response, describe_response]

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

    return json.dumps(response, default=json_serial)


if __name__ == '__main__':
    app.run(debug=True)
