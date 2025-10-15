/*
Copyright © 2025 Devin B. Royal. All Rights Reserved.
*/
package com.devin.nmar.memory;

import java.time.Instant;
import java.util.*;

/**
 * MemoryAnchors - relevance-indexed memory with decay and consolidation.
 */
public class MemoryAnchors {
    public static class Chunk {
        public final UUID id = UUID.randomUUID();
        public final String key;
        public final String payload;
        public double relevance;
        public final Instant created;
        public int accesses = 0;
        public Chunk(String key, String payload, double relevance) { this.key=key; this.payload=payload; this.relevance=relevance; this.created = Instant.now(); }
    }

    private final Map<UUID,Chunk> store = new HashMap<>();
    private final int maxChunks;
    private final double decayRate;

    public MemoryAnchors(int maxChunks, double decayRate) {
        this.maxChunks = Math.max(100, maxChunks);
        this.decayRate = Math.max(0.0, decayRate);
    }

    public synchronized Chunk remember(String key, String payload, double relevance) {
        Chunk c = new Chunk(key,payload,relevance);
        store.put(c.id,c);
        if (store.size() > maxChunks) consolidate();
        return c;
    }

    public synchronized List<Chunk> retrieve(String q, int limit) {
        long now = Instant.now().toEpochMilli();
        List<Chunk> list = new ArrayList<>();
        for (Chunk c : store.values()) {
            if (c.key.contains(q) || c.payload.contains(q)) {
                double ageHours = Math.max(0.0,(now - c.created.toEpochMilli())/1000.0/3600.0);
                double freshness = Math.exp(-decayRate * ageHours);
                double score = c.relevance * freshness + Math.log(1 + c.accesses);
                c.relevance = score;
                list.add(c);
            }
        }
        list.sort(Comparator.comparingDouble((Chunk x) -> x.relevance).reversed());
        if (list.size() > limit) list = list.subList(0, limit);
        list.forEach(c -> c.accesses++);
        return list;
    }

    private synchronized void consolidate() {
        List<Chunk> list = new ArrayList<>(store.values());
        list.sort(Comparator.comparingDouble(a -> a.relevance));
        while (store.size() > maxChunks && !list.isEmpty()) {
            Chunk rem = list.remove(0);
            store.remove(rem.id);
        }
    }
}

/*
Copyright © 2025 Devin B. Royal. All Rights Reserved.
*/
