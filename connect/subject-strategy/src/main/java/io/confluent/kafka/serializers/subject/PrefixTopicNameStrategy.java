package io.confluent.kafka.serializers.subject;

import java.util.Map;
import io.confluent.kafka.schemaregistry.ParsedSchema;
import io.confluent.kafka.serializers.subject.strategy.SubjectNameStrategy;

/**
 * Subject name strategy that produces ":{prefix}:{topic}-key" or ":{prefix}:{topic}-value"
 * to match the Python producer's format (e.g. ":.flink-dev:healthcare.public.prescriptions-key").
 * Prefix is read from (in order): config map keys, then system property "connect.subject.name.prefix".
 * Config keys: subject.name.prefix, key.converter.subject.name.prefix, value.converter.subject.name.prefix
 * (env: CONNECT_KEY_CONVERTER_SUBJECT_NAME_PREFIX, CONNECT_VALUE_CONVERTER_SUBJECT_NAME_PREFIX).
 */
public class PrefixTopicNameStrategy implements SubjectNameStrategy {

    /** System property fallback when converter does not pass prefix in config (entrypoint can set via KAFKA_OPTS). */
    private static final String PREFIX_SYSTEM_PROPERTY = "connect.subject.name.prefix";

    /** Keys the Connect worker may pass (env CONNECT_*_SUBJECT_NAME_PREFIX → key.converter.subject.name.prefix etc.) */
    private static final String[] PREFIX_KEYS = {
        "subject.name.prefix",
        "key.converter.subject.name.prefix",
        "value.converter.subject.name.prefix"
    };

    private String prefix = "";

    @Override
    public void configure(Map<String, ?> configs) {
        if (configs != null) {
            for (String key : PREFIX_KEYS) {
                Object p = configs.get(key);
                if (p != null && !p.toString().trim().isEmpty()) {
                    prefix = p.toString().trim();
                    return;
                }
            }
        }
        String fromJvm = System.getProperty(PREFIX_SYSTEM_PROPERTY);
        if (fromJvm != null && !fromJvm.trim().isEmpty()) {
            prefix = fromJvm.trim();
        } else {
            prefix = "";
        }
    }

    @Override
    public String subjectName(String topic, boolean isKey, ParsedSchema schema) {
        if (topic == null) {
            throw new IllegalArgumentException("Topic is null.");
        }
        String suffix = isKey ? "key" : "value";
        if (prefix == null || prefix.isEmpty()) {
            return topic + "-" + suffix;
        }
        return ":" + prefix + ":" + topic + "-" + suffix;
    }
}
