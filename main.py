''' Flask service to provide webpage

consider async await with flask -- no idea about support...

    # can dispatch a an email with SNS if it's running for more than a day
    # would still be nice to get a user count somehow before stopping
    # the instance does tell the minecraft client user count so maybe it has an api...
    # the api would have to be at the game port though.... ... hmmm...
'''
import json
import os
from flask import Flask, render_template, redirect, flash, url_for
import boto3
import aws_secrets
from datetime import date, datetime

app = Flask(__name__)

app.config['SECRET_KEY'] = aws_secrets.flask_secret

client = boto3.client(
    'ec2',
    aws_access_key_id=aws_secrets.aws_access_key_id,
    aws_secret_access_key=aws_secrets.aws_secret_access_key,
    region_name=aws_secrets.region_name)

def json_serial(obj):
    ''' JSON serializer for objects not serializable by default json code

    This is called in templates I think, probably better to move that logic here.

    see: https://stackoverflow.com/a/22238613
    '''
    if isinstance(obj, (datetime, date)):
        return obj.isoformat()
    raise TypeError ("Type %s not serializable" % type(obj))


def describe_ec2_instance(instance_id, dry_run=False):
    ''' Describe a single ec2 instance
    '''
    instance_details = dict()
    if not instance_id:
        return { 'public_ip': None, 'state': None, 'payload': None }

    instance_details['payload'] = client.describe_instances(InstanceIds=[instance_id], DryRun=dry_run)

    try:
        instance_details['public_ip'] = instance_details['payload']['Reservations'][0]['Instances'][0]['PublicIpAddress']
    except KeyError:
        instance_details['public_ip'] = None

    try:
        instance_details['state'] = instance_details['payload']['Reservations'][0]['Instances'][0]['State']['Name']
    except KeyError:
        instance_details['state'] = None

    return instance_details


def start_ec2_instance():
    ''' Start a new ec2 instance from the launch template
    '''
    launch_template = { 'LaunchTemplateName': aws_secrets.launch_template_name } # template should terminate on stop
    instance_id = os.environ.get('RUNNING_INSTANCE_ID')

    instance_details = None
    if instance_id:
        print("Instance id already exists: {}".format(instance_id))
        instance_details = describe_ec2_instance(instance_id)
        # reference: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-lifecycle.html
        # the only risk is that there's a player on an old server who loses their progress

    if not instance_id or not instance_details or instance_details['state'] not in ['pending', 'running', 'rebooting']:
        create_response = client.run_instances(MaxCount=1, MinCount=1, LaunchTemplate=launch_template)
        # replace the old instance ID with the new one
        os.environ['RUNNING_INSTANCE_ID'] = create_response['Instances'][0]['InstanceId']  # only 1 instance: max=1, min=1
        print("Added a new instance: {}".format(os.environ.get('RUNNING_INSTANCE_ID')))


@app.route('/start/', methods=["GET", "POST"])
def start_webpage():
    ''' start the ec2 instance on page load if one isn't already started
    '''
    start_response = start_ec2_instance()

    flash(start_response) # consume in describe template

    # add a flash message to the describe webpage
    return redirect(url_for('describe_webpage'))  # lets always use describe to show information


@app.route('/', methods=["GET"])
@app.route('/describe/', methods=["GET"])
def describe_webpage():
    ''' Get a description of the last running instance
    '''
    # TODO: should probably get all instances with the tag so I can detect if things aren't terminating...
    instance_id = os.environ.get('RUNNING_INSTANCE_ID')
    print("Describing the instance: {}".format(os.environ.get('RUNNING_INSTANCE_ID')))

    try:
        instance_details = describe_ec2_instance(instance_id, dry_run=False)
    except Exception as e:
        return 'Describe failed. Details: {}'.format(e)

    return render_template(
        'describe_details.html',
        public_ip=instance_details['public_ip'],
        state=instance_details['state'],
        response=instance_details
        )


if __name__ == '__main__':
    app.run(debug=True)
