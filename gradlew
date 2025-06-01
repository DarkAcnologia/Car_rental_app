#!/usr/bin/env sh
##############################################################################
## Gradle start script for UN*X                                            ##
##############################################################################
export JAVA_HOME=${JAVA_HOME}
exec java -Xmx64m -Xms64m -classpath "gradle/wrapper/gradle-wrapper.jar" org.gradle.wrapper.GradleWrapperMain "$@"
