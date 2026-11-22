"""rofi's speaker / mic tabs (rofi/bin/k-devices) for Bluetooth earbuds, on faked wpctl and pw-dump:
a row per mode, a mode the earbuds aren't offering still listed, and picking it asks for that link."""
import json
import os
import subprocess

from fixture import REPO

BIN = os.path.join(REPO, "rofi", "bin")
PATH = "/org/bluez/hci0/dev_AA"


def earbuds(sb, profiles, active):
    """the earbuds as PipeWire device 40, offering these profiles, with this one in use (node 50)"""
    dump = [{"id": 40, "info": {"props": {"media.class": "Audio/Device", "device.api": "bluez5",
                                          "device.description": "Buds", "api.bluez5.path": PATH},
                                "params": {"EnumProfile": [{"name": n, "index": i} for i, n in enumerate(profiles)],
                                           "Profile": [{"name": active}]}}},
            {"id": 50, "info": {"props": {"media.class": "Audio/Sink", "device.id": "40"}}}]
    sb.write("~/dump.json", json.dumps(dump))
    sb.fake("pw-dump", f'cat {sb.path("~/dump.json")}')
    sb.fake("wpctl", 'case "$1" in status) printf "Audio\\n ├─ Sinks:\\n │  *   50. Buds [vol: 0.80]\\n │      61. Laptop [vol: 0.50]\\n" ;; esac')


def rows(sb, tab):
    p = subprocess.run([os.path.join(BIN, "k-" + tab)], env=sb.env, capture_output=True, text=True, timeout=20)
    return [l.split("\0")[0].strip("● ").strip() + " -> " + l.split("\x1f")[-1] for l in p.stdout.splitlines()
            if l and not l.startswith("\0")]


def test_each_mode_gets_a_row_at_the_bottom(sb):
    earbuds(sb, ["off", "a2dp-sink", "headset-head-unit"], "a2dp-sink")
    assert rows(sb, "speaker") == ["Laptop  ·  50% -> a:61", "Buds  ·  Headset (music)  ·  80% -> a:50",
                                   "Buds  ·  Handsfree (calls, with mic) -> p:40:2"]


def test_a_mode_not_offered_is_still_listed(sb):
    earbuds(sb, ["off", "headset-head-unit"], "headset-head-unit")
    assert rows(sb, "speaker") == ["Laptop  ·  50% -> a:61", "Buds  ·  Headset (music)  ·  not available -> c:40:a2dp-sink",
                                   "Buds  ·  Handsfree (calls, with mic)  ·  80% -> a:50"]


def test_picking_it_asks_for_the_link_then_switches(sb):
    earbuds(sb, ["off", "headset-head-unit"], "headset-head-unit")
    # the earbuds accept: after the request, PipeWire offers music mode too
    after = sb.read("~/dump.json").replace('{"name": "headset-head-unit", "index": 1}',
                                           '{"name": "headset-head-unit", "index": 1}, {"name": "a2dp-sink", "index": 2}')
    sb.write("~/after.json", after)
    sb.fake("busctl", f'cp {sb.path("~/after.json")} {sb.path("~/dump.json")}')
    subprocess.run([os.path.join(BIN, "k-speaker"), "--bring-up", "40", "a2dp-sink"], env=sb.env, timeout=30, check=True)
    assert sb.calls("busctl") == [f"busctl call org.bluez {PATH} org.bluez.Device1 ConnectProfile s "
                                  "0000110b-0000-1000-8000-00805f9b34fb"]
    assert "wpctl set-profile 40 2" in sb.calls("wpctl"), sb.calls("wpctl")


def test_a_refused_link_says_what_to_do(sb):
    earbuds(sb, ["off", "headset-head-unit"], "headset-head-unit")
    sb.fake("busctl", "exit 1")
    subprocess.run([os.path.join(BIN, "k-speaker"), "--bring-up", "40", "a2dp-sink"], env=sb.env, timeout=30, check=True)
    assert not [c for c in sb.calls("wpctl") if "set-profile" in c]
    assert "Headset isn't available" in sb.calls("notify-send")[-1], sb.calls("notify-send")
