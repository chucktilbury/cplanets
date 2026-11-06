/*
 * src/server/snapshotStore.cw — SQLite-shaped live snapshot (F).
 *
 * Persists published tick, state blob, digest blob, and last
 * policies for the live process only. No durable save / rejoin
 * API in v1 (RULES §2 Session). Schema stays clean for a future
 * save path (PLAN §4.F item 7).
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial SQLite snapshot tables (no rejoin API).
 *   2026-11-05  Build SQL with String.append (no adjacent lits).
 */

import sql as SQL
import sqlite as SQLite

include "policyTable.cw"

/*
 * SnapshotStore is the sole writer's SQLite-shaped persistence.
 *
 * Empty path opens a private temporary DB (stand-alone, no save).
 * One writer: the server process. Clients never open this DB.
 */
class SnapshotStore {
    SQLite.Connection db
    String path
    bool openOk
    String lastError

    /*
     * Construct a store bound to a SQLite path.
     *
     * Purpose: delay schema setup until open() so tests can choose
     * "" for a temp DB or a path under /tmp.
     *
     * Parameters:
     *   dbPath — filesystem path, or "" for a private temp DB.
     *
     * Returns: SnapshotStore with openOk false.
     */
    SnapshotStore(String dbPath) {
        path = dbPath
        openOk = false
        lastError = "not opened"
        db = SQLite.Connection(dbPath)
    }

    /*
     * Build a CREATE/INSERT SQL string from fragments.
     *
     * Purpose: avoid adjacent string-literal syntax (Cwhip does
     * not concatenate them) while keeping lines short.
     *
     * Parameters:
     *   parts — list of String fragments in order.
     *
     * Returns: concatenated SQL text.
     */
    String joinSql(list parts) {
        String out = ""
        int64 index = 0
        while (index < parts.length) {
            String part = parts[index]
            out.append(part)
            index = index + 1
        }
        return(out)
    }

    /*
     * Open the connection and ensure schema exists.
     *
     * Purpose: create meta / publish / policies tables for the
     * live game. Does not load a prior saved game (no rejoin).
     *
     * Parameters: none.
     *
     * Returns: true when open and schema execute succeeded.
     */
    bool open() {
        if (not db.isOpen()) {
            lastError = db.error()
            openOk = false
            return(false)
        }
        String metaSql = joinSql([
            "CREATE TABLE IF NOT EXISTS meta (",
            "key TEXT PRIMARY KEY, value TEXT NOT NULL)"])
        if (not db.execute(metaSql)) {
            lastError = db.error()
            openOk = false
            return(false)
        }
        String publishSql = joinSql([
            "CREATE TABLE IF NOT EXISTS publish (",
            "tick INTEGER PRIMARY KEY,",
            "state_blob BLOB NOT NULL,",
            "digest_blob BLOB NOT NULL)"])
        if (not db.execute(publishSql)) {
            lastError = db.error()
            openOk = false
            return(false)
        }
        String policiesSql = joinSql([
            "CREATE TABLE IF NOT EXISTS policies (",
            "player_id INTEGER PRIMARY KEY,",
            "blob BLOB NOT NULL,",
            "has_policy INTEGER NOT NULL)"])
        if (not db.execute(policiesSql)) {
            lastError = db.error()
            openOk = false
            return(false)
        }
        String schemaSql = joinSql([
            "INSERT OR REPLACE INTO meta(key, value) ",
            "VALUES('schema', 'cplanets-f-v1')"])
        if (not db.execute(schemaSql)) {
            lastError = db.error()
            openOk = false
            return(false)
        }
        openOk = true
        lastError = ""
        return(true)
    }

    /*
     * Persist one published tick and the last-policy table.
     *
     * Purpose: sole-writer snapshot after tick() (PLAN §4.F item
     * 2). Overwrites policy rows; inserts publish row for tick.
     *
     * Parameters:
     *   tick — published tick count.
     *   stateBlob — opaque published state bytes.
     *   digestBlob — opaque digest / events bytes.
     *   policies — last-policy table to mirror.
     *
     * Returns: true when all writes succeed.
     */
    bool persist(
        int64 tick,
        buffer stateBlob,
        buffer digestBlob,
        PolicyTable policies) {
        if (not openOk) {
            lastError = "store not open"
            return(false)
        }
        String publishSql = joinSql([
            "INSERT OR REPLACE INTO publish",
            "(tick, state_blob, digest_blob) ",
            "VALUES (?, ?, ?)"])
        SQL.Statement putPublish = db.prepare(publishSql)
        if (putPublish == null) {
            lastError = db.error()
            return(false)
        }
        bool bound = putPublish.bind(1, SQL.Value(tick))
        if (not bound) {
            lastError = putPublish.error()
            putPublish.close()
            return(false)
        }
        bound = putPublish.bind(2, SQL.Value(stateBlob))
        if (not bound) {
            lastError = putPublish.error()
            putPublish.close()
            return(false)
        }
        bound = putPublish.bind(3, SQL.Value(digestBlob))
        if (not bound) {
            lastError = putPublish.error()
            putPublish.close()
            return(false)
        }
        putPublish.step()
        if (putPublish.failed()) {
            lastError = putPublish.error()
            putPublish.close()
            return(false)
        }
        putPublish.close()

        String policySql = joinSql([
            "INSERT OR REPLACE INTO policies",
            "(player_id, blob, has_policy) ",
            "VALUES (?, ?, ?)"])
        int64 index = 0
        while (index < policies.slots.length) {
            PolicySlot slot = policies.slots[index]
            SQL.Statement putPolicy = db.prepare(policySql)
            if (putPolicy == null) {
                lastError = db.error()
                return(false)
            }
            bound = putPolicy.bind(1, SQL.Value(slot.playerId))
            if (not bound) {
                lastError = putPolicy.error()
                putPolicy.close()
                return(false)
            }
            bound = putPolicy.bind(2, SQL.Value(slot.blob))
            if (not bound) {
                lastError = putPolicy.error()
                putPolicy.close()
                return(false)
            }
            int64 flag = 0
            if (slot.hasPolicy) {
                flag = 1
            }
            bound = putPolicy.bind(3, SQL.Value(flag))
            if (not bound) {
                lastError = putPolicy.error()
                putPolicy.close()
                return(false)
            }
            putPolicy.step()
            if (putPolicy.failed()) {
                lastError = putPolicy.error()
                putPolicy.close()
                return(false)
            }
            putPolicy.close()
            index = index + 1
        }
        lastError = ""
        return(true)
    }

    /*
     * Read the latest published tick from the publish table.
     *
     * Purpose: smoke / unit checks that persist wrote a row.
     *
     * Parameters: none.
     *
     * Returns: max tick, or -1 when empty / error.
     */
    int64 latestTick() {
        if (not openOk) {
            return(-1)
        }
        SQL.Statement query = db.prepare(
            "SELECT MAX(tick) FROM publish")
        if (query == null) {
            lastError = db.error()
            return(-1)
        }
        if (not query.step()) {
            query.close()
            return(-1)
        }
        SQL.Value value = query.value(0)
        if (value.isNull()) {
            query.close()
            return(-1)
        }
        int64 tick = value.asInteger()
        query.close()
        return(tick)
    }

    /*
     * Close the SQLite connection.
     *
     * Purpose: end of process; temp DB discarded (no save).
     *
     * Parameters: none.
     *
     * Returns: true when close succeeds or already closed.
     */
    bool close() {
        if (not db.isOpen()) {
            openOk = false
            return(true)
        }
        bool ok = db.close()
        openOk = false
        return(ok)
    }
}
