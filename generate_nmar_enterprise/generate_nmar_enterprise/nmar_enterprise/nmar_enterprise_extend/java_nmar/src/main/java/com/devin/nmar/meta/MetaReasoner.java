/*
Copyright © 2025 Devin B. Royal. All Rights Reserved.
*/
package com.devin.nmar.meta;

import java.util.*;

/**
 * MetaReasoner: self-reflection and feedback generation.
 */
public class MetaReasoner {
    public static class Feedback { public final double reward; public final String rationale; public Feedback(double r, String ra) { reward = r; rationale = ra; } }

    public Feedback evaluate(String prompt, String output, double confidence, Map<String,Object> ctx) {
        if (output == null || output.trim().isEmpty()) return new Feedback(-1.0, "empty output");
        double reward = Math.max(-1.0, Math.min(1.0, confidence - 0.25));
        String rationale = "confidence adjusted";
        if (output.length() < Math.max(20, prompt.length()/2)) { reward -= 0.2; rationale += "; short output"; }
        if (ctx != null && Boolean.TRUE.equals(ctx.get("domainMismatch"))) { reward -= 0.3; rationale += "; domainMismatch"; }
        return new Feedback(reward, rationale);
    }
}

/*
Copyright © 2025 Devin B. Royal. All Rights Reserved.
*/
