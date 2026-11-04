# 부하 생성기 Job(load-k6, L1-2b)의 이미지입니다. 스크립트만 담고 실행은 run.sh가 합니다.
# 배포 workflow(deploy-server-env)가 부하 환경 배포 때 빌드해 Job에 붙입니다. 버전은 README의 로컬 실행과 같습니다.
FROM grafana/k6:2.3.0
WORKDIR /load
COPY --chown=k6:k6 . .
ENTRYPOINT ["sh", "/load/run.sh"]
