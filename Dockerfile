# Copyright (c) Jupyter Development Team.
# Distributed under the terms of the Modified BSD License.
ARG OWNER=jupyter
ARG BASE_CONTAINER=$OWNER/scipy-notebook
FROM $BASE_CONTAINER

LABEL maintainer="Minh Tran <gtdminh@gmail.com>"
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

USER root

# Spark dependencies
# Default values can be overridden at build time
# (ARGS are in lower case to distinguish them from ENV)
ARG spark_version="3.3.2"
ARG hadoop_version="3"
ARG scala_version
ARG spark_checksum="4cd2396069fbe0f8efde2af4fd301bf46f8c6317e9dea1dd42a405de6a38380635d49b17972cb92c619431acece2c3af4c23bfdf193cedb3ea913ed69ded23a1"
ARG openjdk_version="17"
ARG postgres_version="42.6.0"
ARG mysql_version="8.0.32"
ARG snowflake_version="3.9.2"

ENV APACHE_SPARK_VERSION="${spark_version}" \
    HADOOP_VERSION="${hadoop_version}"

RUN apt-get update --yes && \
    apt-get install --yes --no-install-recommends \
    "openjdk-${openjdk_version}-jre-headless" \
    ca-certificates-java \
    iputils-ping && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Spark installation
WORKDIR /tmp

# You need to use https://archive.apache.org/dist/ website if you want to download old Spark versions
# But it seems to be slower, that's why we use recommended site for download
RUN if [ -z "${scala_version}" ]; then \
    wget -qO "spark.tgz" "https://dlcdn.apache.org/spark/spark-${APACHE_SPARK_VERSION}/spark-${APACHE_SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz"; \
  else \
    wget -qO "spark.tgz" "https://dlcdn.apache.org/spark/spark-${APACHE_SPARK_VERSION}/spark-${APACHE_SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}-scala${scala_version}.tgz"; \
  fi && \
  echo "${spark_checksum} *spark.tgz" | sha512sum -c - && \
  tar xzf "spark.tgz" -C /usr/local --owner root --group root --no-same-owner && \
  rm "spark.tgz"

# Configure Spark
ENV SPARK_HOME=/usr/local/spark
ENV SPARK_OPTS="--driver-java-options=-Xms1024M --driver-java-options=-Xmx4096M --driver-java-options=-Dlog4j.logLevel=info" \
    PATH="${PATH}:${SPARK_HOME}/bin"

RUN if [ -z "${scala_version}" ]; then \
    ln -s "spark-${APACHE_SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}" "${SPARK_HOME}"; \
  else \
    ln -s "spark-${APACHE_SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}-scala${scala_version}" "${SPARK_HOME}"; \
  fi && \
  # Add a link in the before_notebook hook in order to source automatically PYTHONPATH && \
  mkdir -p /usr/local/bin/before-notebook.d && \
  ln -s "${SPARK_HOME}/sbin/spark-config.sh" /usr/local/bin/before-notebook.d/spark-config.sh


RUN wget "https://repo1.maven.org/maven2/net/snowflake/snowflake-jdbc/${snowflake_version}/snowflake-jdbc-${snowflake_version}.jar"
RUN wget "https://jdbc.postgresql.org/download/postgresql-${postgres_version}.jar"
RUN wget "https://repo1.maven.org/maven2/com/mysql/mysql-connector-j/${mysql_version}/mysql-connector-j-${mysql_version}.jar"
RUN cp /tmp/*.jar "${SPARK_HOME}/jars/"

ENV PYSPARK_SUBMIT_ARGS="--jars ${SPARK_HOME}/jars/snowflake-jdbc-${snowflake_version}.jar,${SPARK_HOME}/jars/postgresql-${postgres_version}.jar,${SPARK_HOME}/jars/mysql-connector-j-${mysql_version}.jar  pyspark-shell"

# Configure IPython system-wide
COPY ipython_kernel_config.py "/etc/ipython/"
RUN fix-permissions "/etc/ipython/"

USER ${NB_UID}

# Install pyarrow
RUN mamba install --yes \
    'pyarrow' && \
    mamba clean --all -f -y && \
    fix-permissions "${CONDA_DIR}" && \
    fix-permissions "/home/${NB_USER}"

WORKDIR "${HOME}"
EXPOSE 4040