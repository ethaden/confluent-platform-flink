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
import picocli.CommandLine;
import picocli.CommandLine.Command;
import picocli.CommandLine.Option;
import picocli.CommandLine.Parameters;

@Command(name = "Consumer", version = "Kafka AVRO Consumer Example v1.0", mixinStandardHelpOptions = true)
public class Consumer implements Runnable {

    @Option(names = { "-p", "--poll" }, description = "Poll interval in ms. Default: 100")
    private int poll = 100;

    @Parameters(index = "0", arity = "1")
    private String configFile;

    private static final Logger LOGGER = LogManager.getLogger(MethodHandles.lookup().lookupClass());

    private Properties properties;
    private String topic;

    private Properties loadConfig() throws IOException {
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

    public void run() {
      try {
        this.properties = loadConfig();
        this.topic = this.properties.getProperty("topic");
        this.subscribe();
      } catch (IOException e)
      {
        System.err.println("Exception while reading config file: "+e);
      }
    }
    public static void main(String[] args) {
      int exitCode = new CommandLine(new Consumer()).execute(args);
      System.exit(exitCode);
    }

    public Consumer() {
    }

    private void subscribe() {
        LOGGER.info("Starting AVRO consumer");
        try (KafkaConsumer<String, SimpleValue> consumer = new KafkaConsumer<>(this.properties)) {
            // Subscribe to our topic
            LOGGER.info("Subscribing to topic " + this.topic);
            consumer.subscribe(List.of(this.topic));
            //noinspection InfiniteLoopStatement
            Duration poll_timeout = Duration.ofMillis(this.poll);
            while (true) {
                try {
                    final var records = consumer.poll(poll_timeout);
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
