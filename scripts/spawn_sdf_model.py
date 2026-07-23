#!/usr/bin/env python3
"""Spawn one SDF model into Gazebo, owning preflight, replace, and verify.

The orchestrator previously forked three Python processes per robot
(rosservice preflight, this spawner, rosservice verification). One rospy
process now performs the whole sequence, so each robot costs one interpreter
start instead of three.

Exit codes:
  0  the model was spawned and is visible in Gazebo
  4  the model already exists and --existing-model-policy is "fail"
     (permanent: retrying without operator action cannot succeed)
  1  any other failure (transient: Gazebo or ROS may still be starting)
"""
import argparse
import json
import math
import sys
import time
import xml.etree.ElementTree as ET

import rospy
from gazebo_msgs.srv import DeleteModel, GetModelState, SpawnModel
from geometry_msgs.msg import Pose

EXIT_TRANSIENT = 1
EXIT_MODEL_EXISTS = 4
SERVICE_WAIT_SECONDS = 30.0
DELETE_WAIT_SECONDS = 5.0
VERIFY_WAIT_SECONDS = 10.0


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


def service_proxy(name, service_type):
    rospy.wait_for_service(name, timeout=SERVICE_WAIT_SECONDS)
    return rospy.ServiceProxy(name, service_type)


def model_exists(get_model_state, model):
    return bool(get_model_state(model, "world").success)


def wait_for_model(get_model_state, model, present, deadline_seconds):
    deadline = time.monotonic() + deadline_seconds
    while True:
        if model_exists(get_model_state, model) == present:
            return True
        if time.monotonic() >= deadline:
            return False
        time.sleep(0.1)


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
    parser.add_argument(
        "--existing-model-policy", choices=("fail", "replace"), default="fail"
    )
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

    get_model_state = service_proxy("/gazebo/get_model_state", GetModelState)
    replaced = False
    if args.existing_model_policy == "replace" and model_exists(
        get_model_state, args.model
    ):
        delete_model = service_proxy("/gazebo/delete_model", DeleteModel)
        result = delete_model(args.model)
        if not result.success:
            rospy.logerr("DeleteModel failed: %s", result.status_message)
            raise SystemExit(EXIT_TRANSIENT)
        if not wait_for_model(get_model_state, args.model, False, DELETE_WAIT_SECONDS):
            rospy.logerr("model %s still exists after delete_model", args.model)
            raise SystemExit(EXIT_TRANSIENT)
        replaced = True

    spawn = service_proxy("/gazebo/spawn_sdf_model", SpawnModel)
    result = spawn(args.model, sdf, "", pose, "world")
    if not result.success:
        # The fail policy skips the preflight, so an existing model surfaces
        # here; distinguish it from transient Gazebo errors for the caller.
        if args.existing_model_policy == "fail" and model_exists(
            get_model_state, args.model
        ):
            rospy.logerr("model %s already exists", args.model)
            raise SystemExit(EXIT_MODEL_EXISTS)
        rospy.logerr("SpawnModel failed: %s", result.status_message)
        raise SystemExit(EXIT_TRANSIENT)
    if not wait_for_model(get_model_state, args.model, True, VERIFY_WAIT_SECONDS):
        rospy.logerr("Gazebo did not report model %s after spawn", args.model)
        raise SystemExit(EXIT_TRANSIENT)
    rospy.loginfo("SpawnModel: %s", result.status_message)
    print("SPAWN_SDF_RESULT " + json.dumps({"replaced": replaced}), flush=True)


if __name__ == "__main__":
    main()
