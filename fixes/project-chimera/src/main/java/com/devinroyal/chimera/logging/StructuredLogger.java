/*
 * Copyright © 2025 Devin B. Royal.
 * All Rights Reserved.
 */
package com.devinroyal.chimera.logging;

import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.logging.Level;
import java.util.logging.Logger;

public final class StructuredLogger {
    private final Logger logger;

    private StructuredLogger(Class<?> cls) {
        this.logger = Logger.getLogger(cls.getName());
    }

    public static StructuredLogger get(Class<?> cls) { return new StructuredLogger(cls); }

    public void info(String event, Object... kv) { log(Level.INFO, event, kv); }
    public void warn(String event, Object... kv) { log(Level.WARNING, event, kv); }
    public void error(String event, Object... kv) { log(Level.SEVERE, event, kv); }

    private void log(Level level, String event, Object... kv) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("ts", Instant.now().toString());
        m.put("event", event);
        for (int i = 0; i + 1 < kv.length; i += 2) m.put(String.valueOf(kv[i]), kv[i + 1]);
        logger.log(level, m.toString());
    }
}
/*
 * Copyright © 2025 Devin B. Royal.
 * All Rights Reserved.
 */
