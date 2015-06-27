#!/usr/bin/env python
#
# Copyright (c) 2013 Fabian Affolter <fabian at affolter-engineering.ch>
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

name = 'irssi'
broker = '127.0.0.1'
port = 1883
topic = 'irssi'
qos = 2


def timestamp():
    ts = time.time()
    return datetime.datetime.fromtimestamp(ts).strftime('%Y-%m-%d %H:%M:%S')


def on_connect(client, userdata, flags, rc):
    ''' Assign a callback for connect and disconnect '''
    if rc == 0:
        print '%s Connected successfully to %s:%s' % (timestamp(), broker,
                                                      port)
    # Subscribe to topic 'test'
    client.subscribe(topic, qos)


def on_disconnect(client, userdata, rc):
    print '%s Disconnected from %s:%s' % (timestamp(), broker, port)


def on_message(client, useruserdataa, msg):
    ''' Send a notification after a new message has arrived'''
    message = msg.payload.split('\n')
    summary = message[0]
    body = '\n'.join(message[1:])
    print timestamp(), summary, body
    notify(summary=summary, body=body)


def notify(summary, body):
    ''' Details: https://developer.gnome.org/notification-spec/
        http://cheesehead-techblog.blogspot.ch/2009/02/five-ways-to-make-notification-pop-up.html'''

    app_name = name
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
    mqttclient = paho.Client(client_id='notify', clean_session=False)

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
