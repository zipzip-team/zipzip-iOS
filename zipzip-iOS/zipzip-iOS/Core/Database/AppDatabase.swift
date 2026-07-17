//
//  AppDatabase.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/10/26.
//

import Foundation
import OSLog
import SQLiteData

private let logger = Logger(subsystem: "com.zipzip.zipzip-iOS", category: "Database")

func prepareAppDependencies() {
    prepareDependencies {
        $0.defaultDatabase = try! appDatabase()
    }
}

func appDatabase() throws -> any DatabaseWriter {
    @Dependency(\.context) var context

    var configuration = Configuration()
    configuration.foreignKeysEnabled = true
    #if DEBUG
        configuration.prepareDatabase { db in
            db.trace(options: .profile) {
                if context == .preview {
                    print("\($0.expandedDescription)")
                } else {
                    logger.debug("\($0.expandedDescription)")
                }
            }
        }
    #endif

    let database = try defaultDatabase(configuration: configuration)
    logger.info("open \(database.path)")

    var migrator = DatabaseMigrator()
    #if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
    #endif

    migrator.registerMigration("Create tables") { db in
        try #sql(
            """
            CREATE TABLE "device"(
              "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
              "make" TEXT,
              "model" TEXT,
              "is_registered" INTEGER NOT NULL DEFAULT 0
            ) STRICT
            """
        )
        .execute(db)

        try #sql(
            """
            CREATE TABLE "place"(
              "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
              "name" TEXT NOT NULL,
              "latitude" REAL NOT NULL,
              "longitude" REAL NOT NULL
            ) STRICT
            """
        )
        .execute(db)

        try #sql(
            """
            CREATE TABLE "photo"(
              "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
              "local_identifier" TEXT NOT NULL UNIQUE,
              "content_hash" TEXT,
              "taken_at" INTEGER,
              "added_at" INTEGER NOT NULL,
              "added_date" INTEGER NOT NULL,
              "is_favorite" INTEGER NOT NULL DEFAULT 0,
              "latitude" REAL,
              "longitude" REAL,
              "width" INTEGER NOT NULL,
              "height" INTEGER NOT NULL,
              "device_id" INTEGER REFERENCES "device"("id"),
              "place_id" INTEGER REFERENCES "place"("id")
            ) STRICT
            """
        )
        .execute(db)

        try #sql(
            """
            CREATE TABLE "album"(
              "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
              "name" TEXT NOT NULL,
              "created_at" INTEGER NOT NULL
            ) STRICT
            """
        )
        .execute(db)

        try #sql(
            """
            CREATE TABLE "album_photo"(
              "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
              "album_id" INTEGER NOT NULL REFERENCES "album"("id") ON DELETE CASCADE,
              "photo_id" INTEGER NOT NULL REFERENCES "photo"("id") ON DELETE CASCADE,
              "added_at" INTEGER NOT NULL
            ) STRICT
            """
        )
        .execute(db)

        try #sql(
            """
            CREATE TABLE "sync_state"(
              "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
              "change_token" TEXT
            ) STRICT
            """
        )
        .execute(db)

        try #sql(
            """
            CREATE TABLE "shared_group"(
              "id" INTEGER NOT NULL PRIMARY KEY,
              "created_by_user_id" INTEGER,
              "name" TEXT NOT NULL,
              "invite_code" TEXT UNIQUE,
              "created_at" INTEGER
            ) STRICT
            """
        )
        .execute(db)

        try #sql(
            """
            CREATE TABLE "shared_album"(
              "id" INTEGER NOT NULL PRIMARY KEY,
              "shared_group_id" INTEGER NOT NULL REFERENCES "shared_group"("id") ON DELETE CASCADE,
              "name" TEXT NOT NULL
            ) STRICT
            """
        )
        .execute(db)

        try #sql(
            """
            CREATE TABLE "shared_photo"(
              "id" INTEGER NOT NULL PRIMARY KEY,
              "shared_album_id" INTEGER NOT NULL REFERENCES "shared_album"("id") ON DELETE CASCADE,
              "content_hash" TEXT,
              "original_file_name" TEXT
            ) STRICT
            """
        )
        .execute(db)

        try #sql(#"CREATE INDEX "idx_photo_taken_at" ON "photo"("taken_at")"#).execute(db)
        try #sql(#"CREATE INDEX "idx_photo_added_at" ON "photo"("added_at")"#).execute(db)
        try #sql(#"CREATE INDEX "idx_photo_added_date" ON "photo"("added_date")"#).execute(db)
        try #sql(#"CREATE INDEX "idx_photo_device_id" ON "photo"("device_id")"#).execute(db)
        try #sql(#"CREATE INDEX "idx_photo_place_id" ON "photo"("place_id")"#).execute(db)
        try #sql(#"CREATE INDEX "idx_photo_is_favorite" ON "photo"("is_favorite")"#).execute(db)
        try #sql(#"CREATE INDEX "idx_photo_content_hash" ON "photo"("content_hash")"#).execute(db)
        try #sql(
            #"CREATE INDEX "idx_album_photo_album_added" ON "album_photo"("album_id", "added_at")"#
        )
        .execute(db)
        try #sql(#"CREATE INDEX "idx_shared_album_group_id" ON "shared_album"("shared_group_id")"#).execute(db)
        try #sql(#"CREATE INDEX "idx_shared_photo_album_id" ON "shared_photo"("shared_album_id")"#).execute(db)
    }

    migrator.registerMigration("Give album photos unique identities") { db in
        try #sql(
            """
            CREATE TABLE "album_photo_new"(
              "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
              "album_id" INTEGER NOT NULL REFERENCES "album"("id") ON DELETE CASCADE,
              "photo_id" INTEGER NOT NULL REFERENCES "photo"("id") ON DELETE CASCADE,
              "added_at" INTEGER NOT NULL
            ) STRICT
            """
        )
        .execute(db)

        try #sql(
            """
            INSERT INTO "album_photo_new"("album_id", "photo_id", "added_at")
            SELECT "album_id", "photo_id", "added_at" FROM "album_photo"
            """
        )
        .execute(db)

        try #sql(#"DROP TABLE "album_photo""#).execute(db)
        try #sql(#"ALTER TABLE "album_photo_new" RENAME TO "album_photo""#).execute(db)
        try #sql(
            #"CREATE INDEX "idx_album_photo_album_added" ON "album_photo"("album_id", "added_at")"#
        )
        .execute(db)
    }

    migrator.registerMigration("Seed favorites album") { db in
        try #sql(
            #"ALTER TABLE "album" ADD COLUMN "is_favorite" INTEGER NOT NULL DEFAULT 0"#
        )
        .execute(db)

        try AlbumRecord.insert {
            AlbumRecord.Draft(name: "즐겨찾기", createdAt: .now, isFavorite: true)
        }
        .execute(db)
    }

    migrator.registerMigration("Mirror shared server entities") { db in
        // 기존 공유 테이블의 정수 ID는 서버 UUID와 호환되지 않는 임시 스키마다.
        // 공유 데이터는 서버가 원본이므로 캐시만 비우고 UUID 기반 미러 테이블로 다시 만든다.
        try #sql(#"DROP TABLE "shared_photo""#).execute(db)
        try #sql(#"DROP TABLE "shared_album""#).execute(db)
        try #sql(#"DROP TABLE "shared_group""#).execute(db)

        try #sql(
            """
            CREATE TABLE "shared_group"(
              "id" TEXT NOT NULL PRIMARY KEY,
              "created_by_user_id" TEXT,
              "created_by_display_name" TEXT,
              "name" TEXT NOT NULL,
              "invite_code" TEXT UNIQUE,
              "created_at" INTEGER,
              "joined_at" INTEGER,
              "updated_at" INTEGER NOT NULL,
              "member_count" INTEGER NOT NULL DEFAULT 0,
              "shared_album_count" INTEGER NOT NULL DEFAULT 0,
              "photo_count" INTEGER NOT NULL DEFAULT 0,
              "my_role" TEXT NOT NULL
            ) STRICT
            """
        )
        .execute(db)

        try #sql(
            """
            CREATE TABLE "shared_album"(
              "id" TEXT NOT NULL PRIMARY KEY,
              "shared_group_id" TEXT NOT NULL REFERENCES "shared_group"("id") ON DELETE CASCADE,
              "name" TEXT NOT NULL,
              "photo_count" INTEGER NOT NULL DEFAULT 0,
              "created_by_user_id" TEXT,
              "created_by_display_name" TEXT,
              "is_creator" INTEGER NOT NULL DEFAULT 0,
              "created_at" INTEGER NOT NULL,
              "updated_at" INTEGER NOT NULL
            ) STRICT
            """
        )
        .execute(db)

        try #sql(
            """
            CREATE TABLE "shared_photo"(
              "id" TEXT NOT NULL PRIMARY KEY,
              "shared_album_id" TEXT NOT NULL REFERENCES "shared_album"("id") ON DELETE CASCADE,
              "content_hash" TEXT,
              "original_file_name" TEXT
            ) STRICT
            """
        )
        .execute(db)

        try #sql(#"CREATE INDEX "idx_shared_album_group_id" ON "shared_album"("shared_group_id")"#)
            .execute(db)
        try #sql(#"CREATE INDEX "idx_shared_photo_album_id" ON "shared_photo"("shared_album_id")"#)
            .execute(db)
    }

    migrator.registerMigration("Track device resolution pending") { db in
        try #sql(
            #"ALTER TABLE "photo" ADD COLUMN "device_pending" INTEGER NOT NULL DEFAULT 0"#
        )
        .execute(db)

        try #sql(
            #"UPDATE "photo" SET "device_pending" = 1 WHERE "device_id" IS NULL"#
        )
        .execute(db)

        try #sql(#"CREATE INDEX "idx_photo_device_pending" ON "photo"("device_pending")"#).execute(db)
    }

    migrator.registerMigration("Scope shared cache to authenticated user") { db in
        try #sql(
            """
            CREATE TABLE "shared_cache_owner"(
              "id" INTEGER NOT NULL PRIMARY KEY CHECK ("id" = 1),
              "user_id" TEXT NOT NULL
            ) STRICT
            """
        )
        .execute(db)
    }

    migrator.registerMigration("Store shared photos as album memberships") { db in
        // 공유 사진은 서버가 원본인 캐시다. 기존 1:N 임시 캐시는 버리고 서버의 N:M 구조로 다시 채운다.
        try #sql(#"DROP TABLE "shared_photo""#).execute(db)

        try #sql(
            """
            CREATE TABLE "shared_photo"(
              "id" TEXT NOT NULL PRIMARY KEY,
              "shared_group_id" TEXT NOT NULL REFERENCES "shared_group"("id") ON DELETE CASCADE,
              "local_photo_id" INTEGER REFERENCES "photo"("id") ON DELETE SET NULL,
              "original_url" TEXT NOT NULL,
              "original_url_expires_at" INTEGER NOT NULL,
              "thumbnail_url" TEXT,
              "thumbnail_url_expires_at" INTEGER,
              "thumbnail_status" TEXT NOT NULL,
              "device_model" TEXT,
              "taken_at" INTEGER,
              "display_at" INTEGER NOT NULL,
              "latitude" REAL,
              "longitude" REAL,
              "location_name" TEXT,
              "is_inferred" INTEGER NOT NULL DEFAULT 0,
              "width" INTEGER NOT NULL,
              "height" INTEGER NOT NULL,
              "uploaded_by_user_id" TEXT,
              "uploaded_by_display_name" TEXT,
              "is_uploader" INTEGER NOT NULL DEFAULT 0,
              "like_count" INTEGER NOT NULL DEFAULT 0,
              "comment_count" INTEGER NOT NULL DEFAULT 0,
              "is_liked_by_me" INTEGER NOT NULL DEFAULT 0,
              "created_at" INTEGER NOT NULL,
              "updated_at" INTEGER NOT NULL
            ) STRICT
            """
        )
        .execute(db)

        try #sql(
            """
            CREATE TABLE "shared_album_photo"(
              "shared_album_id" TEXT NOT NULL REFERENCES "shared_album"("id") ON DELETE CASCADE,
              "shared_photo_id" TEXT NOT NULL REFERENCES "shared_photo"("id") ON DELETE CASCADE,
              "display_at" INTEGER NOT NULL,
              PRIMARY KEY("shared_album_id", "shared_photo_id")
            ) STRICT
            """
        )
        .execute(db)

        try #sql(
            """
            CREATE TABLE "shared_photo_upload_task"(
              "id" TEXT NOT NULL PRIMARY KEY,
              "batch_id" TEXT NOT NULL,
              "shared_group_id" TEXT NOT NULL REFERENCES "shared_group"("id") ON DELETE CASCADE,
              "shared_album_id" TEXT NOT NULL REFERENCES "shared_album"("id") ON DELETE CASCADE,
              "local_photo_id" INTEGER NOT NULL REFERENCES "photo"("id") ON DELETE CASCADE,
              "object_key" TEXT NOT NULL UNIQUE,
              "upload_url" TEXT NOT NULL,
              "upload_url_expires_at" INTEGER NOT NULL,
              "content_type" TEXT NOT NULL,
              "size_bytes" INTEGER NOT NULL CHECK("size_bytes" > 0),
              "idempotency_key" TEXT NOT NULL,
              "status" TEXT NOT NULL,
              "created_at" INTEGER NOT NULL,
              UNIQUE("shared_group_id", "local_photo_id")
            ) STRICT
            """
        )
        .execute(db)

        try #sql(#"CREATE INDEX "idx_shared_photo_group_id" ON "shared_photo"("shared_group_id")"#)
            .execute(db)
        try #sql(
            #"CREATE UNIQUE INDEX "idx_shared_photo_group_local" ON "shared_photo"("shared_group_id", "local_photo_id") WHERE "local_photo_id" IS NOT NULL"#
        )
        .execute(db)
        try #sql(
            #"CREATE INDEX "idx_shared_album_photo_album_display" ON "shared_album_photo"("shared_album_id", "display_at" DESC, "shared_photo_id")"#
        )
        .execute(db)
        try #sql(
            #"CREATE INDEX "idx_shared_album_photo_photo_id" ON "shared_album_photo"("shared_photo_id")"#
        )
        .execute(db)
        try #sql(
            #"CREATE INDEX "idx_shared_photo_upload_batch" ON "shared_photo_upload_task"("batch_id")"#
        )
        .execute(db)
        try #sql(
            #"CREATE INDEX "idx_shared_photo_upload_expiry" ON "shared_photo_upload_task"("upload_url_expires_at")"#
        )
        .execute(db)
    }

    migrator.registerMigration("Cache shared group member names") { db in
        try #sql(#"ALTER TABLE "shared_group" ADD COLUMN "member_names" TEXT"#).execute(db)
    }

    do {
        try migrator.migrate(database)
        return database
    } catch let migrationError {
        guard context == .live else { throw migrationError }
        logger.error("migration failed: \(migrationError). backing up store and recreating.")
        let path = database.path
        try? database.close()

        let fileManager = FileManager.default
        let suffixes = ["", "-wal", "-shm"]
        let backupBase = path + ".corrupt-\(UUID().uuidString)"

        var moved: [(original: String, backup: String)] = []
        for suffix in suffixes {
            let original = path + suffix
            guard fileManager.fileExists(atPath: original) else { continue }
            do {
                try fileManager.moveItem(atPath: original, toPath: backupBase + suffix)
                moved.append((original: original, backup: backupBase + suffix))
            } catch {
                for entry in moved.reversed() {
                    try? fileManager.moveItem(atPath: entry.backup, toPath: entry.original)
                }
                throw migrationError
            }
        }

        do {
            let recreated = try defaultDatabase(configuration: configuration)
            try migrator.migrate(recreated)
            for entry in moved {
                try? fileManager.removeItem(atPath: entry.backup)
            }
            return recreated
        } catch {
            for suffix in suffixes {
                try? fileManager.removeItem(atPath: path + suffix)
            }
            for entry in moved {
                try? fileManager.moveItem(atPath: entry.backup, toPath: entry.original)
            }
            throw error
        }
    }
}
