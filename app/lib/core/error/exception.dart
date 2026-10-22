// thrown by remote data sources (Firestore); repositories map it to ServerFailure
class ServerException implements Exception {
  String code;
  ServerException({required this.code});
}

// thrown by local data sources (bundled assets, cache); repositories map it to CacheFailure
class CacheException implements Exception {
  String code;
  CacheException({required this.code});
}

class PoseException implements Exception {
  String code;
  PoseException({required this.code});
}
