# SpaceWalker

스페이스 멤버들과 일일 미션 사진을 공유하는 SNS형 iOS 앱입니다. Apple 로그인으로 시작해 Space를 선택하고, 캘린더·피드·지도·마이페이지 탭을 중심으로 미션 사진을 업로드/조회할 수 있습니다. 실서비스용 API 연동과 토큰 리프레시, 이미지 메타데이터 저장, 프리사인드 업로드 흐름을 구현했습니다.

- **주요 역할**: iOS 클라이언트 개발 (UIKit + Rx), 백엔드 연동, UX 설계  
- **타깃**: iOS 16+, Xcode 15+

| Login | Calendar | Feed | Feed Detail |
|------|------|------|------|
| <img width="200" src="https://github.com/user-attachments/assets/81b02ccd-39d0-44ce-baf7-ba328a9731cc" /> | <img width="200" src="https://github.com/user-attachments/assets/3cfeebba-0964-4455-a5b4-0f3a369c72ce" /> | <img width="200" src="https://github.com/user-attachments/assets/43f325c2-3085-4a44-b8f1-7e78b3fe2695" /> | <img width="200" src="https://github.com/user-attachments/assets/31ce294e-33b7-405e-9f5f-449e965a71dc" /> | 

| Map | Calendar Detail | Calendar Detail - 2 | My Page |
|------|------|------|------|
| <img width="200" src="https://github.com/user-attachments/assets/ac62e8c1-38f9-407d-b525-ad69e9489693" /> | <img width="200" src="https://github.com/user-attachments/assets/adca53ee-88b1-4c8e-a1f8-14fb0152b070" /> | <img width="200" src="https://github.com/user-attachments/assets/aff3da4b-8167-4678-aa46-e380f516bec2" /> | <img width="200" src="https://github.com/user-attachments/assets/2dbdb77c-fd83-4625-bbf8-9d72d0119dea" /> |

| My Page - Edit Nickname | My Page - Privacy Policy | My Page - Terms | My Page - OSS License|
|------|------|------|------|
| <img width="200" src="https://github.com/user-attachments/assets/c0962d2a-8c52-41e1-9c03-683a73a8bea5" /> | <img width="200" src="https://github.com/user-attachments/assets/7971b45c-60cc-4d7d-90f6-0dfec3696325" /> | <img width="200" src="https://github.com/user-attachments/assets/42e50946-449a-4ce5-8f87-eeedb032a1f4" /> | <img width="200" src="https://github.com/user-attachments/assets/71dd09d8-9506-43e5-9e4e-d5e6c74e0674" /> |

## 핵심 기능
- **Apple 로그인**: `AuthenticationServices`를 이용해 애플 계정으로 로그인. 토큰 저장 후 자동 세션 유지.
- **Space 선택/참여**: 서버에서 내려주는 Space 리스트(최대 3개 선택)를 Rx 바인딩으로 처리. 유효하지 않은 ID 에러 핸들링 포함.
- **캘린더 미션**: FSCalendar 기반 월간 뷰, 미션 제목/필터 칩 표시. 사진 촬영 시 EXIF 메타데이터(촬영 시각, 위치, 해상도, 기기명, MIME 타입)를 추출·저장(Realm) 후 프리사인드 URL 업로드 → 미션 제출.
- **피드**: Masonry 스타일 워터폴 레이아웃, Space별 필터 칩, Kingfisher 이미지 캐싱, 페이지네이션, 좋아요 토글 중복요청 방지.
- **지도**: 위치 기반 사진/Space 조회(뷰 골격 준비) 및 위치 권한 처리.
- **마이페이지**: 프로필 이미지 업로드(프리사인드), 닉네임 수정, 약관/정책/오픈소스 라이선스 링크, 회원 탈퇴.
- **안정성**: 401 응답 시 자동 토큰 리프레시 및 재요청. Rx 기반 dispose 관리, 전역 로깅(Apple `Logger` + 커스텀 헬퍼).

## 기술 스택
- **UI**: UIKit, SnapKit, FSCalendar, Photos/AVFoundation/MapKit, SafariServices
- **Reactive**: RxSwift/RxCocoa
- **Networking**: Alamofire, 커스텀 `NetworkManager`(토큰 리프레시 + 더미 응답 지원)
- **Auth**: Sign in with Apple
- **이미지/캐시**: Kingfisher, 프리사인드 URL 업로드
- **로컬 저장**: Realm (사진 메타데이터 캐시)
- **기타**: OSLog/Logger, CryptoKit(Nonce)

