#include "AndroidDocumentStorage.h"
#include "KrkrJniHelper.h"
#include <cerrno>
#include <codecvt>
#include <locale>

namespace krkr::documents {
namespace {
constexpr auto klass = "org/github/krkr2/flutter_engine_bridge/AndroidDocumentTree";
struct Call : JniHelper::MethodInfo {
    bool ready;
    Call(const char *method, const char *signature) : ready(JniHelper::getStaticMethodInfo(*this, klass, method, signature)) {}
    ~Call() { if (classID) env->DeleteLocalRef(classID); }
    bool failed() {
        if (!env->ExceptionCheck()) return false;
        env->ExceptionClear(); errno = EACCES; return true;
    }
};
jstring string(JNIEnv *env, const char *value) {
    // JNI's NewStringUTF uses modified UTF-8, which cannot represent an ordinary
    // four-byte UTF-8 filename. Convert explicitly to preserve supplementary chars.
    std::wstring_convert<std::codecvt_utf8_utf16<char16_t>, char16_t> convert;
    const auto utf16 = convert.from_bytes(value);
    return env->NewString(reinterpret_cast<const jchar *>(utf16.data()), utf16.size());
}
std::string string(JNIEnv *env, jstring value) {
    const auto *chars = env->GetStringChars(value, nullptr);
    std::u16string utf16(reinterpret_cast<const char16_t *>(chars), env->GetStringLength(value));
    env->ReleaseStringChars(value, chars);
    std::wstring_convert<std::codecvt_utf8_utf16<char16_t>, char16_t> convert;
    return convert.to_bytes(utf16);
}
}
bool owns(const char *path) {
    if (!path || path[0] != '/') return false;
    Call c("ownsPath", "(Ljava/lang/String;)Z");
    if (!c.ready) return false;
    auto text = string(c.env, path);
    bool value = c.env->CallStaticBooleanMethod(c.classID, c.methodID, text);
    c.env->DeleteLocalRef(text);
    return !c.failed() && value;
}
int open(const char *path, int flags) {
    Call c("nativeOpen", "(Ljava/lang/String;I)I");
    if (!c.ready) { errno = EACCES; return -1; }
    auto text = string(c.env, path);
    int fd = c.env->CallStaticIntMethod(c.classID, c.methodID, text, flags);
    c.env->DeleteLocalRef(text);
    if (c.failed()) return -1;
    if (fd < 0) { errno = -fd; return -1; }
    return fd;
}
bool stat(const char *path, Stat &value) {
    Call c("nativeStat", "(Ljava/lang/String;)[J");
    if (!c.ready) return false;
    auto text = string(c.env, path);
    auto result = static_cast<jlongArray>(c.env->CallStaticObjectMethod(c.classID, c.methodID, text));
    c.env->DeleteLocalRef(text);
    if (c.failed() || !result) return false;
    jlong data[3]{};
    c.env->GetLongArrayRegion(result, 0, 3, data);
    c.env->DeleteLocalRef(result);
    if (c.failed()) return false;
    value = {static_cast<int>(data[0]), data[1], data[2]};
    return true;
}
bool list(const char *path, std::vector<std::string> &names) {
    Call c("nativeList", "(Ljava/lang/String;)[Ljava/lang/String;");
    if (!c.ready) return false;
    auto text = string(c.env, path);
    auto result = static_cast<jobjectArray>(c.env->CallStaticObjectMethod(c.classID, c.methodID, text));
    c.env->DeleteLocalRef(text);
    if (c.failed() || !result) return false;
    for (jsize i = 0; i < c.env->GetArrayLength(result); ++i) {
        auto item = static_cast<jstring>(c.env->GetObjectArrayElement(result, i));
        names.push_back(string(c.env, item));
        c.env->DeleteLocalRef(item);
    }
    c.env->DeleteLocalRef(result);
    return !c.failed();
}
bool mutate(const char *method, const char *path, const char *to) {
    Call c(method, to ? "(Ljava/lang/String;Ljava/lang/String;)Z" : "(Ljava/lang/String;)Z");
    if (!c.ready) return false;
    auto text = string(c.env, path);
    auto target = to ? string(c.env, to) : nullptr;
    const bool value = to
        ? c.env->CallStaticBooleanMethod(c.classID, c.methodID, text, target)
        : c.env->CallStaticBooleanMethod(c.classID, c.methodID, text);
    c.env->DeleteLocalRef(text);
    if (target) c.env->DeleteLocalRef(target);
    return !c.failed() && value;
}
}
