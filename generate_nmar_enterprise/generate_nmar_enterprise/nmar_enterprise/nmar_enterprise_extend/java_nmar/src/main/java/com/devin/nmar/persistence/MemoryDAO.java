/*
Copyright © 2025 Devin B. Royal. All Rights Reserved.
*/
package com.devin.nmar.persistence;

import java.sql.*;
import java.util.*;
import java.util.logging.Logger;

/**
 * MemoryDAO - persistence layer for MemoryAnchors using PostgreSQL + pgvector.
 * NOTE: This class is a functional JDBC implementation. It expects the pgvector extension
 * and table created by migrations.
 */
public class MemoryDAO {
    private static final Logger LOG = Logger.getLogger(MemoryDAO.class.getName());
    private final String jdbcUrl;
    private final String user;
    private final String pass;

    public MemoryDAO(String jdbcUrl, String user, String pass) {
        this.jdbcUrl = jdbcUrl;
        this.user = user;
        this.pass = pass;
    }

    private Connection conn() throws SQLException {
        return DriverManager.getConnection(jdbcUrl, user, pass);
    }

    public UUID saveMemory(String key, String payload, double relevance, float[] embedding) {
        String sql = "INSERT INTO memory_anchors (key, payload, relevance, embedding) VALUES (?, ?, ?, ?::vector) RETURNING id";
        try (Connection c = conn(); PreparedStatement p = c.prepareStatement(sql)) {
            p.setString(1, key);
            p.setString(2, payload);
            p.setDouble(3, relevance);
            // array -> string format for pgvector: '[v1,v2,...]'
            String vec = arrayToPgVector(embedding);
            p.setString(4, vec);
            try (ResultSet rs = p.executeQuery()) {
                if (rs.next()) return UUID.fromString(rs.getString(1));
            }
        } catch (SQLException e) {
            LOG.severe("saveMemory failed: " + e.getMessage());
            throw new RuntimeException(e);
        }
        return null;
    }

    public List<Map<String,Object>> nearestNeighbors(float[] embedding, int k) {
        List<Map<String,Object>> out = new ArrayList<>();
        String sql = "SELECT id, key, payload, relevance, 1 - (embedding <#> ?::vector) AS similarity FROM memory_anchors ORDER BY embedding <#> ?::vector LIMIT ?";
        // NOTE: '<#>' is pgvector operator for cosine distance; adjust for your pgvector version
        try (Connection c = conn(); PreparedStatement p = c.prepareStatement(sql)) {
            String vec = arrayToPgVector(embedding);
            p.setString(1, vec);
            p.setString(2, vec);
            p.setInt(3, k);
            try (ResultSet rs = p.executeQuery()) {
                while (rs.next()) {
                    Map<String,Object> m = new HashMap<>();
                    m.put("id", rs.getString("id"));
                    m.put("key", rs.getString("key"));
                    m.put("payload", rs.getString("payload"));
                    m.put("relevance", rs.getDouble("relevance"));
                    m.put("similarity", rs.getDouble("similarity"));
                    out.add(m);
                }
            }
        } catch (SQLException e) {
            LOG.severe("nearestNeighbors failed: " + e.getMessage());
            throw new RuntimeException(e);
        }
        return out;
    }

    private String arrayToPgVector(float[] v) {
        StringBuilder sb = new StringBuilder();
        sb.append('[');
        for (int i=0;i<v.length;i++) {
            if (i>0) sb.append(',');
            sb.append(v[i]);
        }
        sb.append(']');
        return sb.toString();
    }
}
