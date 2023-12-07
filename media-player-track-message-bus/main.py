import hashlib
import json
from os import getenv

import boto3
import dbus
import requests
from botocore.exceptions import ClientError
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

DBusGMainLoop(set_as_default=True)


class PlayerManager:

    def __init__(self):
        self.api_gateway_endpoint = getenv('API_GW_ENDPOINT')
        self.api_creation_path = '/create'
        self.s3 = boto3.client('s3')
        loop = GLib.MainLoop()
        bus = dbus.SessionBus()
        bus.add_signal_receiver(handler_function=self.handler,
                                signal_name='PropertiesChanged', bus_name='org.mpris.MediaPlayer2.strawberry')
        loop.run()

    def handler(self, interface, changed_props, invalidated_props):
        if 'Metadata' in changed_props and 'mpris:artUrl' in changed_props['Metadata']:
            title = changed_props['Metadata']['xesam:title']
            album = changed_props['Metadata']['xesam:album']
            artist = changed_props['Metadata']['xesam:artist'][0]
            track_number = changed_props['Metadata']['xesam:trackNumber']
            art_url = changed_props['Metadata']['mpris:artUrl']
            hashed = self.normalize_and_encrypt_string(artist + album)
            if not self.check_file_exists("duberton-fm-album-covers", hashed):
                self.upload_file(art_url.replace("file://", ""), "duberton-fm-album-covers", hashed)
            self.send_song(artist, album, title, hashed)

    def send_song(self, artist, album, title, hashed):
        print(f'{artist} - {title}, {album}, {hashed}')
        payload = {'artist': artist, 'album': album, 'title': title, 'hash': hashed}

        payload_json = json.dumps(payload)

        headers = {'Content-Type': 'application/json'}

        response = requests.post(f'{self.api_gateway_endpoint}{self.api_creation_path}', data=payload_json,
                                 headers=headers)
        print(f'Response status code: {response.status_code}')

    @staticmethod
    def normalize_and_encrypt_string(input_string):
        normalized_string = input_string.lower().strip()
        sha256_hash = hashlib.sha256(normalized_string.encode()).hexdigest()
        return sha256_hash

    def check_file_exists(self, bucket_name, s3_file_key):
        try:
            self.s3.head_object(Bucket=bucket_name, Key=s3_file_key)
            print(f"File '{s3_file_key}' exists in the S3 bucket '{bucket_name}'.")
            return True
        except ClientError as e:
            if e.response['Error']['Code'] == '404':
                print(f"File '{s3_file_key}' does not exist in S3 bucket '{bucket_name}'.")
                return False
            else:
                print(f"Error checking file existence: {e}")
                return False

    def upload_file(self, local_file, bucket_name, s3_file_key):
        print(f'Uploading file {local_file}')
        self.s3.upload_file(local_file, bucket_name, s3_file_key)


if __name__ == '__main__':
    boto3.setup_default_session(
        aws_access_key_id=getenv('AWS_ACCESS_KEY_ID'),
        aws_secret_access_key=getenv('AWS_SECRET_ACCESS_KEY')
    )

    print('We are up. We are running!')
    manager = PlayerManager()
