cmake_minimum_required(VERSION 3.0.2)
project(gazebo_sim_px4_1_12)

find_package(catkin REQUIRED COMPONENTS roslaunch)

catkin_package()

install(
  DIRECTORY config launch manifest
  DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION}
)
