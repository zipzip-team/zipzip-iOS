# local-db-decisions

# 집집(zipzip) 로컬 DB 설계 결정 기록

> 스키마 정의는 [`local-db-schema.md`](./local-db-schema.md) 참고.
이 문서는 **각 결정의 배경과 근거(왜 이렇게 했는가)** 를 정리한다.
> 

---

## 결정 1. 라벨을 `device` / `place`로 분리

**결정**: 통합 `label` + `photo_label`(M:N) 대신, `device`·`place` **N:1 참조 테이블**로 분리.

**근거**
- 기기·장소는 사진당 단일값 → 실제 관계가 **M:N이 아니라 N:1**. 조인 테이블은 과설계.
- 두 축은 공유 컬럼이 거의 없음(기기: model/os, 장소: name/lat/lng) → 한 테이블에 담으면 **nullable 범벅(sparse table)**.
- 사진마다 “iPhone 15 Pro” 문자열 반복 저장 대신, 참조 테이블로 정규화.

## 결정 2. 필터링 때문에 오히려 분리가 유리

**맥락**: “앱에서 라벨로 필터링하니 라벨이 필요하다”는 요구.

**근거**
- 필터 UI(`[기기 ▾] [장소 ▾]`)의 **후보 목록 = 참조 테이블의 행**. `SELECT * FROM device` / `place`로 바로 채움.
- 실제 필터는 `photo`의 FK 조회 → `WHERE device_id=? AND place_id=?` (인덱스로 빠름).
- 통합 구조였다면 “기기 AND 장소”에 `photo_label`을 `type` 구분해 **이중 조인**해야 함 → 더 복잡.

→ 필터링을 하기 때문에 **축별로 테이블 분리**하는 게 맞다.

## 결정 3. 원본 좌표(`latitude`/`longitude`)를 `photo`에 보존

**결정**: `photo`에 원본 좌표 저장 + `place`(클러스터)와 공존.

**근거**
- `place_id`(클러스터 결과)만 저장하면, 반경 기준을 바꿀 때 **원본 좌표가 없어 재클러스터링 불가**.
- 역할 분리:
- `photo.latitude/longitude` → **불변 원본(source of truth)**
- `place` → 좌표를 반경으로 묶은 **파생 결과**
- `photo.place_id` → 현재 클러스터 배정(언제든 재계산 가능)

## 결정 4. `width`/`height`, `added_at`의 진짜 용도

**핵심**: “보여주려고”가 아니라 **배치·정렬을 위해** 필요.

- **`width`/`height`** — 정보 표시가 아니라 **그리드 레이아웃**. 이미지를 로드하기 전에 셀 비율을 확정해야 스크롤 중 **레이아웃 튐(reflow)** 이 없다.
- **`added_at`** — 촬영일(`taken_at`)과 **다른 축**. 오래된 사진을 나중에 가져오면 촬영일은 과거지만 추가일은 현재. “최근 추가” 타임라인·**증분 동기화 기준선**이 된다.

## 결정 5. 그리드는 SQLite 쿼리로 구동

**선택지**
- (A) **SQLite 쿼리로 구동** — `SELECT ... FROM photo ORDER BY ...` 결과로 셀 구성, 이미지는 `local_identifier`로 로드
- (B) `PHFetchResult`로 구동 — PhotoKit 정렬 목록을 그대로 사용, DB는 라벨·앨범·해시만 보관

**결정**: **(A) 채택.** 메타데이터와 이미지 참조를 DB에 저장해 DB로 그리드를 구동.

**따라오는 의무**
- **인덱스**: `taken_at`, `added_at`, `device_id`, `place_id`, `is_favorite`, `album_photo(album_id, added_at)`
- **DB ↔︎ PhotoKit 동기화**: DB가 화면 source of truth이므로 Photos 앱의 즐겨찾기·삭제·편집을 `PHPhotoLibraryChangeObserver` + `change_token`으로 DB에 반영해야 함.

## 결정 6. DB 저장 여부 판단 기준

컬럼을 DB에 저장할 이유는 둘 중 하나여야 한다.

1. **내가 SQL로 정렬·필터·그룹·조인하는 값** (PhotoKit으로는 복잡 쿼리·조인 불가)
2. **PhotoKit이 안 주는 값** (`content_hash`, 기기·장소 그룹핑 등)

→ “PHAsset이 이미 주고, 상세 화면에서 한 장씩 보여주기만 하는 값”은 저장하지 말고 `local_identifier`로 그때그때 읽는다. **단, (A) 그리드 구동을 택했으므로 정렬·레이아웃에 쓰는 값들은 저장 대상이 됨.**

### 컬럼별 판단 (photo)

