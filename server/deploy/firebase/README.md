# Firebase Hosting

S117: 커스텀 도메인 하나가 모든 경로(`**`)를 서울 리전 Cloud Run `server`로 rewrite합니다. 정적 파일은 두지 않습니다(`public/`은 비어 있음).
S130: `appAssociation`은 `NONE`입니다. 기본값 `AUTO`이면 Hosting이 Firebase 프로젝트에 등록된 앱으로 `/.well-known/assetlinks.json`과 `apple-app-site-association`을 직접 만들어 rewrite보다 먼저 답합니다. `NONE`이면 이 경로도 rewrite로 server에 가고, App Link 지문은 server 설정(`ANDROID_CERT_SHA256`) 하나가 기준입니다.
배포는 `.github/workflows/deploy-server-env.yml`이 server 배포 뒤 `firebase deploy --only hosting --project <프로젝트>`로 합니다.
커스텀 도메인 연결은 도메인이 정해진 뒤 Firebase 콘솔에서 합니다.
