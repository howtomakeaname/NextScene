#pragma once
#include <string>
#include <vector>
#include <cstdint>

namespace krkr::documents {
bool owns(const char *path);
// The caller owns a successful fd. Errors set errno and return -1.
int open(const char *path, int flags);
struct Stat { int kind; int64_t size; int64_t modified; };
bool stat(const char *path, Stat &value);
bool list(const char *path, std::vector<std::string> &names);
bool mutate(const char *method, const char *path, const char *to = nullptr);
}
