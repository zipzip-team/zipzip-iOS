# 집집(zipzip) 기기(Device) 백필 가이드

> **대상**: 이 기능을 이어받거나 데이터를 갱신할 팀원
> **목표**: 사진의 EXIF에서 촬영 기기(제조사·모델)를 뽑아 `device` 테이블을 채우고 `photo.device_id`를 연결하는 과정 이해하기
> 스키마는 [`local-db-schema.md`](./local-db-schema.md), 장소 라벨링과의 대칭 구조는 [`place-labeling.md`](./place-labeling.md) 참고.

---

## 1. 배경

사진 import(`PhotoLibrarySyncService`) 단계에서는 좌표·크기·즐겨찾기 등 `PHAsset`에서 즉시 얻는 메타데이터만 기록한다. 촬영 기기 정보(제조사·모델)는 원본 이미지의 **EXIF/TIFF** 안에 들어 있어 파일 데이터를 읽어야 하고, iCloud에만 있는 사진은 네트워크로 원본을 받아와야 하므로 import 시점에 함께 처리하기엔 비싸다.

그래서 import는 **네트워크를 쓰지 않고 로컬 원본만** 읽는다.

- 로컬 원본이 있는 사진 → 그 자리에서 EXIF를 읽어 `device_id`까지 채운다.
- iCloud 전용(로컬에 없는) 사진 → 기기 판별을 **보류**하고 `device_id = NULL`("pending") 상태로만 저장한다.

이 보류분(`device_id IS NULL`)을 나중에 채우는 후처리 패스가 **device backfill**이다. 대량 라이브러리(수만 장 iCloud 사진)에서 import가 즉시 끝나고 계정/네트워크 에러 폭주를 피하기 위한 분리다.

## 2. 전체 흐름 (import → backfill)

```
[앱 실행 / 포그라운드 복귀]
        │
        ▼
PhotoSyncCoordinator.runSync()   ── task (foreground) ──────────────┐
   1) photoLibrarySync.syncIfNeeded()                               │
        · PHAsset 전체 스캔, 500장 청크                              │
        · EXIF는 로컬만 읽음(allowsNetwork:false)                    │
        · 로컬 사진 → device_id 채워 저장                            │
        · iCloud 전용 → device_id=NULL(pending)로 저장              │
        · 끝나면 change token 저장(= 초기 import 완료)               │
   2) placeLabeling.labelPendingPhotos()  // 장소 라벨링             │
        │                                                           │
        └─ startBackfill()  ── backfillTask (priority: .utility) ───┘
                └─ deviceBackfill.backfillPendingDevices()
                     · device_id IS NULL 사진을 네트워크로 EXIF 채움
                     · UI를 막지 않고 백그라운드(앱 실행 중)에서 진행
```

- import(`task`)와 backfill(`backfillTask`)은 **별개 태스크**다. `isFinished`는 import+라벨링 시점에 true가 되고, backfill은 그 뒤로도 계속 돈다(UI 비차단).
- backfill 결과로 `device` 행과 `photo.device_id`가 채워지면, 등록 화면·갤러리에 해당 기기·사진이 **점진적으로** 나타난다.

## 3. 트리거 지점

진입점: [RootView.swift](../zipzip-iOS/zipzip-iOS/App/RootView.swift) — 앱 등장 시 `startIfNeeded()`, 포그라운드 복귀 시 `refresh()`. 둘 다 `runSync()`를 호출한다.

- `runSync()`는 `task == nil` 가드, `startBackfill()`은 `backfillTask == nil` 가드로 **중복 실행을 방지**한다. 각 태스크는 완료 시 `defer`로 자기 핸들을 `nil`로 되돌려 다음 트리거에서 재실행될 수 있다.
- 매 실행마다 backfill이 다시 붙으므로, 아직 남은 `device_id IS NULL` 사진을 **이어서** 처리한다(재개 가능).
- `CancellationError`는 조용히 무시하고, 그 외 에러만 로깅한다.

## 4. 백필 알고리즘 ([DeviceBackfillService](../zipzip-iOS/zipzip-iOS/Core/PhotoLibrary/DeviceBackfillService.swift))

