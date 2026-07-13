# Navigation 운영 정책

## 목적

SwiftUI가 하나의 navigation column에서 서로 다른 path element 타입을 비교하면서 발생하는
`SwiftUI.AnyNavigationPath.Error.comparisonTypeMismatch`를 예방한다. 이 문서는 앱 전역 화면 전환의
소유권, route 모델링, 탭 전환과 테스트 기준을 정의한다.

## 현재 구조

```text
RootView
└── NavigationStack(path: Router.path)       // 앱에서 유일한 path binding
    ├── 인증 플로우
    └── RootTabView
        ├── Main
        ├── Album
        ├── Picture
        ├── Share
        └── MyPage
```

- `RootView`가 유일한 `NavigationStack(path:)` 소유자다.
- `Router.path`는 하나의 homogeneous path인 `[Route]`다.
- 각 feature는 `Router`에 route 변경을 요청하고 자체 navigation path를 보유하지 않는다.
- destination 등록은 `RootView`의 `navigationDestination(for: Route.self)` 한 곳에서 한다.
- 탭은 선택된 화면만 렌더링한다. feature 상태는 상위에서 소유한 ViewModel로 보존한다.

## 필수 규칙

### 1. 하나의 navigation column에는 path 소유자가 하나만 있어야 한다

앱의 주 화면 전환은 `RootView`의 stack을 사용한다. feature 화면 아래에 다른 타입의
`NavigationStack(path:)`를 중첩하지 않는다. 특히 `opacity`, `ZStack` 등으로 숨긴 탭은 화면에서 보이지
않아도 view hierarchy에 남으므로 별도 stack을 함께 유지하면 안 된다.

독립적인 sheet가 내부에서 완결되는 별도 흐름이라면 자체 stack을 둘 수 있다. 이 경우에도 부모 stack과
동시에 같은 navigation column을 점유하지 않고, sheet 밖의 route를 변경하지 않아야 한다.

### 2. 전역 push는 `Route`로 표현한다

```swift
enum Route: Hashable {
    case shareGroup(UUID)
    case shareAlbum(groupID: UUID, albumID: Int)
}

router.push(.shareGroup(groupID))
```

일반적인 programmatic navigation, 딥 링크, 탭을 넘는 전환은 모두 `[Route]`에 기록한다.
단일 화면에서만 의미가 있고 복원할 필요가 없는 이진 상태는
`navigationDestination(isPresented:)`를 사용할 수 있지만, 전역 router와 같은 전환을 중복해서 표현하지
않는다.

### 3. route에는 가볍고 안정적인 식별자를 담는다

route는 화면 데이터 자체보다 `UUID`, 데이터베이스 ID 같은 식별자를 담고 destination에서 최신 데이터를
조회한다. 이렇게 해야 hash/equality가 화면 전환 중 바뀌지 않고 경로 복원과 딥 링크가 단순해진다.

현재 `photoDetail(Photo)`, `albumPhotoDetail(albumID:photo:)`,
`photoInfoEdit(metadata:localIdentifiers:)`는 기존 호환을 위한 예외다. 해당 흐름을 수정할 때 식별자 기반
route로 순차 이전한다.

### 4. path는 main actor에서 명령으로 변경한다

- push: `router.push(_:)`
- 한 단계 뒤로: `router.pop()`
- root로 복귀: `router.popToRoot()`
- 탭 전환이나 딥 링크처럼 새 경로로 이동: `router.replacePath(with:)`

SwiftUI의 `NavigationStack` binding을 제외한 application code는 `Router.path`를 직접 수정하지 않는다.
경로 중간의 특정 case만 `filter`로 제거하지 않는다. 유효한 prefix로 pop하거나 새 path 전체를 원자적으로
교체한다.

### 5. 탭 선택은 명시적인 전환 이벤트다

navbar는 `Binding<NavbarTab>`로 값을 직접 쓰지 않고 선택 callback을 전달한다. 탭 coordinator는 다음
순서로 전환을 처리한다.

1. 떠나는 feature의 일시적인 UI 상태를 정리한다.
2. `Router`의 path를 목적 탭에 맞는 전체 path로 교체한다.
3. 선택된 탭을 갱신한다.

숨겨진 탭 view를 캐시해 navigation stack까지 보존하지 않는다. 유지해야 하는 데이터는 ViewModel의
수명으로 보존한다.

### 6. ViewModel은 navigation state를 소유하지 않는다

ViewModel은 데이터와 비즈니스/UI 상태를 다룬다. `NavigationPath`, `[FeatureRoute]`, pop/push 메서드는
두지 않는다. 화면 이동이 필요한 작업은 성공 여부나 결과 값을 반환하고 View 또는 coordinator가
`Router`를 변경한다.

## 새 화면 추가 절차

1. `Route`에 식별자 중심 case를 추가한다.
2. `RootView.navigationDestination(for:)`에 destination을 연결한다.
3. 호출 화면에서 환경의 `Router`로 push한다.
4. navbar 표시 조건 등 route 분류가 필요하면 `Route`의 계산 프로퍼티를 갱신한다.
5. `NavigationArchitectureTests`와 관련 feature 테스트를 갱신한다.

## 회귀 방지 체크리스트

- `NavigationStack(path:)` 검색 결과가 `RootView` 하나뿐인가?
- 새 feature가 `NavigationPath` 또는 별도 route 배열을 만들지 않았는가?
- route associated value가 가볍고 안정적인 식별자인가?
- 탭 전환이 숨겨진 view cache가 아닌 ViewModel 상태 보존을 사용하는가?
- path를 중간 filtering하지 않고 suffix pop 또는 전체 교체하는가?
- push, pop, 탭 전환, 딥 링크 진입과 복귀를 테스트했는가?

## 장애 분석 기록

이번 장애는 상위 `[Route]` stack과 Share의 `[ShareRoute]` stack을 함께 유지한 상태에서, 캐시된 탭이
숨겨져도 hierarchy에 남아 SwiftUI가 서로 다른 path comparison type을 조정하려 한 것이 직접적인
트리거로 판단했다. 과거 동일 오류를 해결하며 단일 `[Route]`로 통합했던 구조가 Share 중첩 stack과 탭
cache 도입으로 다시 깨진 회귀였다.

수정은 Share route를 전역 `Route`로 합치고, path-bound stack을 `RootView` 하나로 제한하며, 탭 전환 시
전체 path를 교체하는 방식으로 적용했다. `NavigationArchitectureTests`가 이 불변식을 검사한다.

## 참고 자료

- [Apple: Understanding the composition of NavigationStack](https://developer.apple.com/documentation/swiftui/understanding-the-navigation-stack)
- [Apple: NavigationStack](https://developer.apple.com/documentation/swiftui/navigationstack)
- [Apple: navigationDestination(isPresented:destination:)](https://developer.apple.com/documentation/swiftui/view/navigationdestination%28ispresented%3Adestination%3A%29)
- [WWDC22: The SwiftUI cookbook for navigation](https://developer.apple.com/videos/play/wwdc2022/10054/)
