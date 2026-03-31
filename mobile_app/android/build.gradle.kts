allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// O SEGREDO ESTÁ AQUI: "../build" aponta para mobile_app/build
rootProject.layout.buildDirectory.value(rootProject.layout.projectDirectory.dir("../build"))

subprojects {
    val subprojectDirectory = rootProject.layout.buildDirectory.get().dir(project.name)
    project.layout.buildDirectory.value(subprojectDirectory)
}

subprojects {
    project.configurations.all {
        resolutionStrategy.eachDependency {
            if (requested.group == "androidx.activity" && 
                (requested.name == "activity" || requested.name == "activity-ktx")) {
                useVersion("1.10.0")
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}