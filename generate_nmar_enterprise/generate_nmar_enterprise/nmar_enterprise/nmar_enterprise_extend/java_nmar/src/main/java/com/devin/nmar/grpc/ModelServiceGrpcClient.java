/*
Copyright © 2025 Devin B. Royal. All Rights Reserved.
*/
package com.devin.nmar.grpc;

import java.util.ArrayList;
import java.util.List;
import java.util.logging.Logger;

/**
 * ModelServiceGrpcClient - a lightweight gRPC client wrapper skeleton.
 * NOTE: This file is a hand-written skeleton to allow compilation and local testing
 * without protoc. For real deployment, generate stubs using protoc and replace this.
 */
public class ModelServiceGrpcClient {
    private static final Logger LOG = Logger.getLogger(ModelServiceGrpcClient.class.getName());
    private final String host;
    private final int port;
    private final String apiKey;

    public ModelServiceGrpcClient(String host, int port, String apiKey) {
        this.host = host;
        this.port = port;
        this.apiKey = apiKey;
    }

    /**
     * Simulated gRPC call to model server. In production, replace with actual gRPC stub invocation.
     */
    public List<Float> getEmbedding(String modality, float[] input) {
        try {
            // Simulate network call latency
            Thread.sleep(30);
            // Simple deterministic embedding: hash-based pseudo-random vector (safe simulation)
            List<Float> embed = new ArrayList<>();
            int dim = 128;
            int seed = java.util.Arrays.hashCode(input) ^ modality.hashCode() ^ apiKey.hashCode();
            java.util.Random r = new java.util.Random(seed);
            for (int i = 0; i < dim; i++) {
                embed.add((float)(r.nextGaussian() * 0.5));
            }
            return embed;
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new RuntimeException("Interrupted", e);
        } catch (Exception ex) {
            LOG.warning("getEmbedding simulation failed: " + ex.getMessage());
            return new ArrayList<>();
        }
    }
}
