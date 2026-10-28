# Firebase Hosting

S117: 커스텀 도메인 하나가 모든 경로(`**`)를 서울 리전 Cloud Run `server`로 rewrite합니다. 정적 파일은 두지 않습니다(`public/`은 비어 있음).
배포는 `.github/workflows/deploy-server-env.yml`이 server 배포 뒤 `firebase deploy --only hosting --project <프로젝트>`로 합니다.
커스텀 도메인 연결은 도메인이 정해진 뒤 Firebase 콘솔에서 합니다.
