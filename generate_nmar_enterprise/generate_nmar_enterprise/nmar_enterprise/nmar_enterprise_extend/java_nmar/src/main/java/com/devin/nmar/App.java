/*
Copyright © 2025 Devin B. Royal. All Rights Reserved.
*/
package com.devin.nmar;

import com.devin.nmar.core.NeuroMesh;
import com.devin.nmar.fusion.ModalityFusion;
import com.devin.nmar.memory.MemoryAnchors;
import com.devin.nmar.meta.MetaReasoner;
import com.devin.nmar.learning.AdaptiveLearner;

import java.util.*;

public class App {
    public static void main(String[] args) {
        try {
            NeuroMesh mesh = new NeuroMesh(0.01, 1024);
            ModalityFusion fusion = new ModalityFusion(128);
            MemoryAnchors memory = new MemoryAnchors(2000, 0.01);
            MetaReasoner meta = new MetaReasoner();
            AdaptiveLearner learner = new AdaptiveLearner(mesh, 100);

            String text = "Projected sea-level rise near urban coasts will accelerate infrastructure risks.";
            ModalityFusion.Embedding te = fusion.encodeText(text);
            ModalityFusion.Embedding ie = fusion.encodeImage(new byte[]{1,2,3,4,5}, "sat");
            ModalityFusion.Embedding se = fusion.encodeSensor(new double[]{0.3,0.2});

            Map<String,ModalityFusion.Embedding> mods = new HashMap<>();
            mods.put("text", te);
            mods.put("image", ie);
            mods.put("sensor", se);

            ModalityFusion.Embedding fused = fusion.fuse(mods);
            List<String> keys = new ArrayList<>();
            for (int i=0;i<8;i++) keys.add("sem:" + i + ":" + (int)(fused.v[i]*1000));
            for (String k : keys) mesh.getOrCreate(k, 0.5);
            mesh.propagate(0.04, 4);

            memory.remember("climate:policy", text, 0.9);
            String out = "Recommend adaptation funding and coastal managed retreat studies.";
            MetaReasoner.Feedback f = meta.evaluate(text, out, 0.8, Collections.emptyMap());
            learner.apply(keys, f.reward);

            System.out.println("NMAR Core demo executed successfully.");
        } catch (Exception e) {
            e.printStackTrace();
            System.exit(2);
        }
    }
}

/*
Copyright © 2025 Devin B. Royal. All Rights Reserved.
*/
