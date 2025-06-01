@echo off
:: Gradle start script for Windows
set JAVA_HOME=%JAVA_HOME%
java -Xmx64m -Xms64m -classpath "gradle\wrapper\gradle-wrapper.jar" org.gradle.wrapper.GradleWrapperMain %*
