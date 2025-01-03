#!/usr/bin/env python3
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

import time
import datetime
import dbus
import paho.mqtt.client as paho
import socket
import os
import json
import sys

if "DEBUG" in os.environ and os.environ["DEBUG"] == "1":
    DEBUG = True
else:
    DEBUG = False

app_name = "mqtt-notify"
if DEBUG:
    mqtt_client_name = app_name + "-" + socket.gethostname() + "-" + str(os.getpid())
else:
    mqtt_client_name = app_name + "-" + socket.gethostname()
broker = "127.0.0.1"
port = 1883
topic = "weechat"
qos = 2


def timestamp(ts=None):
    if ts:
        ts = int(ts)
    else:
        ts = time.time()
    return datetime.datetime.fromtimestamp(ts).strftime("%Y-%m-%d %H:%M:%S")


def on_connect(client, userdata, flags, rc):
    """ Assign a callback for connect and disconnect """
    if rc == 0:
        msg = "%s Connected successfully to %s:%s as %s" % (
            timestamp(),  # NOQA
            broker,
            port,
            mqtt_client_name,
        )
        if DEBUG:
            print('{"message": %s}' % msg)
        else:
            print(msg)
        # Subscribe to topic 'test'
        client.subscribe(topic, qos)
    else:
        msg = "%s Failed connecting to %s:%s as %s" % (
            timestamp(),  # NOQA
            broker,
            port,
            mqtt_client_name,
        )
        if DEBUG:
            print('{"message": %s}' % msg)
        else:
            print(msg)


def on_disconnect(client, userdata, rc):
    msg = "%s Disconnected from %s:%s as %s" % (
        timestamp(),
        broker,
        port,
        mqtt_client_name,
    )
    if DEBUG:
        print('{"message": %s}' % msg)
    else:
        print(msg)


def on_message(client, userdata, msg):
    """ Send a notification after a new message has arrived
        json as per weechat mqtt_notify.py script
    """

    message = updatemsg(json.loads(msg.payload))

    blacklist_buffers = ["core.highmon", "irc.bitlbee.gmail"]
    blacklisted = message["buffer_full"] in blacklist_buffers
    displayed = message["displayed"]
    highlighted = message["highlight"]
    private = message["data"] == "private" or "notify_private" in message["tags"]

    if not blacklisted and displayed and (highlighted or private):
        message["X-notified"] = True

        summary = "%s (%s on %s)" % (
            message["sender"],
            message["buffer_short"],
            message["server"],
        )
        body = "%s\n(%s)" % (message["message"], message["local_time"])
        body1 = "%s" % (message["message"])

        # NOTIFY
        notify(summary=summary, body=body)

        if not DEBUG:
            print(message(["local_time"], summary, body1))

    if DEBUG:
        print(json.dumps(message, indent=4, sort_keys=True))
        with open("/home/serge/logs/mqtt_notify-json.log", "a") as jsonlog:
            jsonlog.write(json.dumps(message, sort_keys=True))
            jsonlog.write("\n")


def updatemsg(message):

    buffer = message["buffer_full"].split(".")
    if len(buffer) == 2:
        buffer = [buffer[0], "", buffer[1]]

    message["buffer_items"] = buffer
    message["plugin"] = buffer[0]
    message["server"] = buffer[1]
    message["buffer_short"] = buffer[2]
    message["tags"] = message["tags"].split(",")
    message["displayed"] = bool(message["displayed"])
    message["highlight"] = bool(message["highlight"])
    message["X-notified"] = False
    message["local_time"] = timestamp(message["timestamp"])

    return message


def notify(summary, body):
    """ Details: https://developer.gnome.org/notification-spec/
        http://cheesehead-techblog.blogspot.ch/2009/02/five-ways-to-make-notification-pop-up.html"""

    replaces_id = 0
    service = "org.freedesktop.Notifications"
    path = "/org/freedesktop/Notifications"
    interface = service
    app_icon = "user-invisible"
    expire_timeout = 10000
    actions = []
    hints = []

    session_bus = dbus.SessionBus()
    obj = session_bus.get_object(service, path)
    interface = dbus.Interface(obj, interface)
    interface.Notify(
        app_name, replaces_id, app_icon, summary, body, actions, hints, expire_timeout
    )


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
        print()
        mqttclient.disconnect()
        sys.exit(0)


if __name__ == "__main__":
    main()
