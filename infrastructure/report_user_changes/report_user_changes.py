''' Report changes in user status to SNS

This module is intended to be run on cron every minute.
'''
from mcstatus import MinecraftServer
import boto3
import json
import datetime
import pytz

def get_players(server_ip, server_port="25565"):
    """ Format this information to be consumed in a template
    """
    server = MinecraftServer.lookup(f"{server_ip}:{server_port}")
    status = server.status()

    #server_info["playercount"] = status.players.online
    #server_info["latency"] = status.latency

    if status.players.sample is not None:
        player_names = [player.name for player in status.players.sample]
    else:
        player_names = []

    return player_names

def main():
    ''' Report any change in cached players to SNS

    This is intended to update every second on cron.
    NB: debounce should be used in the SNS notifier to avoid excess messages.

    TODO: optional local json map to attach realnames to usernames in message content
    '''
    server_ip = '0.0.0.0'
    last_players_file = 'last_players_online.dat'
    aws_region = 'us-east-1'
    sns_arn = 'arn:aws:sns:us-east-1:705280753284:minecraft_user_connection_events'
    now = datetime.datetime.now()
    now_subj = now.astimezone(pytz.timezone('US/Eastern')).strftime('%I:%M %p').lstrip('0')

    try:
        with open(last_players_file, 'r') as f:
            last_player_names = json.load(f)
    except FileNotFoundError:
        last_player_names = []

    player_names = get_players(server_ip)

    with open(last_players_file, 'w') as f:
        json.dump(player_names, f)

    just_logged_in = set(player_names) - set(last_player_names)
    just_logged_out = set(last_player_names) - set(player_names)

    messages = []
    for player in just_logged_in:
        messages.append({'text': f"Cincicraft: {player} joined @ {now_subj}"})
    for player in just_logged_out:
        messages.append({'text': f"Cincicraft: {player} left @ {now_subj}"})

    client = boto3.client('sns', region_name=aws_region)
    for message in messages:
        response = client.publish(
            TargetArn=sns_arn,
            Subject=message['text'],
            Message=json.dumps(message))
        print(response)

if __name__ == '__main__':
    main()
