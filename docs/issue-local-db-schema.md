# [feat] SQLiteData 기반 로컬 DB 스키마 구축

## 📝 기능 설명

로컬 사진 데이터를 다루기 위한 **SQLiteData(GRDB) 기반 로컬 DB 스키마**를 구축합니다.

사진 그리드/타임라인을 SQLite 쿼리로 구동하므로, 정렬·필터에 필요한 메타데이터를 로컬 DB에 저장합니다. 이번 작업은 이후 저장/조회·동기화 기능이 올라탈 **스키마 토대**를 마련하는 것이 목적입니다.

- 스키마 정의: `docs/local-db-schema.md`
- 설계 근거: `docs/local-db-decisions.md`
- 데이터 흐름: `docs/db-data-flow.md`

## ✅ 할 일

- [x] SQLiteData 셋업 및 마이그레이션 구성
- [x] photo 테이블 생성
- [x] device 테이블 생성
- [x] place 테이블 생성
- [x] album 테이블 생성
- [x] album_photo 테이블 생성
- [x] sync_state 테이블 생성
- [x] shared_group 테이블 생성
- [x] shared_album 테이블 생성
- [x] shared_photo 테이블 생성
- [x] 인덱스 설정

## 👀 기타 사항 (선택사항)

- 동기화·서버 데이터 저장 로직은 별도 이슈로 진행
- date 테이블은 생성하지 않음 (taken_at 파생 쿼리로 처리)
- 이미지는 local_identifier 참조만 저장 (파일 경로 저장 X)
