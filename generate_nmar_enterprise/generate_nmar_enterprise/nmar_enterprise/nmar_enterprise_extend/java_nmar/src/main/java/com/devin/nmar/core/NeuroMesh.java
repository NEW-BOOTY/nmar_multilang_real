/*
Copyright © 2025 Devin B. Royal. All Rights Reserved.
*/
package com.devin.nmar.core;

import java.util.*;
import java.util.concurrent.atomic.AtomicLong;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 * NeuroMesh - dynamic graph topology with rewiring, pruning, and neurogenesis.
 * Designed for integration with real embeddings or incremental learning signals.
 */
public class NeuroMesh {
    private static final Logger LOG = Logger.getLogger(NeuroMesh.class.getName());
    private final Map<Long, Node> nodes = new HashMap<>();
    private final AtomicLong idGen = new AtomicLong(1);
    private final double pruneThreshold;
    private final int maxNodes;

    public static class Node {
        public final long id;
        public final String key;
        public double activation;
        public final Map<Long, Double> edges = new HashMap<>();

        public Node(long id, String key) { this.id = id; this.key = key; this.activation = 0.0; }
    }

    public NeuroMesh(double pruneThreshold, int maxNodes) {
        this.pruneThreshold = pruneThreshold;
        this.maxNodes = Math.max(16, maxNodes);
        LOG.info(() -> "NeuroMesh initialized pruneThreshold=" + pruneThreshold + " maxNodes=" + maxNodes);
    }

    public synchronized Node createNode(String key, double activation) {
        try {
            long id = idGen.getAndIncrement();
            Node n = new Node(id, key);
            n.activation = activation;
            nodes.put(id, n);
            enforceMaxNodes();
            return n;
        } catch (Exception e) {
            LOG.log(Level.SEVERE, "createNode failed", e);
            throw e;
        }
    }

    public synchronized Node getNodeByKey(String key) {
        for (Node n : nodes.values()) if (n.key.equals(key)) return n;
        return null;
    }

    public synchronized Node getOrCreate(String key, double activation) {
        Node n = getNodeByKey(key);
        return (n != null) ? n : createNode(key, activation);
    }

    public synchronized void addEdge(long fromId, long toId, double weight) {
        try {
            Node f = nodes.get(fromId);
            if (f == null || !nodes.containsKey(toId)) {
                LOG.warning("addEdge: missing node(s) from=" + fromId + " to=" + toId);
                return;
            }
            f.edges.merge(toId, Math.max(0.0, weight), Double::sum);
        } catch (Exception e) {
            LOG.log(Level.SEVERE, "addEdge failed", e);
            throw e;
        }
    }

    public synchronized void propagate(double decay, int steps) {
        try {
            for (int s=0; s<steps; s++) {
                Map<Long, Double> incoming = new HashMap<>();
                for (Node n : nodes.values()) {
                    for (Map.Entry<Long, Double> e : n.edges.entrySet()) {
                        incoming.merge(e.getKey(), n.activation * e.getValue(), Double::sum);
                    }
                }
                for (Map.Entry<Long, Double> inc : incoming.entrySet()) {
                    Node tgt = nodes.get(inc.getKey());
                    if (tgt != null) tgt.activation = tgt.activation * (1.0 - decay) + inc.getValue();
                }
                if (s % 5 == 0) prune();
            }
        } catch (Exception e) {
            LOG.log(Level.SEVERE, "propagate failed", e);
            throw e;
        }
    }

    private synchronized void prune() {
        try {
            List<Long> removeNodes = new ArrayList<>();
            for (Node n : nodes.values()) {
                n.edges.entrySet().removeIf(en -> en.getValue() < pruneThreshold);
                if (n.activation < pruneThreshold && n.edges.isEmpty()) removeNodes.add(n.id);
            }
            for (Long id : removeNodes) nodes.remove(id);
        } catch (Exception e) {
            LOG.log(Level.SEVERE, "prune failed", e);
            throw e;
        }
    }

    private synchronized void enforceMaxNodes() {
        if (nodes.size() <= maxNodes) return;
        List<Node> list = new ArrayList<>(nodes.values());
        list.sort(Comparator.comparingDouble(a -> a.activation));
        while (nodes.size() > maxNodes) {
            Node rem = list.remove(0);
            nodes.remove(rem.id);
            LOG.fine(() -> "enforceMaxNodes removed " + rem.id);
        }
    }

    public synchronized Map<String,Object> snapshot() {
        Map<String,Object> out = new HashMap<>();
        out.put("nodeCount", nodes.size());
        return out;
    }
}
 
/*
Copyright © 2025 Devin B. Royal. All Rights Reserved.
*/
