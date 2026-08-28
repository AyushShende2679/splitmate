class Failure {
  final String message;
  final StackTrace? stackTrace;
  const Failure(this.message, [this.stackTrace]);
}

class CacheFailure extends Failure {
  const CacheFailure(super.message, [super.stackTrace]);
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message, [super.stackTrace]);
}
