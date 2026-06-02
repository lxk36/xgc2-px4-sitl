cmake_minimum_required(VERSION 3.0.2)
project(px4_sitl_runtime)

find_package(ament_cmake REQUIRED)

install(
  DIRECTORY config launch manifest
  DESTINATION share/${PROJECT_NAME}
)

install(
  PROGRAMS
    scripts/run_px4_sitl.sh
    scripts/setup_runtime_env.sh
  DESTINATION lib/${PROJECT_NAME}
)

ament_package()
