#!/usr/bin/env python2
#
# This script is a fork of
# http://fabian-affolter.ch/blog/mqtt-and-desktop-notifications/
# Copyright (c) 2013 Fabian Affolter <fabian at affolter-engineering.ch>
#
# Modified for my own use.
# Copyright (c) 2015 Serge van Ginderachter <serge@vanginderachter.be>
#
# Released under the MIT license.
#

import sys
import time
import datetime
import dbus
import paho.mqtt.client as paho
import socket
import os
import json

app_name = 'mqtt-notify'
mqtt_client_name = (app_name + '-' + socket.gethostname() + '-'
                    + str(os.getpid()))
broker = '127.0.0.1'
port = 1883
topic = 'weechat'
qos = 2


def timestamp():
    ts = time.time()
    return datetime.datetime.fromtimestamp(ts).strftime('%Y-%m-%d %H:%M:%S')


def on_connect(client, userdata, flags, rc):
    ''' Assign a callback for connect and disconnect '''
    if rc == 0:
        print '%s Connected successfully to %s:%s as %s' % (
                timestamp(), broker, port, mqtt_client_name)
        # Subscribe to topic 'test'
        client.subscribe(topic, qos)
        print '%s Subscribing to %s with qos %s' % (timestamp(), topic, qos)


def on_disconnect(client, userdata, rc):
    print '%s Disconnected from %s:%s as %s' % (timestamp(), broker, port, mqtt_client_name)


def on_message(client, userdata, msg):
    ''' Send a notification after a new message has arrived
        json as per weechat mqtt_notify.py script
        {
        "sender": "KirkMcDonald", "tags": "irc_privmsg,notify_message,prefix_nick_230,nick_KirkMcDonald,host_~Kirk@python/site-packages/KirkMcDonald,log1",
        "buffer": "#python", "timestamp": "1522091241", "displayed": 1, "highlight": 0, "message": "phinxy: That is strange.", "data": ""
        }

        {
        "sender": "MichaelRigart_ggl", "tags": "irc_privmsg,notify_private,prefix_nick_230,nick_MichaelRigart_ggl,host_michael@netronix.be,log1",
        "buffer": "MichaelRigart_ggl", "timestamp": "1522091293", "displayed": 1, "highlight": 0, "message": "wb", "data": "private"
        }

        {
        "sender": "gobelin", "tags": "irc_privmsg,notify_message,prefix_nick_250,nick_gobelin,host_~gobelin@minecraft.ginsys.net,log1",
        "buffer": "#ginsys", "timestamp": "1522307767", "displayed": 1, "highlight": 0, "message": "test michael@netronix.be", "data": ""
        }

        {
        "sender": "freenode:gobelin", "tags": "irc_privmsg,notify_private,prefix_nick_250,nick_gobelin,host_~gobelin@minecraft.ginsys.net,log1",
        "buffer": "highmon", "timestamp": "1522308236", "displayed": 1, "highlight": 0, "message": "[gobelin] hi", "data": "private"
        }

    '''

    message = json.loads(msg.payload)

    if (message['buffer'] != 'highmon' and
            message['displayed'] == 1 and (
            message['highlight'] == 1 or
            message['data'] == 'private' or
            'notify_private' in message['tags'])):
        summary = message['sender']
        body = '%s (%s)' % (message['message'], message['buffer'])
        print timestamp(), summary, body
        notify(summary=summary, body=body)
    #else:
    #    print timestamp(), message


def notify(summary, body):
    ''' Details: https://developer.gnome.org/notification-spec/
        http://cheesehead-techblog.blogspot.ch/2009/02/five-ways-to-make-notification-pop-up.html'''

    replaces_id = 0
    service = 'org.freedesktop.Notifications'
    path = '/org/freedesktop/Notifications'
    interface = service
    app_icon = ''
    expire_timeout = 10000
    actions = []
    hints = []

    session_bus = dbus.SessionBus()
    obj = session_bus.get_object(service, path)
    interface = dbus.Interface(obj, interface)
    interface.Notify(app_name, replaces_id, app_icon, summary, body, actions,
                     hints, expire_timeout)


def main():
    # Setup the MQTT client
    mqttclient = paho.Client(client_id=mqtt_client_name, clean_session=False)

    # Callbacks
    mqttclient.on_message = on_message
    mqttclient.on_connect = on_connect
    mqttclient.on_disconnect = on_disconnect

    # Connect
    try:
        mqttclient.connect(broker, port, 60)
    except socket.error:
        # mttclient wil keep trying to reconnect
        pass

    try:
        # Loop the client forever
        mqttclient.loop_forever()
    except KeyboardInterrupt:
        print
        mqttclient.disconnect()
        sys.exit(0)

if __name__ == '__main__':
    main()
