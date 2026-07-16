// Parallel transport tier for gRPC, coexisting with the Dio stack. The base IS a
// ClientChannel (inheritance, same idea as AbstractGateway). Concrete channels
// expose typed `...ServiceClient` getters built from generated protobuf
// (`*.pbgrpc.dart`). Secure-by-default credentials; gzip + identity codecs.
//
// Rename anchors: `Feature` -> your service name; `FeatureServiceClient` comes
// from your generated `feature.pbgrpc.dart`.

import 'package:grpc/grpc.dart';

import 'package:app/gateway/model/url.dart';
import 'package:app/main/environment.dart';
// import 'package:app/grpc/feature.pbgrpc.dart'; // generated; uncomment in real app

/// Base gRPC channel. gRPC hosts are plain host strings (no scheme); port
/// defaults to 443.
abstract class AbstractGrpcGateway extends ClientChannel {
  AbstractGrpcGateway({required Url url, bool useInsecure = false})
      : super(
          url.baseHost,
          port: url.port ?? 443,
          options: ChannelOptions(
            credentials: useInsecure
                ? const ChannelCredentials.insecure()
                : const ChannelCredentials.secure(),
            codecRegistry: CodecRegistry(
              codecs: const <Codec>[GzipCodec(), IdentityCodec()],
            ),
          ),
        );
}

/// Concrete channel. One typed service-client getter per generated stub.
class FeatureChannel extends AbstractGrpcGateway {
  FeatureChannel(Environment env) : super(url: env.grpcUrl);

  // FeatureServiceClient get featureClient => FeatureServiceClient(this);

  Future<void> dispose() => shutdown();
}
