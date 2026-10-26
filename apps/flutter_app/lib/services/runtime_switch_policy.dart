/// Platforms whose native runtime supports destroying a parked project and
/// creating another engine handle without restarting the Flutter process.
bool canReplaceParkedRuntime(String operatingSystem) {
  return operatingSystem == 'android' ||
      operatingSystem == 'ohos' ||
      operatingSystem == 'ios';
}
