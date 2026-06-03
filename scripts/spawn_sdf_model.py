#!/usr/bin/env python3
import argparse
import math
import sys
import xml.etree.ElementTree as ET

import rospy
from gazebo_msgs.srv import SpawnModel
from geometry_msgs.msg import Pose


def _set_plugin_tag(plugin, tag, value):
    elem = plugin.find(tag)
    if elem is not None:
        elem.text = str(value)


def render_sdf(path, mavlink_tcp_port, mavlink_udp_port, qgc_udp_port, sdk_udp_port):
    tree = ET.parse(path)
    root = tree.getroot()
    for plugin in root.iter("plugin"):
        if plugin.attrib.get("name") == "mavlink_interface":
            _set_plugin_tag(plugin, "mavlink_tcp_port", mavlink_tcp_port)
            _set_plugin_tag(plugin, "mavlink_udp_port", mavlink_udp_port)
            _set_plugin_tag(plugin, "qgc_udp_port", qgc_udp_port)
            _set_plugin_tag(plugin, "sdk_udp_port", sdk_udp_port)
    return ET.tostring(root, encoding="unicode")


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
    args = parser.parse_args(rospy.myargv(argv=sys.argv)[1:])

    rospy.init_node("spawn_sdf_model", anonymous=True)
    sdf = render_sdf(
        args.sdf,
        args.mavlink_tcp_port,
        args.mavlink_udp_port,
        args.qgc_udp_port,
        args.sdk_udp_port,
    )

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