| 컬럼 | 용도 | PhotoKit 제공 | 결론 |
| --- | --- | --- | --- |
| `id` | 로컬 PK | — | 저장 |
| `local_identifier` | PHAsset 재조회(이미지 로드) 브리지 | 키 | 저장 |
| `content_hash` | 중복 판별·서버 매핑 | ❌ | 저장 |
| `device_id`/`place_id` | 필터(그룹핑은 내 계산) | ❌ | 저장 |
| `added_at` | 증분 동기화·최근 추가순 | ❌ | 저장 |
| `taken_at` | 타임라인 정렬·date 집계 | ✅ | 저장 (A 구동) |
| `latitude`/`longitude` | place 클러스터링·지도 | ✅ | 저장 (DB 클러스터링) |
| `width`/`height` | 그리드 셀 비율 예약 | ✅ | 저장 (A 구동) |
| `is_favorite` | 즐겨찾기 필터·표시 | ✅ | 저장 (동기화로 최신화 책임) |

## 결정 7. 이미지 로딩은 참조 방식 (경로 저장 안 함)

**결정**: 로컬 사진은 `local_identifier`만 저장하고 `PHCachingImageManager`로 로드. **파일 경로/썸네일 경로 컬럼 없음.**

**근거 — PhotoKit 원본 경로는 저장 불가**
- PHAsset은 안정적인 파일 URL을 공개 API로 주지 않음. 얻을 수 있는 URL은:
- **일시적** (다음 실행에서 경로 보장 안 됨)
- **시스템 Photos 라이브러리 내부** (앱 소유 아님)
- 사진이 **iCloud에만** 있을 수 있음
- Apple 원칙: `localIdentifier`를 저장하고 매번 재-fetch → `PHImageManager`로 요청.

### “파일 캐싱”의 의미와 선택지

캐싱 = PhotoKit 밖으로 픽셀을 복사해 **앱 샌드박스에 저장**하고 그 경로를 DB에 저장하는 것.

| 방식 | DB 저장 | 특징 | 채택 |
| --- | --- | --- | --- |
| ① 참조만 | `local_identifier` | `PHCachingImageManager` 프리페치로 스크롤 처리 | ✅ |
| ② 썸네일 캐시 | 샌드박스 `thumbnail_path` | 콜드 스크롤 빠름, 캐시 관리 직접 | 미채택 |
| ③ 원본 캐시 | 샌드박스 경로 | 용량 2배 | 지양 |

**예외**: 서버에서 **다운로드한 `shared_photo`** 는 PhotoKit에 없는 내 파일 → 앱 샌드박스에 저장하고 **경로 컬럼(`local_file_path`)을 두는 게 정당**(추후 다운로드 기능 시).

## 결정 8. MVP 컬럼 확정 — 파생·미사용 컬럼 제거

1차 MVP 기능 범위에 맞춰, 파생 가능하거나 아직 쓰지 않는 컬럼을 제거한다.

| 대상 | 조치 | 근거 |
| --- | --- | --- |
| `album.sort_order` | 제거 | MVP에 앨범 수동 정렬 없음 |
| `album_photo.sort_order` | 제거 | 앨범 내 사진 수동 정렬 없음 |
| `album.cover_photo_id` | 제거 | 썸네일 = `album_photo.added_at` 최신 3개 **자동 파생** |
| `album.updated_at` | 제거 | 최근활동순 정렬 등 사용처 없음 |
| `device.os_version` | 제거 | OS 버전은 가변 → device 정체성을 쪼갬 (필터 축도 아님) |
| `device.photo_count` | 제거 | `COUNT(*) GROUP BY device_id`로 파생, 조기 최적화 회피 |
| `device.created_at` | 제거 | 사용처 낮음 |
| `date` 테이블 | **미생성** | `taken_at`에서 파생 쿼리/뷰로 시작, 성능 문제 시 `day` PK 캐시로 전환 |
| `place.country/city` | 보류 | 앨범 필터는 라벨 기반 예정, 도시 계층 필터는 라벨 저장 방식 확정 후 결정 |

→ 원칙: **파생 가능한 값은 저장하지 않는다. 수동 오버라이드 기능이 생기거나 실측 성능 문제가 있을 때만 컬럼화한다.**

---

## 미결 / 추후 결정

- `place` 도시/지역 계층 필터 — 라벨 저장 방식 확정 후 (`country`/`city` 도입 여부)
- `shared_photo` 다운로드 부기 컬럼(`local_file_path`, `download_state`, `local_photo_id`) 도입 시점
- E2EE 도입 시 암호화 대상 컬럼·키 관리 방식
- 개방형 ML 태그 필요 시 `tag` + `photo_tag`(M:N) 추가