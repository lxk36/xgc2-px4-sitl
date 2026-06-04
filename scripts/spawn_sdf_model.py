#!/usr/bin/env python3
import argparse
import math
import sys
import xml.etree.ElementTree as ET

import rospy
from gazebo_msgs.srv import SpawnModel
from geometry_msgs.msg import Pose


def _parse_bool(value):
    if isinstance(value, bool):
        return value
    normalized = str(value).strip().lower()
    if normalized in ("1", "true", "yes", "on"):
        return True
    if normalized in ("0", "false", "no", "off"):
        return False
    raise argparse.ArgumentTypeError("expected boolean value, got %r" % value)


def _set_plugin_tag(plugin, tag, value):
    elem = plugin.find(tag)
    if elem is not None:
        elem.text = str(value)


def _remove_children(parent, predicate):
    removed = []
    for child in list(parent):
        if predicate(child):
            parent.remove(child)
            removed.append(child)
    return removed


def _remove_named_plugin(root, plugin_name):
    removed = []
    for parent in root.iter():
        removed.extend(
            _remove_children(
                parent,
                lambda child: child.tag == "plugin"
                and child.attrib.get("name") == plugin_name,
            )
        )
    return removed


def _remove_include_by_name(root, include_name):
    removed = []
    for parent in root.iter():
        removed.extend(
            _remove_children(
                parent,
                lambda child: child.tag == "include"
                and child.findtext("name") == include_name,
            )
        )
    return removed


def _remove_joint_by_name(root, joint_name):
    removed = []
    for parent in root.iter():
        removed.extend(
            _remove_children(
                parent,
                lambda child: child.tag == "joint"
                and child.attrib.get("name") == joint_name,
            )
        )
    return removed


def _remove_plugin_tag(root, plugin_name, tag):
    removed = []
    for plugin in root.iter("plugin"):
        if plugin.attrib.get("name") != plugin_name:
            continue
        for elem in list(plugin):
            if elem.tag == tag:
                plugin.remove(elem)
                removed.append(elem)
    return removed


def _strip_indoor_sensor_plugins(root, strip_gps, strip_mag, strip_baro):
    report = []
    if strip_gps:
        report.append(("gps include gps0", len(_remove_include_by_name(root, "gps0"))))
        report.append(("gps joint gps0_joint", len(_remove_joint_by_name(root, "gps0_joint"))))
    if strip_mag:
        report.append(("plugin magnetometer_plugin", len(_remove_named_plugin(root, "magnetometer_plugin"))))
        report.append(("mavlink_interface magSubTopic", len(_remove_plugin_tag(root, "mavlink_interface", "magSubTopic"))))
    if strip_baro:
        report.append(("plugin barometer_plugin", len(_remove_named_plugin(root, "barometer_plugin"))))
        report.append(("mavlink_interface baroSubTopic", len(_remove_plugin_tag(root, "mavlink_interface", "baroSubTopic"))))
    return report


def render_sdf(
    path,
    mavlink_tcp_port,
    mavlink_udp_port,
    qgc_udp_port,
    sdk_udp_port,
    strip_gps=False,
    strip_mag=False,
    strip_baro=False,
):
    tree = ET.parse(path)
    root = tree.getroot()
    strip_report = _strip_indoor_sensor_plugins(root, strip_gps, strip_mag, strip_baro)
    for plugin in root.iter("plugin"):
        if plugin.attrib.get("name") == "mavlink_interface":
            _set_plugin_tag(plugin, "mavlink_tcp_port", mavlink_tcp_port)
            _set_plugin_tag(plugin, "mavlink_udp_port", mavlink_udp_port)
            _set_plugin_tag(plugin, "qgc_udp_port", qgc_udp_port)
            _set_plugin_tag(plugin, "sdk_udp_port", sdk_udp_port)
    return ET.tostring(root, encoding="unicode"), strip_report


def quaternion_from_rpy(roll, pitch, yaw):
    cy = math.cos(yaw * 0.5)
    sy = math.sin(yaw * 0.5)
    cp = math.cos(pitch * 0.5)
    sp = math.sin(pitch * 0.5)
    cr = math.cos(roll * 0.5)
    sr = math.sin(roll * 0.5)
    return (
        sr * cp * cy - cr * sp * sy,
        cr * sp * cy + sr * cp * sy,
        cr * cp * sy - sr * sp * cy,
        cr * cp * cy + sr * sp * sy,
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--sdf", required=True)
    parser.add_argument("--model", required=True)
    parser.add_argument("--x", type=float, default=0.0)
    parser.add_argument("--y", type=float, default=0.0)
    parser.add_argument("--z", type=float, default=0.0)
    parser.add_argument("--roll", type=float, default=0.0)
    parser.add_argument("--pitch", type=float, default=0.0)
    parser.add_argument("--yaw", type=float, default=0.0)
    parser.add_argument("--mavlink-tcp-port", type=int, required=True)
    parser.add_argument("--mavlink-udp-port", type=int, required=True)
    parser.add_argument("--qgc-udp-port", type=int, required=True)
    parser.add_argument("--sdk-udp-port", type=int, required=True)
    parser.add_argument("--strip-gps", type=_parse_bool, default=False)
    parser.add_argument("--strip-mag", type=_parse_bool, default=False)
    parser.add_argument("--strip-baro", type=_parse_bool, default=False)
    args = parser.parse_args(rospy.myargv(argv=sys.argv)[1:])

    rospy.init_node("spawn_sdf_model", anonymous=True)
    sdf, strip_report = render_sdf(
        args.sdf,
        args.mavlink_tcp_port,
        args.mavlink_udp_port,
        args.qgc_udp_port,
        args.sdk_udp_port,
        strip_gps=args.strip_gps,
        strip_mag=args.strip_mag,
        strip_baro=args.strip_baro,
    )
    for label, count in strip_report:
        rospy.loginfo("SDF transform: removed %d x %s", count, label)

    pose = Pose()
    pose.position.x = args.x
    pose.position.y = args.y
    pose.position.z = args.z
    qx, qy, qz, qw = quaternion_from_rpy(args.roll, args.pitch, args.yaw)
    pose.orientation.x = qx
    pose.orientation.y = qy
    pose.orientation.z = qz
    pose.orientation.w = qw

    rospy.wait_for_service("/gazebo/spawn_sdf_model")
    spawn = rospy.ServiceProxy("/gazebo/spawn_sdf_model", SpawnModel)
    result = spawn(args.model, sdf, "", pose, "world")
    if not result.success:
        rospy.logerr("SpawnModel failed: %s", result.status_message)
        raise SystemExit(1)
    rospy.loginfo("SpawnModel: %s", result.status_message)


if __name__ == "__main__":
    main()
