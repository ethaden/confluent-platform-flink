import com.github.benmanes.gradle.versions.updates.DependencyUpdatesTask

plugins {
    id("java-application-conventions")
    id("kafka-java-conventions")
    id("com.github.davidmc24.gradle.plugin.avro") version "1.9.1"
    id("com.github.ben-manes.versions") version "0.54.0"
}

val avroVersion = "1.12.0"

dependencies {
    compileOnly("org.apache.avro:avro-tools:$avroVersion")
//    implementation(project(":utilities"))
}

application {
    mainClass.set("io.confluent.ethaden.examples.kafka.Produce")
}

avro {
    setCreateSetters(false)
}


tasks.withType<com.github.benmanes.gradle.versions.updates.DependencyUpdatesTask> {
    resolutionStrategy {
        componentSelection {
            // Explicitly declare the type of the selection parameter
            all { selection: ComponentSelection -> 
                fun String.isNonStable(): Boolean {
                    val stableKeywords = listOf("RELEASE", "FINAL", "GA")
                    val isStableKeyword = stableKeywords.any { this.uppercase().contains(it) }
                    val isSemantic = this.matches(Regex("^[0-9,.v-]+(-r)?$"))
                    return !isStableKeyword && !isSemantic
                }

                if (selection.candidate.version.isNonStable()) {
                    selection.reject("Release candidate")
                }
            }
        }
    }
}
