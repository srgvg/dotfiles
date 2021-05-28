#!/usr/bin/env python3

# https://github.com/waxlamp/elgato/blob/master/elgato/__main__.py

"""Main module for elgato package."""

import argparse
import json
import leglight
import os
import sys
from typing import Any, List, Literal, Optional, TypedDict


# Monkeypatch requests to provide a timeout for all GET requests.
import requests

old_get = requests.get


def new_get(*args: Any, **kwargs: Any) -> Any:
    """Wrap calls to requests.get() with injection of a timeout."""
    kwargs["timeout"] = 2
    return old_get(*args, **kwargs)


requests.get = new_get


class DiscoveredLight(TypedDict):
    """Type of persisted light information."""

    address: str
    port: int


class LightInfo(DiscoveredLight):
    """Type of runtime light information."""

    name: str
    power: Literal["off", "on"]
    brightness: int
    color: int


class Discovered:
    """Active record class for retrieving/saving light list."""

    path: str
    lights: List[leglight.LegLight] = []

    def __init__(self, path: str) -> None:
        """Initialize with a path to a JSON file."""
        self.path = path

    def hydrate(self) -> None:
        """Hydrate with light data from the config file."""
        with open(self.path) as f:
            lights: List[DiscoveredLight] = json.loads(f.read())
            ok = True
            for (i, light) in enumerate(lights):
                try:
                    self.lights.append(
                        leglight.LegLight(light["address"], light["port"])
                    )
                except requests.exceptions.Timeout:
                    print(
                        f"Light {i} ({light['address']}:{light['port']}) "
                        "could not be found",
                        file=sys.stderr,
                    )
                    ok = False

            if not ok:
                print(
                    "You may want to run light discovery again "
                    "(`elgato lights --discover`)"
                )

    def refresh(self) -> None:
        """Discover the lights on the network."""
        lights = leglight.discover(5)
        self.lights = [leglight.LegLight(light.address, light.port) for light in lights]
        self.save()

    def save(self) -> None:
        """Save the current data to the file this instance was opened from."""
        with open(self.path, "w") as f:
            f.write(
                json.dumps(
                    [
                        {"address": light.address, "port": light.port}
                        for light in self.lights
                    ]
                )
            )

    def get_light(self, which: int) -> leglight.LegLight:
        """Return a light by index, guarding against out-of-range requests."""
        try:
            return self.lights[which]
        except IndexError:
            raise RuntimeError(
                "no such light (try running `elgato lights` or "
                "`elgato lights --discover` to see what lights are available)"
            )

    def light_info(self, which: int) -> LightInfo:
        """Construct a LightInfo object from an index."""
        light = self.get_light(which)

        return {
            "name": f"{light.productName} {light.serialNumber}",
            "power": "off" if light.isOn == 0 else "on",
            "brightness": light.isBrightness,
            "color": int(light.isTemperature),
            "address": light.address,
            "port": light.port,
        }

    def print_light_info(self, which: int) -> None:
        """Print information about a light by index."""
        light = self.light_info(which)
        spacing = max(len(key) for key in light.keys())
        for key in light:
            print(f"    {key.rjust(spacing)}: {light[key]}")  # type: ignore


def get_discovered_lights() -> Discovered:
    """Return the current settings."""
    config_dir = os.getenv("ELGATO_CONFIG_DIR", os.path.expanduser("~/.config/elgato"))
    discovered_file = os.path.join(config_dir, "discovered.json")

    # Ensure config directory exists.
    if not os.path.exists(config_dir):
        os.makedirs(config_dir)

    # Ensure discovered lights file exists.
    if not os.path.exists(discovered_file):
        with open(discovered_file, "w") as f:
            f.write("[]")

    return Discovered(discovered_file)


discovered = get_discovered_lights()


def lights(discover: bool) -> int:
    """Discover the lights on the network, and display them."""
    if discover:
        discovered.refresh()
    else:
        discovered.hydrate()

    for index in range(len(discovered.lights)):
        print(f"Light {index}")
        discovered.print_light_info(index)

    return 0


def turn_on(which: int) -> int:
    """Turn on the requested light."""
    discovered.hydrate()
    light = discovered.get_light(which)
    light.on()
    return 0


def turn_off(which: int) -> int:
    """Turn off the requested light."""
    discovered.hydrate()
    light = discovered.get_light(which)
    light.off()
    return 0


def toggle(which: int) -> int:
    """Toggle the requested light."""
    discovered.hydrate()
    light = discovered.get_light(which)
    return turn_on(which) if light.isOn == 0 else turn_off(which)


def set_color(
    which: int, level: Optional[int], warmer: Optional[int], cooler: Optional[int]
) -> int:
    """Set the first light's color temperature."""
    discovered.hydrate()
    light = discovered.get_light(which)

    delta: Optional[int] = None

    if level is not None:
        light.color(level)
    elif warmer is not None:
        delta = -500 if warmer < 0 else -warmer
    elif cooler is not None:
        delta = 500 if cooler < 0 else cooler
    else:
        print(int(light.isTemperature))

    if delta is not None:
        level = int(light.isTemperature) + delta
        if level < 2900:
            level = 2900
        elif level > 7000:
            level = 7000

        light.color(level)

    return 0


def set_brightness(
    which: int, level: Optional[int], brighter: Optional[int], dimmer: Optional[int]
) -> int:
    """Set the first light's brightness."""
    discovered.hydrate()
    light = discovered.get_light(which)

    delta: Optional[int] = None

    if level is not None:
        light.brightness(level)
    elif brighter is not None:
        delta = 10 if brighter < 0 else brighter
    elif dimmer is not None:
        delta = -10 if dimmer < 0 else -dimmer
    else:
        print(light.isBrightness)

    if delta is not None:
        level = light.isBrightness + delta
        if level < 0:
            level = 0
        elif level > 100:
            level = 100

        light.brightness(level)

    return 0


