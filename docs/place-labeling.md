# place-labeling

# 집집(zipzip) 사진 장소 라벨링 가이드

> **대상**: 이 기능을 이어받거나 데이터를 갱신할 팀원
> **목표**: 사진 좌표가 어떻게 "서울 강남구" 같은 장소 라벨이 되는지, 왜 오프라인 방식인지 이해하기
> 스키마는 [`local-db-schema.md`](./local-db-schema.md), 설계 근거는 [`local-db-decisions.md`](./local-db-decisions.md) 참고.

---

## 1. 배경

사진에는 촬영 시 GPS 좌표(`photo.latitude/longitude`)가 이미 저장된다([AssetMetadata](../zipzip-iOS/zipzip-iOS/Core/PhotoLibrary/AssetMetadata.swift)에서 `PHAsset.location`을 기록). 하지만 이 좌표를 사람이 읽을 장소명으로 바꾸는 단계가 없어, `place` 테이블은 비어 있고 사진 뷰의 장소 표기·장소 필터가 동작하지 않았다.

이 기능은 좌표를 **행정구역 라벨**(국내) 또는 **국가명**(해외)으로 변환해 `place` 행을 만들고 `photo.place_id`를 채운다.

## 2. 라벨링 규칙

- **해외**: 한국어 국가명 하나로 묶음 — "일본", "미국".
- **국내**: 시명은 축약해서 표기.
  1. 구가 있으면 → `<시축약> <구>` — "서울 강남구", "성남시 분당구"
  2. 구가 없고 동이 있으면 → `<시축약> <동>` — "춘천시 소양동"
  3. 동이 없으면(군 지역) → `<군> <읍/면>` — "양평군 양평읍"

## 3. 왜 오프라인인가 (핵심 결정)

처음엔 Apple 역지오코딩(`CLGeocoder` → iOS 26 deprecation으로 `MKReverseGeocodingRequest`)을 썼으나, **서버 스로틀(역지오코딩 60초당 50건, `GEOErrorDomain -3`)** 에 걸려 대용량 라이브러리 라벨링이 실패했다. 문제 해결 과정은 [`place-labeling-troubleshooting`](https://www.notion.so) 참고.

**결론: 온라인 지오코딩을 버리고, 행정구역 경계 폴리곤을 앱에 번들해 좌표가 어느 구역에 속하는지 로컬에서 판정(point-in-polygon)한다.** 네트워크·쿼터·스로틀이 전부 사라지고 조회가 즉시 이뤄진다. → 되돌리지 말 것.

## 4. 데이터 흐름

```
PhotoSyncCoordinator.startIfNeeded()
  └─ 사진 import(PhotoLibrarySyncService) 완료 후
      └─ PlaceLabelingService.labelPendingPhotos()   // @concurrent, 앱 실행 중 1회 패스
           1) place_id 없고 좌표 있는 사진 조회
           2) 0.005°(~500m) 격자로 클러스터링 (조회·DB쓰기 중복 제거)
           3) 클러스터마다 LocalReverseGeocoder로 라벨 조회
           4) place find-or-create → 클러스터의 사진들 place_id 일괄 update
```

- `place_id == nil`만 대상 → 앱을 다시 켜면 못한 사진부터 재개.
- 클러스터 하나가 실패해도 건너뛰고 나머지를 계속 처리(에러 격리).
- 진행 로그: `subsystem=com.zipzip.zipzip-iOS category=PlaceLabeling`.

## 5. 번들 데이터 (Resources/Geo, 총 ~1.9MB)

| 파일 | 출처 | 내용 | 크기 |
| --- | --- | --- | --- |
| `HangJeongDong.geojson` | [vuski/admdongkor](https://github.com/vuski/admdongkor) | 행정동 경계(국내), 속성 `adm_nm`("시도 시군구 행정동") | ~1.74MB |
| `Countries.geojson` | [Natural Earth 110m](https://github.com/nvkelso/natural-earth-vector) | 국가경계(해외), 속성 `NAME_KO`, **한국 제외** | ~0.17MB |

- 한국(KR)을 국가경계에서 뺀 이유: 국내 좌표가 행정동 폴리곤 틈새에 빠졌을 때 "대한민국"으로 잘못 라벨되지 않고 미라벨로 남게 하려고.
- `Resources`는 Xcode synchronized root group이라 폴더에 파일만 넣으면 자동 번들된다(빌드 산출물에서 포함 확인).

### 데이터 재생성 (행정구역 통폐합 시)

vuski 최신 GeoJSON을 받아 mapshaper로 단순화·경량화한다:

```bash
# 국내
npx -y mapshaper HangJeongDong_verYYYYMMDD.geojson \
  -filter-fields adm_nm -simplify 6% keep-shapes -clean \
  -o precision=0.00005 HangJeongDong.geojson

# 해외 (한국 제외)
npx -y mapshaper ne_110m_admin_0_countries.geojson \
  -filter 'ISO_A2 !== "KR"' -filter-fields NAME_KO,ISO_A2 \
  -o precision=0.01 Countries.geojson
```

> 배포 전 vuski 데이터 라이선스 확인 필요.

## 6. 코드 구성

| 파일 | 역할 |
| --- | --- |
| [LocalReverseGeocoder.swift](../zipzip-iOS/zipzip-iOS/Core/PhotoLibrary/LocalReverseGeocoder.swift) | 번들 GeoJSON을 `MKGeoJSONDecoder`로 로드, bbox 프리필터 + ray-casting point-in-polygon. 국내→`adm_nm`, 해외→국가명. 외부 의존성 없음 |
| [PlaceLabelCatalog.swift](../zipzip-iOS/zipzip-iOS/Core/PhotoLibrary/PlaceLabelCatalog.swift) | `adm_nm` 문자열을 접미사(구/시/군/동/읍면)로 분류해 §2 규칙대로 라벨 조립 |
| [PlaceLabelingService.swift](../zipzip-iOS/zipzip-iOS/Core/PhotoLibrary/PlaceLabelingService.swift) | 라벨링 패스: 클러스터링·조회·`place` 생성·`place_id` 기록·진행 로그 |
| [PhotoSyncCoordinator.swift](../zipzip-iOS/zipzip-iOS/Core/PhotoLibrary/PhotoSyncCoordinator.swift) | import 완료 후 라벨링 트리거 |

읽기 측(`PhotoSectionsProvider`)은 `photo.place_id → place.name`을 조인해 화면 장소 문자열로 내보내고, `.location` 필터가 이 값으로 동작한다.

## 7. 트레이드오프 / 한계

- **정밀도**: 클러스터링 0.005°(~500m)라 사진↔대표점 최대 이격 ~355m. 구/동보다 작아 오라벨 위험 낮음. 경계 단순화(6%) 오차는 이보다 작아 무시 가능.
- **행정동 데이터는 읍/면/동까지** → 규칙 3의 "리"는 읍/면 레벨로 라벨된다(대부분 문제 없음).
- **실행 범위**: 앱 실행 중에만 진행(백그라운드 `BGTaskScheduler` 미사용). 초기 import 이후 새로 추가된 사진은 증분 동기화가 붙어야 라벨링 대상이 된다(별도 이슈).

## 8. 검증

- Python 참조 구현과 macOS `swift` 실행 양쪽에서 대표 좌표 확인: 서울 중구/서초구, 양평군 양평읍, 춘천시 소양동, 부산 해운대구, 제주시 이도2동, 일본, 미국 → 전부 정확.
- 실기기: 앱 실행 → `PlaceLabeling` 로그로 진행률 확인 → 사진 뷰 장소 표기·장소 필터가 실제 라벨로 채워지는지 확인.
