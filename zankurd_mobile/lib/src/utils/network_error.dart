/// Returns true when an exception is likely caused by a missing connection.
///
/// This deliberately uses only transport-level markers. Domain failures such
/// as a rejected purchase must stay in the regular error state.
bool isLikelyOfflineError(Object error) {
  final message = error.toString().toLowerCase();
  const transportMarkers = [
    'network',
    'offline',
    'socket',
    'timeout',
    'timed out',
    'failed host lookup',
    'connection refused',
    'connection reset',
    'dns',
    'internet',
  ];
  return transportMarkers.any(message.contains);
}