## 아키텍처
- **계층 분리**: `App`(엔트리/루트 전환) → `Features`(화면) → `Core`(네트워크·레포지토리·유틸·모델) → `Resources`.
- **패턴**: UIKit 기반 MVVM(Rx) + Repository. ViewController는 UI/바인딩, ViewModel은 입력/출력 스트림과 상태 관리, Repository가 네트워크/로컬 접근을 캡슐화.
- **네트워크**: 단일 `NetworkManager`가 Alamofire 요청을 감싸고, 401 시 토큰 리프레시 후 재시도. 더미 API 모드(`requestDummy`)를 같은 인터페이스로 제공해 개발/테스트를 단순화.
- **세션/라우팅**: `SceneDelegate`에서 토큰 유무와 `/api/v1/space/my-space` 결과에 따라 루트 VC를 전환(`SignUp` ↔ `SpaceSelect` ↔ `MainTabBar`). `NetworkManager.onRequireReauthentication` 콜백으로 재인증 플로우를 일원화.
- **데이터 보관**: Realm으로 촬영 메타데이터를 로컬에 저장해 업로드 실패 시 복구 여지 확보. Kingfisher로 원격 이미지 캐시.
- **로깅**: OSLog `Logger` + 헬퍼(`LogAuth`, `LogNetwork`, `LogUI`, `LogGeneral`)로 카테고리 기반 로그 관리.

## 폴더 구조
- `App/`: `AppDelegate`, `SceneDelegate` – 앱 부팅, 루트 전환, 재인증 콜백.
- `Core/`: 네트워크/디코더/유틸/로그/세션/Realm 모델, Repositories.
- `Features/`  
  - `SignUp/`: Apple 로그인, 약관/개인정보 링크.  
  - `SpaceSelect/`: Space 선택, Rx MVVM 패턴(`SpaceSelectViewModel`).  
  - `Calendar/` `CalendarDetail/`: 미션 달력, 촬영·업로드·제출 흐름.  
  - `Feed/` `FeedDetail/`: 워터폴 피드, Space 필터, 좋아요.  
  - `Map/`: 위치 기반 뷰.  
  - `MyPage/`: 프로필/닉네임/정책/탈퇴.  
  - `MainTabBarController`: 캘린더·피드·지도·마이페이지 탭 구성.
- `Resources/`: 에셋, `Secrets.swift`(API baseURL), `GoogleService-Info.plist`.
- `Support/`: `Info.plist`, 프로젝트 설정 파일.

## 주요 플로우 요약
- **앱 진입** (`SceneDelegate`): 액세스 토큰 확인 → 없으면 `SignUpViewController`, 있으면 `/api/v1/space/my-space` 조회 후 Space가 없으면 `SpaceSelectViewController`, 있으면 메인 탭으로 진입.
- **네트워크 공통** (`NetworkManager`): 모든 요청에 대해 401 발생 시 refresh → 성공 시 재시도, 실패 시 `onRequireReauthentication` 콜백으로 로그인 화면 전환.
- **미션 업로드** (`CalendarViewController` + `SpaceRepository`): 촬영/앨범 → 메타데이터 추출/Realm 저장 → `/upload` 프리사인드 URL 획득 → S3 업로드 → `/submit`으로 미션 제출 및 공개 여부 설정.
- **프로필 변경** (`MyPageViewController`): 프리사인드 URL 발급 → 이미지 업로드 → 프로필 업데이트 → Kingfisher 캐시 갱신.

## 환경 설정
- API 엔드포인트는 `Resources/Secrets.swift`의 `baseURL`에서 관리. 환경에 맞게 수정. (`Secrets.baseURL = "https://..."`)
- Firebase: `GoogleService-Info.plist`가 포함되어 있으며, 다른 프로젝트를 사용할 경우 교체 필요.
- 백엔드 준비 전에는 `NetworkManager.requestDummy`/`requestRawDataDummy`를 활용해 더미 응답을 사용할 수 있도록 구현됨.

## 포인트
- Rx 기반 플로우로 로그인→Space 선택→탭 전환까지 비동기 체인을 단순화.
- 토큰 리프레시와 재시도, 재인증 콜백을 `NetworkManager`와 `SceneDelegate`에서 일원화해 사용자 경험을 매끄럽게 유지.
- 워터폴 피드, 캘린더 미션, 프로필 업로드 등 다양한 미디어/네트워크/스토리지 시나리오를 직접 설계.
- 로컬 Realm 캐시로 촬영 메타데이터 보존 → 업로드 실패 시 복구 여지 확보.
- OSLog 기반 카테고리 로그(`Auth`, `Network`, `UI`, `General`)로 문제 추적성 향상.

## 향후 개선 아이디어
- 단위/통합 테스트 추가 (네트워크 목킹, ViewModel 단위 테스트).
- 지도 탭에서 위치 기반 미션/피드 데이터 시각화 고도화.
- 오프라인 업로드 재시도 큐 및 백그라운드 전송 지원.
- 접근성(A11y) 라벨, 동적 폰트 대응 강화.
