import '../../api/route_api.dart';

const adminUnreachableMessage = 'Cannot reach the route server.';

class AdminLoad<T> {
  const AdminLoad.ok(this.value) : error = null;

  const AdminLoad.fail(this.error) : value = null;

  final T? value;
  final String? error;

  bool get failed => error != null;
}

Future<AdminLoad<T>> guardAdminLoad<T>(Future<T> Function() call) async {
  try {
    return AdminLoad.ok(await call());
  } on ApiException catch (error) {
    final message = error.message.trim();
    return AdminLoad.fail(message.isEmpty ? 'Request failed.' : message);
  } catch (_) {
    return AdminLoad.fail(adminUnreachableMessage);
  }
}

String? adminErrorBanner(Iterable<AdminLoad<dynamic>> loads) {
  final messages = <String>[];
  for (final load in loads) {
    final error = load.error;
    if (error == null || messages.contains(error)) continue;
    messages.add(error);
  }
  if (messages.isEmpty) return null;
  return messages.join(' ');
}

bool adminServerReachable(Iterable<AdminLoad<dynamic>> loads) {
  for (final load in loads) {
    if (load.error == adminUnreachableMessage) return false;
  }
  return true;
}
