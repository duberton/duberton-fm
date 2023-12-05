import json
from os import getenv

import dbus
import requests
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

DBusGMainLoop(set_as_default=True)


class PlayerManager:

    def __init__(self):
        self.api_gateway_endpoint = getenv('API_GW_ENDPOINT')
        self.api_creation_path = '/create'
        loop = GLib.MainLoop()
        bus = dbus.SessionBus()
        bus.add_signal_receiver(handler_function=self.handler,
                                signal_name='PropertiesChanged', bus_name='org.mpris.MediaPlayer2.strawberry')
        loop.run()

    def handler(self, interface, changed_props, invalidated_props):
        if 'Metadata' in changed_props and 'mpris:artUrl' in changed_props['Metadata']:
            title = changed_props['Metadata']['xesam:title']
            artist = changed_props['Metadata']['xesam:artist'][0]
            track_number = changed_props['Metadata']['xesam:trackNumber']
            art_url = changed_props['Metadata']['mpris:artUrl']
            print(f'{track_number}. {artist[0]} - {title}, {art_url}')
            self.send(artist, title)

    def send(self, artist, title):
        payload = {'artist': artist, 'title': title}

        payload_json = json.dumps(payload)

        headers = {'Content-Type': 'application/json', }

        response = requests.post(f'{self.api_gateway_endpoint}{self.api_creation_path}', data=payload_json,
                                 headers=headers)
        print(f'Response status code: {response.status_code}')


if __name__ == '__main__':
    manager = PlayerManager()
