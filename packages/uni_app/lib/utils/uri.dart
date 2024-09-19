extension UriUtils on Uri {
  Uri stripQueryComponent() {
    return Uri(
      scheme: scheme,
      userInfo: userInfo,
      host: host,
      port: port,
      path: path,
      fragment: fragment,
    );
  }

  Uri normalizeQueryComponent() => query.isNotEmpty
      ? replace(query: query.replaceAll('+', '%20'))
      : stripQueryComponent();
}
