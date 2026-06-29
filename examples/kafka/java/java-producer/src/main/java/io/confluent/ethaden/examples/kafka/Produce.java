package io.confluent.ethaden.examples.kafka;

import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import static java.lang.Thread.sleep;
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
import models.avro.SimpleValue;
import picocli.CommandLine;
import picocli.CommandLine.Command;
import picocli.CommandLine.Option;
import picocli.CommandLine.Parameters;

@Command(name = "Producer", version = "Kafka AVRO Producer Example v1.0", mixinStandardHelpOptions = true)
public class Produce implements Runnable {

    @Option(names = { "-c", "--count" }, description = "Number of of messages to be produced. Set to \"-1\" for unlimited number of messages. Default: 10")
    private int count = 10;

    @Option(names = { "-w", "--wait" }, description = "Time to wait between sending messages in ms. \"-1\": do not wait. Default: 1000")
    private int wait = 1000;

    @Parameters(index = "0", arity = "1")
    private String configFile;

    private static final Logger LOGGER = LogManager.getLogger(MethodHandles.lookup().lookupClass());

    private Properties properties;
    private String topic;

    public Produce() {
    }

    @Override
    public void run() {
        try {
            this.properties = loadConfig();
            this.topic = this.properties.getProperty("topic");
            this.sendAvroProducer();
        } catch (IOException e) {
            System.err.println("Exception while reading config file: "+e);
        }
    }

    public static void main(String[] args) {
        int exitCode = new CommandLine(new Produce()).execute(args);
        System.exit(exitCode);
    }

    private Properties loadConfig() throws IOException {
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

    void sendAvroProducer() {
        LOGGER.info("Starting AVRO Producer");
        try (KafkaProducer<String, SimpleValue> producer = new KafkaProducer<>(this.properties)) {
            int n=0;
            while (count==-1 || n<count) {
                String key = Integer.toString(n);
                SimpleValue value = SimpleValue.newBuilder()
                        .setTheName("This is message " + key)
                        .setTheValue("This is the value")
                        .build();
                ProducerRecord<String, SimpleValue> producerRecord = new ProducerRecord<>(this.topic, key, value);
                LOGGER.info("Sending message {}", n);
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
              n++;
              if (wait>0) {
                try {
                    sleep(wait);                    
                } catch (InterruptedException e) {
                  break;
                }
              }
            }
            LOGGER.info("Producer flush");
            producer.flush();
        } finally {
            LOGGER.info("Closing producer");
        }
    }
}
