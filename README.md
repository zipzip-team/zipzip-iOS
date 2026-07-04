# zipzip
> 메인폰 밖에서 촬영된 사진을 더 쉽게 찾고, 분류하고, 다시 볼 수 있도록 돕는 사진 정리 보조 서비스

## 🛠️ Library & Stack

### Language & UI
![Swift](https://img.shields.io/badge/Swift%205.0-F05138?style=for-the-badge&logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/SwiftUI-0071E3?style=for-the-badge&logo=swift&logoColor=white)

### Architecture
![MVVM](https://img.shields.io/badge/MVVM-6DB33F?style=for-the-badge)
![Clean Architecture](https://img.shields.io/badge/Clean%20Architecture-4B8BBE?style=for-the-badge)

### Data & State
![SwiftData](https://img.shields.io/badge/SwiftData-2396F3?style=for-the-badge&logo=apple&logoColor=white)
![Observation](https://img.shields.io/badge/Observation-FF7139?style=for-the-badge&logo=swift&logoColor=white)

### Network & Logging
![Alamofire](https://img.shields.io/badge/Alamofire-FF6C37?style=for-the-badge&logo=swift&logoColor=white)
![OSLog](https://img.shields.io/badge/OSLog-000000?style=for-the-badge&logo=apple&logoColor=white)

### Dependency Manager (via SPM)
![Swift Package Manager](https://img.shields.io/badge/Swift%20Package%20Manager-F05138?style=for-the-badge&logo=swift&logoColor=white)

### Collaboration
![Git](https://img.shields.io/badge/Git-F05032?style=for-the-badge&logo=git&logoColor=white)
![GitHub](https://img.shields.io/badge/GitHub-181717?style=for-the-badge&logo=github&logoColor=white)
![Figma](https://img.shields.io/badge/Figma-F24E1E?style=for-the-badge&logo=figma&logoColor=white)
![Notion](https://img.shields.io/badge/Notion-000000?style=for-the-badge&logo=notion&logoColor=white)

## 📣 Convention
### Branch
`태그/#이슈번호`
```
main ─────────────── 운영 배포본 (직접 push 금지)
dev ──────────── 통합 브랜치 / 스프린트 단위 관리
  └── feat/#1  개인 기능 개발 브랜치 (이슈 ID 기반)
hotfix/#2 ──── 긴급 버그 수정 (main에서 분기)
```

### Tag
| 태그 | 설명 | 예시 |
| --- | --- | --- |
| feat | 새로운 기능 추가 | `feat: 로그인 기능 추가` |
| fix | 버그 수정  | `fix: 로그인 예외 처리 버그 수정` |
| docs | README 등의 문서 수정 | `docs: API 명세 업데이트` |
| design | UI/UX 구현 | `design: 랜딩 뷰 구현` |
| refactor | 기능 변경 없이 코드 내부 구조 리팩토링 | `refactor: 로그인 처리 로직 리팩토링` |
| test | 단위 테스트 추가, 통합 테스트 추가, 테스트 코드 수정 | `test: 사용자 인증 로직 테스트 케이스 추가` |
| chore | 라이브러리 버전 수정, 패키지 관리 등 | `chore: 의존성 버전 업데이트` |
| comment | 주석 추가 / 수정 | `comment: 불필요한 주석 제거` |
| hotfix | 배포된 버전에서의 급한 버그 수정 | `hotfix: 서버 Timezone 설정 변경` |
| rename | 파일, 클래스 등의 이름 변경 | `rename: UserController → AuthController 변경` |
| remove | 파일, 클래스 등의 삭제 | `remove: 사용하지 않는 DTO 제거` |
| cicd | CI/CD 관련 설정 | `cicd: Github Actions workflow 추가` |
| add | 파일, 에셋 추가 | `add: 컬러 에셋 추가` |

### Commit Message
```
{태그}: 작업내용

feat: 업장 상세페이지 컴포넌트 사용하도록 수정 및 관리자 조회 API 추가
```
## 📁 Foldering
```
zipzip-iOS/
└── zipzip-iOS/
    │
    ├── App/                         # 앱 진입점 & 전역 설정
    │   ├── zipzip_iOSApp.swift      # @main, ModelContainer(SwiftData) 구성
    │   ├── Info.plist
    │   └── Navigation/              # 화면 전환(라우팅)
    │       ├── Route.swift          # 화면 경로 정의(enum)
    │       └── Router.swift         # @Observable, NavigationPath 관리 (push/pop/popToRoot)
    │
    ├── Core/                        # 앱 전반에서 재사용되는 핵심 인프라
    │   ├── DI/
    │   │   └── DIContainer.swift    # 의존성 주입 컨테이너 (ViewModel 팩토리)
    │   ├── Network/                 # 네트워크 레이어 (Alamofire)
    │   │   ├── APIConfig.swift      # 서버/환경 설정
    │   │   ├── APIEndpoint.swift    # 엔드포인트 정의
    │   │   ├── NetworkProvider.swift# 요청 실행 프로토콜 & 구현
    │   │   ├── NetworkError.swift   # 네트워크 에러 타입
    │   │   └── NetworkLogger.swift  # 디버깅용 요청/응답 로거 (EventMonitor)
    │   ├── Repository/              # 데이터 영속화 추상화 (SwiftData 구현)
    │   ├── Service/                 # 비즈니스 로직 (Repository 조합)
    │   └── Extensions/              # 공용 확장 (현재 비어있음)
    │
    ├── Features/                    # 기능(화면) 단위 모듈
    │   └── Home/
    │       ├── Model/               # SwiftData @Model 엔티티
    │       ├── ViewModel/           # @Observable, Service 호출
    │       └── View/
    │
    ├── Shared/                      # 여러 Feature가 공유하는 요소
    │   ├── Component/               # 공용 UI 컴포넌트
    │   └── Model/                   # 공용 모델
    │
    └── Resources/                   # 에셋 & 리소스
        └── Assets.xcassets/         # AppIcon, AccentColor
```
