allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    val sub = this
    sub.afterEvaluate {
        plugins.withId("com.android.library") {
            val android = extensions.getByName("android")
                as com.android.build.gradle.LibraryExtension
            if (android.namespace == null) {
                val manifest = android.sourceSets.getByName("main").manifest.srcFile
                val pkg = groovy.xml.XmlParser().parse(manifest).attribute("package") as? String
                if (pkg != null) android.namespace = pkg
            }
            android.compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
        }
        plugins.withId("org.jetbrains.kotlin.android") {
            tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile::class.java) {
                compilerOptions {
                    jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
                }
                // tesseract_ocr 0.5.0 packs a .kt stub next to its real .java
                // implementation; K2 treats it as a redeclaration.
                exclude("**/TesseractOcrPlugin.kt")
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
