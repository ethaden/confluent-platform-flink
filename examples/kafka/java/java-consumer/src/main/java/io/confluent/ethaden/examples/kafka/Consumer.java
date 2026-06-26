package io.confluent.ethaden.examples.kafka;

import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.lang.invoke.MethodHandles;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.time.Duration;
import java.util.List;
import java.util.Properties;
import java.util.Random;

import org.apache.kafka.clients.consumer.ConsumerConfig;
import org.apache.kafka.clients.consumer.KafkaConsumer;
import org.apache.kafka.common.errors.RecordDeserializationException;
import org.apache.kafka.common.serialization.StringDeserializer;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import io.confluent.kafka.serializers.KafkaAvroDeserializer;
import models.avro.SimpleValue;

public class Consumer {

    private static final Logger LOGGER = LogManager.getLogger(MethodHandles.lookup().lookupClass());

    private static final int NB_MESSAGES = 10;
    private Properties properties;
    private String topic;
    private static final Duration POLL_TIMEOUT = Duration.ofMillis(100);

    private Properties loadConfig(final String configFile) throws IOException {
        if (!Files.exists(Paths.get(configFile))) {
            throw new IOException(configFile + " not found.");
        }
        final Properties cfg = new Properties();
        try (InputStream inputStream = new FileInputStream(configFile)) {
            cfg.load(inputStream);
        }
        // General
        cfg.put(ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class);
        // Avro
        cfg.put(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, KafkaAvroDeserializer.class);
        if (!cfg.contains(ConsumerConfig.GROUP_ID_CONFIG))
        {
          Random r= new Random();
          cfg.put(ConsumerConfig.GROUP_ID_CONFIG, "Java-Consumer-"+r.nextInt(100000));
        }
        if (!cfg.contains(ConsumerConfig.AUTO_OFFSET_RESET_CONFIG))
        {
          Random r= new Random();
          cfg.put(ConsumerConfig.AUTO_OFFSET_RESET_CONFIG, "earliest");
        }
        return cfg;
    }

    public static void main(String[] args) {
        LOGGER.info("Starting consumer");

        // Load producer configuration settings from a local file
        if (args.length != 1) {
            System.out.println("Usage: java consumer.jar <consumer.properties>");
            System.exit(1);
        }
        try {
            Consumer consumer = new Consumer(args[0]);
            consumer.subscribe();
        } catch (IOException e) {
            System.err.println("Exception while reading config file: " + e);
        }
    }

    public Consumer(final String propFile) throws IOException {
        this.properties = loadConfig(propFile);
        this.topic = this.properties.getProperty("topic");
    }

    private void subscribe() {
        try (KafkaConsumer<String, SimpleValue> consumer = new KafkaConsumer<>(this.properties)) {
            // Subscribe to our topic
            LOGGER.info("Subscribing to topic " + this.topic);
            consumer.subscribe(List.of(this.topic));
            //noinspection InfiniteLoopStatement
            while (true) {
                try {
                    final var records = consumer.poll(POLL_TIMEOUT);
                    int count = records.count();
                    if (count != 0) {
                        LOGGER.info("Poll return {} records", count);
                    }
                    for (var record : records) {
                        LOGGER.info("Fetch record key={} value={}", record.key(), record.value());
                        System.out.println("key="+record.key()+", value="+record.value());
                    }
                } catch (RecordDeserializationException re) {
                    long offset = re.offset();
                    Throwable t = re.getCause();
                    LOGGER.error("Failed to consumer at partition={} offset={}", re.topicPartition().partition(), offset, t);
                    LOGGER.info("Skipping offset={}", offset);
                    consumer.seek(re.topicPartition(), offset + 1);
                } catch (Exception e) {
                    LOGGER.error("Failed to consumer", e);
                }
            }
        } finally {
            LOGGER.info("Closing consumer");
        }
    }

}
