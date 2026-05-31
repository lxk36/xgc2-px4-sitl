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
    scripts/build_deb.sh
    scripts/build_px4_runtime.sh
    scripts/build_runtime_deb_in_docker.sh
    scripts/check_px4_runtime.sh
    scripts/extract_px4_runtime.sh
    scripts/fetch_px4.sh
    scripts/publish_apt_repo.sh
    scripts/run_px4_sitl.sh
    scripts/setup_runtime_env.sh
  DESTINATION ${CATKIN_PACKAGE_BIN_DESTINATION}
)

install(
  DIRECTORY scripts/lib
  DESTINATION ${CATKIN_PACKAGE_BIN_DESTINATION}
  FILE_PERMISSIONS OWNER_READ OWNER_WRITE GROUP_READ WORLD_READ
  DIRECTORY_PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE
)
