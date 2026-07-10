# local-db-schema

# 집집(zipzip) 로컬 DB 설계

> **스택**: SQLiteData (GRDB 기반) · iOS
**구성**: 로컬 원본 테이블 / 조인 테이블 / 서버 수신 테이블
> 

---

## 1. 설계 원칙 (Key Decisions)

| 결정 | 내용 | 이유 |
| --- | --- | --- |
| PK 타입 분리 | 로컬 테이블 `Int64`, 서버 수신 테이블은 서버가 준 bigint(INTEGER) 유지 | 로컬은 조인·인덱스 성능, 서버는 동기화 일치 |
| 라벨 축 분리 | `label` 통합 대신 `device` / `place` **N:1 참조 테이블** | 두 축 모두 사진당 단일값(N:1). 필터 후보를 테이블 행으로 관리, sparse null 제거 |
| 원본 좌표 보존 | `photo.latitude/longitude`(원본) + `place`(파생 클러스터) 공존 | 반경 클러스터링 기준을 바꿔도 재계산 가능 |
| 로컬↔︎서버 매핑 | `content_hash`로 `photo` ↔︎ `shared_photo` 논리 연결 | 서버가 원본을 못 보는 구조에서 중복 판별·재다운로드 방지 |
| 물리 FK vs 논리 연결 | 실선 = 실제 FK, 점선 = 논리 연결(`content_hash`, `taken_at` 파생) | 파생/매핑에는 FK 제약을 걸지 않음 |
| 동기화 | PhotoKit change token(`sync_state`)으로 로컬 증분 동기화, 서버 테이블은 API로 수동 동기화 | SQLiteData의 CloudKit 자동 동기화 기능은 사용하지 않음 |
| 그리드 구동 | 사진 그리드/타임라인을 **SQLite 쿼리로 구동** (DB가 화면 source of truth) | `PHFetchResult` 대신 DB에서 정렬·필터·조인. 정렬/필터 컬럼을 DB에 저장 |
| 이미지 로딩 | 로컬 사진은 **참조만** 저장(`local_identifier`) → `PHCachingImageManager`로 로드 | PhotoKit 원본 경로는 불안정(일시적·시스템 소유·iCloud)이라 저장 불가. 파일 캐싱 대신 PhotoKit 내장 프리페치 사용 |
| 파생 저장 지양 | 쿼리로 만들 수 있는 값(대표 썸네일, 촬영 캘린더, 카운트)은 컬럼으로 두지 않음 | 조기 최적화·동기화 부담 회피. 수동 오버라이드나 실측 성능 문제일 때만 저장 |

### 그리드 SQLite 구동에 따른 의무

- **인덱스 필수** — `photo.taken_at`, `photo.added_at`, `photo.device_id`, `photo.place_id`, `photo.is_favorite`, `album_photo(album_id, added_at)`
  - 서버 수신 테이블의 FK 컬럼(`shared_album.shared_group_id`, `shared_photo.shared_album_id`)도 CASCADE 삭제·조인 성능을 위해 인덱스를 둔다.
  - `photo.content_hash` — 시나리오 3의 로컬↔︎서버 매칭(EXISTS) 조회용.
- **DB ↔︎ PhotoKit 동기화** — DB가 화면 source of truth이므로, Photos 앱에서의 즐겨찾기·삭제·편집을 `PHPhotoLibraryChangeObserver` + `sync_state.change_token`으로 DB에 반영해야 함 (특히 `is_favorite` 최신화 책임을 DB가 짐)
- **이미지 경로 컬럼 없음** — 로컬 `photo`에는 파일 경로/썸네일 경로를 두지 않음 (참조 방식). 경로 저장은 **서버에서 다운로드한 `shared_photo`에만** 해당(추후)

---

## 2. 테이블 정의

### 🟦 로컬 원본 · 참조 테이블

#### `photo` — 사진 메타데이터

