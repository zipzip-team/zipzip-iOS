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
