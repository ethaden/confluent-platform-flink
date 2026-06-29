plugins {
    java
}

repositories {
    mavenCentral()
    maven("https://packages.confluent.io/maven")
}

dependencies {
    implementation("org.apache.logging.log4j:log4j-core:2.26.0")
    implementation("org.apache.logging.log4j:log4j-api:2.26.0")
    implementation("org.apache.logging.log4j:log4j-slf4j-impl:2.26.0")
    implementation("info.picocli:picocli:4.7.7")
    testImplementation("org.junit.jupiter:junit-jupiter-api:6.1.0")
    testRuntimeOnly("org.junit.jupiter:junit-jupiter-engine:6.1.0")
}

tasks.named<Test>("test") {
    useJUnitPlatform()
}