```
backfillPendingDevices()   // @concurrent
  0) 사진 권한(authorized/limited) 확인 — 아니면 즉시 반환
  1) device_id IS NULL 사진의 (id, localIdentifier) 전부 스냅샷
  2) 100개(batchSize)씩 배치 처리
       a) 배치 asset들에서 EXIF 기기정보 추출 (resolve, 배치 내 4개씩 병렬)
       b) 새로 등장한 (make, model) 키 → device 행 find-or-create → deviceCache
       c) resolved된 사진의 photo.device_id 일괄 update
       d) 이번 배치에서 update 0건이면 emptyBatches++
             연속 3회(maxConsecutiveEmptyBatches, ≈300장) 실패 시 백오프 후 종료
```

핵심 규칙:

- **스냅샷 후 처리**: 배치 시작 전에 대상 목록을 한 번에 읽고 각 사진을 한 번씩만 처리한다. 실패로 남은 pending은 다음 실행에서 재조회되므로 무한 루프가 없다.
- **기기정보 없음도 삭제하지 않는다**: EXIF에 make/model이 전혀 없는 사진은 `(make:nil, model:nil)` 키의 **"미상" `device` 행에 배정**한다. 사진을 보존하면서 `device_id`가 채워져 pending에서 빠지므로(재시도 안 됨), 시간·장소·앨범 데이터도 유지된다.
  - 이 "미상" 기기는 [DetectedDeviceProvider](../zipzip-iOS/zipzip-iOS/Features/Onboarding/Service/DetectedDeviceProvider.swift)의 `hasDeviceInfo` 가드로 **기기 선택 목록에서 제외**된다 → 등록 불가 → 갤러리에도 노출되지 않는다.

### 배치 내부 EXIF 추출 (`resolve`)

- `PHAsset.fetchAssets(withLocalIdentifiers:)`로 배치 asset을 한 번에 로드.
- 그 안에서 다시 **4개(maxConcurrent)씩** `withTaskGroup`으로 병렬 EXIF 읽기(네트워크 허용) → I/O·네트워크 대기를 겹쳐 처리.
- asset을 못 찾은 사진(삭제됨 등)은 `.pending`으로 남겨 다음 기회에 재시도.

### 기기 캐시 / find-or-create

- `DeviceKey(make, model)` 단위로 `device` 행을 재사용. 한 번 만든 id는 `deviceCache`에 담아 이후 배치에서 재조회하지 않는다.
- `deviceID(for:db:)`: `make`/`model`이 일치하는 `DeviceRecord`가 있으면 그 id, 없으면 insert 후 `lastInsertedRowID` 반환.

## 5. EXIF 파싱 ([AssetEXIFReader](../zipzip-iOS/zipzip-iOS/Core/PhotoLibrary/AssetEXIFReader.swift))

`deviceInfo(for:allowsNetwork:)` — import는 `allowsNetwork:false`(로컬만), backfill은 `true`(iCloud 다운로드 허용). 결과 `AssetDeviceInfo`는 두 상태:

- `.resolved(make:model:)` — 판정 완료(기기정보 없으면 값이 `nil`).
- `.pending` — 리소스 접근 실패(로컬에 없음/네트워크 오류 등)로 **보류**. 다음 실행에서 재시도.

핵심은 **원본 전체를 받지 않고 앞부분만 스트리밍**해 EXIF 헤더만 확보하는 것:

```
사진 1장 판정
  ├─ 스크린샷?            → .resolved(nil, nil)   (스트리밍 안 함)
  ├─ 사진 리소스 없음?     → .resolved(nil, nil)
  └─ PHAssetResourceManager.requestData 스트리밍
        · 청크가 쌓이며 파싱 임계값(128KB→256KB→…, 2배씩) 도달 시에만 파싱
        ├─ TIFF Make/Model 발견 → 즉시 requestData 취소 → .resolved(make, model)
        ├─ 상한 2MB까지 못 찾음   → .resolved(nil, nil)
        └─ 스트림 완료
              ├─ error 있음      → .pending   (백필 재시도 대상)
              └─ error 없음      → 마지막 파싱으로 확정
```

- 파싱 임계값을 실패할 때마다 2배로 늘려(`reachedParseThreshold`) 콜백마다 전체 버퍼를 재파싱하지 않는다.
- `ResourceStreamBox`는 스트리밍 콜백(스레드 경합)과 취소를 `NSLock`으로 감싼 `@unchecked Sendable` 버퍼로, `finish`가 continuation을 정확히 한 번만 재개하도록 보장한다.

## 6. 예상 소요 시간

