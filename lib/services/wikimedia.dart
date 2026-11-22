import 'package:flutter/foundation.dart' show kIsWeb;

const _agent = 'DeutschLesen/0.1 (personal language-learning app)';

/// Headers per the Wikimedia API etiquette. Browsers forbid setting
/// User-Agent, so the web build sends only Api-User-Agent.
Map<String, String> get wikimediaHeaders => {
  'Api-User-Agent': _agent,
  if (!kIsWeb) 'User-Agent': _agent,
};
