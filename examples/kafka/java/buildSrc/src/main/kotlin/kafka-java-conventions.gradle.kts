plugins {
    id("java-common-conventions")
}

dependencies {
    implementation("org.apache.kafka:kafka-clients:8.3.0-ce")
    implementation("io.confluent:kafka-streams-avro-serde:8.3.0")
}
