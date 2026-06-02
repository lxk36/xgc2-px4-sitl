cmake_minimum_required(VERSION 3.0.2)
project(px4_sitl_runtime)

find_package(catkin REQUIRED COMPONENTS roslaunch)

catkin_package()

install(
  DIRECTORY config launch manifest
  DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION}
)

install(
  PROGRAMS
    scripts/run_px4_sitl.sh
    scripts/setup_runtime_env.sh
  DESTINATION ${CATKIN_PACKAGE_BIN_DESTINATION}
)
