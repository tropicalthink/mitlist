import 'package:uuid/uuid.dart';

/// True when [id] is a UUID the backend will accept in JSON fields typed as
/// `uuid.UUID`. Bundled grocery seed uses stable slugs (e.g. `milk`) locally;
/// those must not be sent to the API until the server graph has assigned a UUID.
bool isApiUuid(String? id) =>
    id != null && id.isNotEmpty && Uuid.isValidUUID(fromString: id);
