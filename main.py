""" Flask service to provide webpage

consider async await with flask -- no idea about support...

    # can dispatch a an email with SNS if it's running for more than a day
    # would still be nice to get a user count somehow before stopping
    # the instance does tell the minecraft client user count so maybe it has an api...
    # the api would have to be at the game port though.... ... hmmm...
"""
import json
import os
import uuid
import logging
from flask import Flask, render_template, redirect, flash, url_for
import boto3
from datetime import date, datetime
from mcstatus import MinecraftServer

app = Flask(__name__)

app.config["SECRET_KEY"] = uuid.uuid4().__str__()
aws_region = "us-east-1"
launch_template_name = "minecraft_ec2_launcher"
launch_template_ondemand_name = "minecraft_ec2_launcher_ondemand"
MC_SSM_PARAMETER = "first_mc_instanceid"

ec2_client = boto3.client("ec2", region_name=aws_region)

ssm_client = boto3.client("ssm", region_name=aws_region)  # docs dont mention region...


def put_instanceid_ssmparam(inst_id):
    """
    https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/ssm.html#SSM.Client.put_parameter
    """
    return ssm_client.put_parameter(
        Name=MC_SSM_PARAMETER,
        Description="id of active minecraft instance",
        Type="String",
        Overwrite=True,
        Value=inst_id,
        # cannot tag because i overwrite
        # Tags=[
        #    {
        #        'Key': 'Name',
        #        'Value': 'minecraft'
        #    },
        # ],
        Tier="Standard",
    )


def get_instanceid_ssmparam():
    """
    """
    inst_id_param = ssm_client.get_parameters(
        Names=[MC_SSM_PARAMETER], WithDecryption=False
    )

    try:
        return inst_id_param["Parameters"][0]["Value"]
    except (IndexError, ValueError) as e:
        # logging.error("No SSM Parameter: {}".format(e))
        return None


def json_serial(obj):
    """ JSON serializer for objects not serializable by default json code

    This is called in templates I think, probably better to move that logic here.

    see: https://stackoverflow.com/a/22238613
    """
    if isinstance(obj, (datetime, date)):
        return obj.isoformat()
    raise TypeError("Type %s not serializable" % type(obj))


def describe_ec2_instance(instance_id, dry_run=False):
    """ Describe a single ec2 instance
    """
    instance_details = dict()
    if not instance_id:
        return {"public_ip": None, "state": None, "payload": None}

    instance_details["payload"] = ec2_client.describe_instances(
        InstanceIds=[instance_id], DryRun=dry_run
    )

    # not interested in figuring out what all can go wrong

    # untested patch
    try:
        if not instance_details["payload"]["Reservations"][0]["Instances"]:
            return {"public_ip": None, "state": None, "payload": None}
    # ehh
    except (KeyError, IndexError) as e:
        instance_details["public_ip"] = None
    except Exception:
        instance_details["public_ip"] = None

    try:
        instance_details["public_ip"] = instance_details["payload"]["Reservations"][0][
            "Instances"
        ][0]["PublicIpAddress"]
    # ehh
    except (KeyError, IndexError) as e:
        instance_details["public_ip"] = None
    except Exception:
        instance_details["public_ip"] = None

    try:
        instance_details["state"] = instance_details["payload"]["Reservations"][0][
            "Instances"
        ][0]["State"]["Name"]
    # ehh
    except (KeyError, IndexError) as e:
        instance_details["state"] = None
    except Exception:
        instance_details["public_ip"] = None

    return instance_details


def start_ec2_instance():
    """ Start a new ec2 instance from the launch template

    Any param specified ec2_client.run_instances overrides the Launch Template.
    """
    launch_template = {"LaunchTemplateName": launch_template_name}
    launch_template_ondemand = {"LaunchTemplateName": launch_template_ondemand_name}
    instance_id = get_instanceid_ssmparam()
    create_response = None  # let
    ON_DEMAND = False  # launch template currently defaults to spot market

    instance_details = None
    if instance_id:
        try:
            instance_details = describe_ec2_instance(instance_id)
            print("Instance id exists: {}".format(instance_id))
        except Exception as e:
            print("Describe failed, proceeding with start. Exception: {}".format(e))
        # reference: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-lifecycle.html

    # TODO: the duplicated nested logic here needs ironed out
    if (
        not instance_id
        or not instance_details
        or instance_details["state"] not in ["pending", "running", "rebooting"]
    ):
        try:
            logging.info(f"Attempting to run instance with default launch template.")
            create_response = ec2_client.run_instances(
                MaxCount=1, MinCount=1, LaunchTemplate=launch_template
            )
        except:
            # this should test if spot capacity is full before doing this
            ON_DEMAND = True
            logging.info("Spot instance creation failed with default launch template.")

        # Report the response in all cases
        logging.info(
            f"RunInstances default launch template response: {str(create_response)}"
        )

        if ON_DEMAND:
            # update launch template to remove spot option
            logging.info(f"Attempting to run instance with ondemand launch template.")
            try:
                create_response = ec2_client.run_instances(
                    MaxCount=1, MinCount=1, LaunchTemplate=launch_template_ondemand
                )
                # Report the response in all cases
                logging.info(
                    f"RunInstances ondemand launch template response: {str(create_response)}"
                )
            except Exception as g:
                # Report the response in all cases
                logging.info(
                    f"RunInstances ondemand launch template response: {str(create_response)}"
                )
                return

        # replace the old instance ID with the new one
        new_instance_id = create_response["Instances"][0]["InstanceId"]
        put_instanceid_ssmparam(new_instance_id)
        print("Added a new instance: {}".format(new_instance_id))


def get_mcstatus(server_ip, server_port="25565"):
    """ Format this information to be consumed in a template
    """
    server_info = dict()
    try:
        server = MinecraftServer.lookup(f"{server_ip}:{server_port}")
        status = server.status(retries=1)
        server_info["playercount"] = status.players.online
        server_info["latency"] = status.latency
        # see mcstatus cli for example
        if status.players.sample is not None:
            server_info["player_names"] = ", ".join(
                [player.name for player in status.players.sample]
            )
        # query = server.query()
        # server_info['player_names'] = query.players.names
        # ping = server.ping() same as reported in status.latency

    except Exception as e:
        print(f"Exception in get_mcstatus: {repr(e)}")
        pass

    return server_info


@app.route("/start/", methods=["GET", "POST"])
def start_webpage():
    """ start the ec2 instance on page load if one isn't already started
    """
    start_response = start_ec2_instance()

    flash(start_response)  # consume in describe template

    # add a flash message to the describe webpage
    return redirect(
        url_for("describe_webpage")
    )  # lets always use describe to show information


@app.route("/", methods=["GET"])
def describe_webpage():
    """ Get a description of the last running instance
    """
    # TODO: should probably get all instances with the tag so I can detect if things aren't terminating...
    instance_id = get_instanceid_ssmparam()
    print("Describing the instance: {}".format(instance_id))

    instance_details = {"public_ip": None, "state": None}
    try:
        instance_details = describe_ec2_instance(instance_id, dry_run=False)
    except Exception as e:
        print("Describe failed. Details: {}".format(e))

    mcstatus_info = get_mcstatus(instance_details["public_ip"])

    return render_template(
        "describe_details.html",
        public_ip=instance_details["public_ip"],
        state=instance_details["state"],
        response=instance_details,
        mcstatus_info=mcstatus_info,
    )


if __name__ == "__main__":
    app.run(debug=False)
