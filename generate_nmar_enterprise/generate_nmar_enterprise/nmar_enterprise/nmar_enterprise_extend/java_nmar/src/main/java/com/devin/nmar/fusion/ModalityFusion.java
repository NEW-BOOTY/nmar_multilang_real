/*
Copyright © 2025 Devin B. Royal. All Rights Reserved.
*/
package com.devin.nmar.fusion;

import java.util.*;

/**
 * ModalityFusion - deterministic placeholder encoders and attention fusion.
 * Replace encoders with real model inference in production.
 */
public class ModalityFusion {
    private final int dim;
    public static class Embedding { public final double[] v; public Embedding(int d) { v = new double[d]; } }
    public ModalityFusion(int dim) { this.dim = Math.max(16, dim); }

    public Embedding encodeText(String text) {
        Embedding e = new Embedding(dim);
        int seed = text.hashCode();
        Random r = new Random(seed);
        for (int i=0;i<dim;i++) e.v[i] = r.nextDouble()*2 - 1;
        return e;
    }

    public Embedding encodeImage(byte[] bytes, String meta) {
        Embedding e = new Embedding(dim);
        int seed = Arrays.hashCode(bytes) ^ (meta==null?0:meta.hashCode());
        Random r = new Random(seed);
        for (int i=0;i<dim;i++) e.v[i] = r.nextDouble()*2 - 1;
        return e;
    }

    public Embedding encodeSensor(double[] s) {
        Embedding e = new Embedding(dim);
        for (int i=0;i<dim;i++) e.v[i] = (i < s.length ? s[i] : 0.0) * 0.1;
        return e;
    }

    public Embedding fuse(Map<String,Embedding> modalities) {
        Embedding out = new Embedding(dim);
        double total = 0.0;
        Map<String,Double> scores = new HashMap<>();
        for (Map.Entry<String,Embedding> me : modalities.entrySet()) {
            double norm = 0.0;
            for (double d : me.getValue().v) norm += d*d;
            norm = Math.sqrt(norm) + 1e-9;
            double score = 1.0/(1.0 + Math.exp(-Math.log(norm+1e-9)));
            scores.put(me.getKey(), score);
            total += score;
        }
        for (Map.Entry<String,Embedding> me : modalities.entrySet()) {
            double w = total==0 ? 1.0/modalities.size() : scores.get(me.getKey())/total;
            double[] vec = me.getValue().v;
            for (int i=0;i<dim;i++) out.v[i] += vec[i] * w;
        }
        return out;
    }
}

/*
Copyright © 2025 Devin B. Royal. All Rights Reserved.
*/
