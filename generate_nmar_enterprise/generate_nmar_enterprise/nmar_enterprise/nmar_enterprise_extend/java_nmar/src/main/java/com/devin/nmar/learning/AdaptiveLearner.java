/*
Copyright © 2025 Devin B. Royal. All Rights Reserved.
*/
package com.devin.nmar.learning;

import com.devin.nmar.core.NeuroMesh;
import java.util.*;
import java.util.logging.Logger;

/**
 * AdaptiveLearner: simple online adapter that applies feedback to mesh.
 */
public class AdaptiveLearner {
    private static final Logger LOG = Logger.getLogger(AdaptiveLearner.class.getName());
    private final NeuroMesh mesh;
    private final Deque<double[]> replay = new ArrayDeque<>();
    private final int maxReplay;

    public AdaptiveLearner(NeuroMesh mesh, int maxReplay) {
        this.mesh = mesh;
        this.maxReplay = Math.max(10, maxReplay);
    }

    public synchronized void apply(List<String> activeKeys, double reward) {
        try {
            List<NeuroMesh.Node> nodes = new ArrayList<>();
            for (String k : activeKeys) nodes.add(mesh.getOrCreate(k, 0.1));
            double scale = Math.max(0.0, Math.min(2.0, 1.0 + reward));
            for (int i=0;i<nodes.size();i++) for (int j=0;j<nodes.size();j++) if (i!=j) mesh.addEdge(nodes.get(i).id, nodes.get(j).id, 0.01 * scale);
            double[] trace = new double[]{reward, activeKeys.size()};
            if (replay.size() >= maxReplay) replay.removeFirst();
            replay.addLast(trace);
            if (Math.random() < 0.05) replayApply();
        } catch (Exception e) {
            LOG.warning("apply failed: " + e.getMessage());
            throw e;
        }
    }

    private void replayApply() {
        for (double[] t : replay) {
            // no-op placeholder for replay-based adjustments
        }
    }
}

/*
Copyright © 2025 Devin B. Royal. All Rights Reserved.
*/