backfill은 **`device_id IS NULL`(= iCloud 전용) 사진 수**에 비례한다. 로컬 원본이 있던 사진은 import에서 이미 처리돼 대상이 아니다.

한 장당 실효 시간은 **iCloud 요청 왕복 + EXIF 헤더(≈128KB~수백 KB) 다운로드**가 지배한다. 동시성은 4(배치 내 병렬)이므로 처리량 ≈ `4 / (장당 지연)`.

| iCloud 전용 사진 수 | 빠름(≈0.3s/장) | 보통(≈0.5s/장) | 느림(≈1.0s/장) |
| ---: | ---: | ---: | ---: |
| 1,000 | ~1분 | ~2분 | ~4분 |
| 5,000 | ~6분 | ~10분 | ~21분 |
| 10,000 | ~13분 | ~21분 | ~42분 |
| 34,000 | ~43분 | ~71분 | ~2.4시간 |

> 계산식: 소요 ≈ `사진수 × 장당지연 ÷ 4`. 장당 지연은 네트워크·iCloud 응답 상태에 크게 좌우되는 **추정치**다.

시간에 영향을 주는 요소:

- **앱 실행 중에만 진행**한다(백그라운드 `BGTaskScheduler` 미사용). 앱을 닫으면 멈추고 다음 실행에서 이어간다 → **실제 벽시계 완료까지는 여러 세션에 걸칠 수 있다**. 위 표는 "앱을 계속 켜둔" 순수 처리 시간이다.
- **백오프**: iCloud/계정 오류로 연속 300장이 전부 실패하면 그 실행은 중단하고 다음 실행에서 재시도한다(무한 다운로드 방지).
- **데이터 사용량**: 대략 `사진수 × 128KB~300KB`. 34,000장이면 누적 ~4~10GB 수준. Wi‑Fi 권장(현재 회선 구분 없음 — [향후 개선](#8-설계-포인트--트레이드오프) 후보).

## 7. 관련 스키마

| 테이블 | 컬럼 | 비고 |
| --- | --- | --- |
| [`device`](../zipzip-iOS/zipzip-iOS/Core/Database/Schema/DeviceRecord.swift) | `id`, `make?`, `model?`, `is_registered` | (make, model) 조합당 1행. `make/model` 모두 nil인 "미상" 행 포함. `is_registered`는 사용자가 "내 기기"로 등록했는지 |
| [`photo`](../zipzip-iOS/zipzip-iOS/Core/Database/Schema/PhotoRecord.swift) | `device_id?` | 백필 대상 = `device_id IS NULL`. 채워지면 대상에서 빠짐 |

## 8. 설계 포인트 / 트레이드오프

- **재개 가능**: 대상이 `device_id IS NULL`뿐이라, 중단·재실행해도 못 끝낸 사진부터 이어서 처리한다.
- **비용 최소화**: EXIF 헤더만 스트리밍하고 찾는 즉시 다운로드를 끊어, iCloud 원본을 통째로 받지 않는다.
- **파괴적이지 않음**: 기기정보가 없어도 사진을 지우지 않고 "미상" 기기로 보존한다(선택 목록·갤러리에서만 숨김).
- **백오프**: 연속 3배치(≈300장)가 전부 실패하면 종료해 권한/네트워크 문제로 무한히 iCloud를 긁는 상황을 막는다. 다음 앱 실행에서 다시 시도.
- **에러 격리**: asset을 못 찾거나 스트림이 실패한 사진은 `.pending`으로 남고, 배치의 나머지 처리는 계속된다.
- **동시성 상한**: 배치 100 / 배치 내 병렬 4로 메모리·네트워크 부하를 제한한다.
- **한계 / 향후 개선**: 앱 실행 중에만 진행(백그라운드 태스크 미사용). 회선 구분이 없어 셀룰러에서도 받는다 → **Wi‑Fi 전용 게이팅(NWPathMonitor)** 이 다음 후보.

## 9. 관찰 / 검증

- 로그: `subsystem=com.zipzip.zipzip-iOS category=DeviceBackfill` (백오프 시 "backing off after repeated failures").
- 기기별 분포: `SELECT make, model, COUNT(*) FROM photo JOIN device ON device_id = device.id GROUP BY device_id`.
- 미처리 잔량(진행 확인): `SELECT COUNT(*) FROM photo WHERE device_id IS NULL` — 값이 줄어들면 정상 진행.