| 논리명 | 물리명 | Type | 제약 | 설명 |
| --- | --- | --- | --- | --- |
| 사진 ID | `id` | INTEGER | PK | 로컬 기본키 |
| PhotoKit 식별자 | `local_identifier` | TEXT | UNIQUE | `PHAsset.localIdentifier` |
| 콘텐츠 해시 | `content_hash` | TEXT |  | 중복 판별·서버 매핑 키 |
| 촬영 일시 | `taken_at` | INTEGER | NULL | 촬영 시각, unix epoch 초 (정렬 축) |
| 추가 일시 | `added_at` | INTEGER | NOT NULL | 라이브러리 추가 시각 (정렬·증분 동기화 축) |
| 즐겨찾기 | `is_favorite` | INTEGER | NOT NULL DEFAULT 0 | 0/1 |
| 위도 | `latitude` | REAL | NULL | 원본 좌표 (GPS 없으면 NULL) |
| 경도 | `longitude` | REAL | NULL | 원본 좌표 |
| 가로 | `width` | INTEGER |  | 그리드 비율 예약 |
| 세로 | `height` | INTEGER |  | 그리드 비율 예약 |
| 기기 ID | `device_id` | INTEGER | FK→device, NULL | 촬영 기기 |
| 장소 ID | `place_id` | INTEGER | FK→place, NULL | 소속 클러스터 |

#### `album` — 사진집

| 논리명 | 물리명 | Type | 제약 | 설명 |
| --- | --- | --- | --- | --- |
| 앨범 ID | `id` | INTEGER | PK |  |
| 이름 | `name` | TEXT |  |  |
| 생성 일시 | `created_at` | INTEGER |  | 사진집 created date |

> 대표 썸네일은 `album_photo.added_at` 최신 3개로 **파생**(컬럼 없음). MVP는 앨범 수동 정렬·대표 지정 없음.
> 

#### `album_photo` — 앨범-사진 조인 (M:N)

| 논리명 | 물리명 | Type | 제약 | 설명 |
| --- | --- | --- | --- | --- |
| 앨범 ID | `album_id` | INTEGER | PK, FK→album |  |
| 사진 ID | `photo_id` | INTEGER | PK, FK→photo |  |
| 추가 일시 | `added_at` | INTEGER |  | added date — 최신순 썸네일 3개 정렬 키 |

> **복합 PK** `(album_id, photo_id)` · MVP는 앨범 내 수동 정렬 없음(`sort_order` 미도입)
> 

#### `device` — 기기 (필터 축)

| 논리명 | 물리명 | Type | 제약 | 설명 |
| --- | --- | --- | --- | --- |
| 기기 ID | `id` | INTEGER | PK |  |
| 제조사 | `make` | TEXT |  | EXIF Make |
| 모델 | `model` | TEXT |  | EXIF Model |

> `os_version` 제외(같은 기기가 OS 버전마다 다른 행으로 쪼개짐). `photo_count`는 `COUNT(*) GROUP BY device_id`로 **파생** → 실측 성능 문제 시에만 캐시 컬럼 도입.
> 

#### `place` — 장소 (필터 축)

| 논리명 | 물리명 | Type | 제약 | 설명 |
| --- | --- | --- | --- | --- |
| 장소 ID | `id` | INTEGER | PK |  |
| 이름 | `name` | TEXT |  | 역지오코딩 지명 |
| 위도 | `latitude` | REAL |  | 클러스터 중심 좌표 |
| 경도 | `longitude` | REAL |  | 클러스터 중심 좌표 |

#### `date` — 촬영 캘린더 (MVP: 테이블 미생성, 파생 쿼리)

`photo.taken_at`에서 파생. MVP에서는 별도 테이블 없이 `taken_at` 인덱스 기반 쿼리/뷰로 처리한다.

```sql
SELECT DISTINCT date(taken_at, 'unixepoch', 'localtime') AS day FROM photo;
```

캘린더 성능이 문제가 되면 그때 `day`(PK) 캐시 테이블로 materialize (행 존재 = 사진 있음 → `has_photos` 불필요, 장수 뱃지 필요 시 `photo_count` 추가).

#### `sync_state` — 동기화 상태

| 논리명 | 물리명 | Type | 제약 | 설명 |
| --- | --- | --- | --- | --- |
| ID | `id` | INTEGER | PK |  |
| 변경 토큰 | `change_token` | TEXT |  | PhotoKit change token (증분 동기화 기준) |

### 🟩 서버 수신 테이블

#### `shared_group` — 공유 그룹

