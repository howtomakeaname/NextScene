cmake_minimum_required(VERSION 3.16)
project(nextscene_artemis_regressions LANGUAGES C CXX)
enable_testing()
# Keep one regression suite in the engine repository. This entry point keeps
# existing NextScene test commands usable, including explicit source overrides.
set(ARTC_BUILD_TESTS ON)
add_subdirectory(.. engine)
