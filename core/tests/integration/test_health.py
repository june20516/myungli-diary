# gRPC health checking: Cloud Run startup probe와 server가 쓰는 상태 (#34)
import grpc
import pytest
from grpc_health.v1 import health_pb2, health_pb2_grpc

from myungli_engine.grpc_api import server as server_module

ENGINE_SERVICE = "myungli.engine.v1.MyungliEngine"


def check(port: int, service: str) -> health_pb2.HealthCheckResponse.ServingStatus.ValueType:
    with grpc.insecure_channel(f"localhost:{port}") as channel:
        stub = health_pb2_grpc.HealthStub(channel)
        response: health_pb2.HealthCheckResponse = stub.Check(health_pb2.HealthCheckRequest(service=service))
        return response.status


@pytest.mark.parametrize("service", ["", ENGINE_SERVICE])
def test_serving_after_start(service: str) -> None:
    running = server_module.start(0)
    try:
        assert check(running.port, service) == health_pb2.HealthCheckResponse.SERVING
    finally:
        running.stop(grace=None)


@pytest.mark.parametrize("service", ["", ENGINE_SERVICE])
def test_not_serving_once_shutdown_begins(service: str) -> None:
    running = server_module.start(0)
    try:
        running.begin_shutdown()
        assert check(running.port, service) == health_pb2.HealthCheckResponse.NOT_SERVING
    finally:
        running.stop(grace=None)