| 논리명 | 물리명 | Type | 제약 | 설명 |
| --- | --- | --- | --- | --- |
| 그룹 ID | `id` | INTEGER | PK | 서버 값 |
| 생성자 ID | `created_by_user_id` | INTEGER |  |  |
| 이름 | `name` | TEXT |  |  |
| 초대 코드 | `invite_code` | TEXT | UNIQUE |  |
| 생성 일시 | `created_at` | INTEGER |  |  |

#### `shared_album` — 공유집

| 논리명 | 물리명 | Type | 제약 | 설명 |
| --- | --- | --- | --- | --- |
| 공유집 ID | `id` | INTEGER | PK | 서버 값 |
| 그룹 ID | `shared_group_id` | INTEGER | FK→shared_group |  |
| 이름 | `name` | TEXT |  |  |

#### `shared_photo` — 공유 사진

| 논리명 | 물리명 | Type | 제약 | 설명 |
| --- | --- | --- | --- | --- |
| 공유 사진 ID | `id` | INTEGER | PK | 서버 값 |
| 공유집 ID | `shared_album_id` | INTEGER | FK→shared_album |  |
| 콘텐츠 해시 | `content_hash` | TEXT |  | 로컬 `photo`와 매핑 |
| 원본 파일명 | `original_file_name` | TEXT |  |  |

---

## 3. 관계 (Relationships)

| 관계 | 종류 | 표기 | 비고 |
| --- | --- | --- | --- |
| `album` — `album_photo` — `photo` | M:N | 실선 | 조인 테이블 경유 |
| `device` → `photo` | 1:∞ | 실선 | 사진의 촬영 기기 |
| `place` → `photo` | 1:∞ | 실선 | 사진의 소속 클러스터 |
| `photo` ↔︎ `shared_photo` | 논리 | 점선 | `content_hash` 매칭 |
| `date` ↔︎ `photo` | 논리 | 점선 | `taken_at` 일자 집계(파생) |
| `shared_group` → `shared_album` → `shared_photo` | 1:∞ | 실선 | 서버 계층 |
| `sync_state` | 독립 | — | 라이브러리 전체 추적 |

> **`content_hash` 매칭 규칙** (`photo` ↔︎ `shared_photo`, 둘 다 nullable·non-unique)
> - **NULL 제외**: `content_hash IS NULL`(해시 미계산·계산 불가)인 행은 양쪽 어디서든 매칭 대상에서 제외한다.
> - **중복 허용**: 동일 콘텐츠가 여러 장일 수 있어 같은 non-null 해시가 여러 `photo`에 존재할 수 있다. 매칭은 **존재 여부(EXISTS)** 로 판정하며(있으면 "이미 가진 사진"), 단일 연결이 필요하면 결정적 규칙(예: 최소 `photo.id`)으로 대표를 고른다. `content_hash`에는 UNIQUE 제약을 걸지 않는다.
> - **Fallback**: `shared_photo.content_hash`가 NULL이거나 로컬에 매칭이 없으면 **새로 받을 사진**으로 취급한다. 로컬 `photo.content_hash`가 아직 없으면 매칭을 **유보(pending)** 하고 해시 계산 후 재판정한다.

---

## 4. 추후 고려 (Backlog)

- **E2EE** — 이번 범위 제외. 도입 시: 민감 컬럼(위치 등) 암호화 blob + 평문 인덱스 컬럼 분리, 키는 Keychain, `shared_photo`에 복호화 메타(iv 등)
- **`shared_photo` 로컬 부기** — 다운로드 필요 시 `local_file_path`(앱 샌드박스 경로 — PhotoKit에 없는 내 파일이라 경로 저장이 정당함), `download_state`, `local_photo_id`(content_hash 매칭 캐시), 크기·타입 컬럼 추가
- **`photo` 추가 컬럼** — `asset_type`(image/video/livePhoto), `created_at`/`updated_at`/`deleted_at`, `file_size`, `duration`
- **개방형 태그** — 사물/인물 등 ML 라벨이 필요해지면 별도 `tag` + `photo_tag`(M:N)로 추가 (device/place와 분리)
- **날짜 집계** — `date.has_photos`를 `photo_count`로 대체 검토 (달력 장수 뱃지)