package io.confluent.ethaden.examples.kafka;

import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.lang.invoke.MethodHandles;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.Properties;
import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.clients.producer.RecordMetadata;
import org.apache.kafka.common.serialization.StringSerializer;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import io.confluent.kafka.serializers.KafkaAvroSerializer;
import io.confluent.kafka.serializers.KafkaAvroSerializerConfig;
import models.avro.SimpleValue;


public class Produce {

    private static final Logger LOGGER = LogManager.getLogger(MethodHandles.lookup().lookupClass());

    private static final int NB_MESSAGES = 10;
    private Properties properties;
    private int count = 0;
    private String topic;

    public Produce(final String propFile) throws IOException {
        this.properties = loadConfig(propFile);
        this.topic = this.properties.getProperty("topic");
    }

    private Properties loadConfig(final String configFile) throws IOException {
        if (!Files.exists(Paths.get(configFile))) {
            throw new IOException(configFile + " not found.");
        }
        final Properties cfg = new Properties();
        try (InputStream inputStream = new FileInputStream(configFile)) {
            cfg.load(inputStream);
        }
        // General
        cfg.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class);
        cfg.put(ProducerConfig.BATCH_SIZE_CONFIG, 30);
        // Avro
        cfg.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, KafkaAvroSerializer.class);
        return cfg;
    }

    public static void main(String[] args) {
        // Load producer configuration settings from a local file
        if (args.length != 1) {
            System.out.println("Usage: java producer.jar <producer.properties>");
            System.exit(1);
        }
        try {
            Produce produce = new Produce(args[0]);
            produce.sendAvroProducer(10);
        } catch (IOException e) {
            System.err.println("Exception while reading config file: "+e);
        }
    }

    void sendAvroProducer(int nb) {
        LOGGER.info("Starting Arvo Producer");
        try (KafkaProducer<String, SimpleValue> producer = new KafkaProducer<>(this.properties)) {
            for (int i=0; i < nb; i++) {
                String key = Integer.toString(count);
                SimpleValue value = SimpleValue.newBuilder()
                        .setTheName("This is message " + key)
                        .setTheValue("This is the value")
                        .build();
                ProducerRecord<String, SimpleValue> producerRecord = new ProducerRecord<>(this.topic, key, value);
                LOGGER.info("Sending message {}", count);
                producer.send(producerRecord, (RecordMetadata recordMetadata, Exception exception) -> {
                    if (exception == null) {
                        System.out.println("Record written to offset " +
                                recordMetadata.offset() + " timestamp " +
                                recordMetadata.timestamp());
                    } else {
                        System.err.println("An error occurred");
                        exception.printStackTrace(System.err);
                    }
              });
                count++;
            }
            LOGGER.info("Producer flush");
            producer.flush();
        } finally {
            LOGGER.info("Closing producer");
        }
    }
}