def validate_color_temperature(s: str) -> int:
    """Validate color temperature argument."""

    try:
        value = int(s)
    except ValueError:
        raise argparse.ArgumentTypeError(f"{s} is not an integer")

    if value < 2900 or value > 7000:
        raise argparse.ArgumentTypeError(
            "color temperature must be between 2900 and 7000"
        )

    if value % 100 != 0:
        raise argparse.ArgumentTypeError("color temperature must be divisible by 100")

    return value


def validate_color_delta(s: str) -> int:
    """Validate color temperature delta argument."""

    try:
        value = int(s)
    except ValueError:
        raise argparse.ArgumentTypeError(f"{s} is not an integer")

    if value < 0 or value > 4100:
        raise argparse.ArgumentTypeError(
            "color temperature change must be between 0 and 4100"
        )

    if value % 100 != 0:
        raise argparse.ArgumentTypeError(
            "color temperature change must be divisible by 100"
        )

    return value


def validate_brightness(s: str) -> int:
    """Validate brightness argument."""

    try:
        value = int(s)
    except ValueError:
        raise argparse.ArgumentTypeError(f"{s} is not an integer")

    if value < 0 or value > 100:
        raise argparse.ArgumentTypeError("brightness must be between 0 and 100")

    return value


def main() -> int:
    """Run the elgato program."""

    # Parse command line arguments.
    #
    # The main parser just knows how to print help when no subcommand is given,
    # and delegates to subparsers otherwise.
    parser = argparse.ArgumentParser(
        description="Control utility for El Gato brand lights."
    )

    def print_help() -> int:
        parser.print_help()
        return 1

    parser.set_defaults(action=print_help)

    # Define a series of subcommand parsers.
    subparsers = parser.add_subparsers(title="subcommands")

    parser_lights = subparsers.add_parser(
        "lights",
        help="Display/refresh list of discovered lights",
        description=(
            "Display information about known lights, "
            "and query the local network to refresh the list"
        ),
    )
    parser_lights.add_argument(
        "--discover",
        action="store_true",
        help="Query the network for lights and save the results",
    )
    parser_lights.set_defaults(action=lights)

    parser_on = subparsers.add_parser(
        "on", help="Turn a light on", description="Turn a light on"
    )
    parser_on.add_argument(
        "which",
        metavar="WHICH",
        nargs="?",
        default=0,
        type=int,
        help="Which light to turn on (default: 0)",
    )
    parser_on.set_defaults(action=turn_on)

    parser_off = subparsers.add_parser(
        "off", help="Turn a light off", description="Turn a light off"
    )
    parser_off.add_argument(
        "which",
        metavar="WHICH",
        nargs="?",
        default=0,
        type=int,
        help="Which light to turn off (default: 0)",
    )
    parser_off.set_defaults(action=turn_off)

    parser_toggle = subparsers.add_parser(
        "toggle", help="Toggle a light", description="Toggle a light"
    )
    parser_toggle.add_argument(
        "which",
        metavar="WHICH",
        nargs="?",
        default=0,
        type=int,
        help="Which light to toggle (default: 0)",
    )
    parser_toggle.set_defaults(action=toggle)

    parser_color = subparsers.add_parser(
        "color",
        help="Set or query a light's color temperature",
        description="Set or query a light's color temperature",
    )
    parser_color.add_argument(
        "which",
        metavar="WHICH",
        nargs="?",
        default=0,
        type=int,
        help="Which light to operate on (default: 0)",
    )
    group = parser_color.add_mutually_exclusive_group()
    group.add_argument(
        "--level",
        metavar="LEVEL",
        type=validate_color_temperature,
        default=None,
        help=(
            "Color temperature in Kelvin (2900-7000); "
            "omit argument to display current value"
        ),
    )
    group.add_argument(
        "--warmer",
        metavar="DELTA",
        type=validate_color_delta,
        nargs="?",
        const=-1,
        default=None,
        help="Color temperature change (0-4100) (default: 500)",
    )
    group.add_argument(
        "--cooler",
        metavar="DELTA",
        type=validate_color_delta,
        nargs="?",
        const=-1,
        default=None,
        help="Color temperature change (0-4100) (default: 500)",
    )
    parser_color.set_defaults(action=set_color)

    parser_brightness = subparsers.add_parser(
        "brightness",
        help="Set or query a light's brightness",
        description="Set or query a light's brightness",
    )
    parser_brightness.add_argument(
        "which",
        metavar="WHICH",
        nargs="?",
        default=0,
        type=int,
        help="Which light to operate on (default: 0)",
    )
    group = parser_brightness.add_mutually_exclusive_group()
    group.add_argument(
        "--level",
        metavar="LEVEL",
        type=validate_brightness,
        default=None,
        help="Brightness level (0-100); omit argument to display current value",
    )
    group.add_argument(
        "--brighter",
        metavar="DELTA",
        type=validate_brightness,
        nargs="?",
        const=-1,
        default=None,
        help="Brightness change (0-100) (default: 10)",
    )
    group.add_argument(
        "--dimmer",
        metavar="DELTA",
        type=validate_brightness,
        nargs="?",
        const=-1,
        default=None,
        help="Brightness change (0-100) (default: 10)",
    )
    parser_brightness.set_defaults(action=set_brightness)

    # Parse the command line arguments and dispatch to the correct subcommand.
    args = parser.parse_args(sys.argv[1:])
    action = args.action
    del args.action

    try:
        return action(**vars(args))
    except RuntimeError as e:
        print(e, file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
