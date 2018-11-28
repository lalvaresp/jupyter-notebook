FROM jupyter/all-spark-notebook

# Build arguments
ARG AMBARI_USER
ARG AMBARI_PASSWORD
ARG AMBARI_HOST
ARG CLUSTER_NAME
ARG KERBEROS_REALM
ARG KADM_SERVER
ARG KDC_SERVER
ARG MASTER_HOST

USER root

RUN apt-get update && apt-get install -y openjdk-8-jdk krb5-workstation wget which maven vim && apt-get clean -y

RUN wget -nv http://public-repo-1.hortonworks.com/HDP/centos7/2.x/updates/2.6.5.0/hdp.repo -O /etc/yum.repos.d/hortonworks.repo
RUN yum install -y hadoop-client spark2 spark2-python hive-server2 hbase oozie-client kafka phoenix-queryserver

COPY conf/krb5.conf.tmpl /tmp/krb5.conf.tmpl

RUN sed -e "s/\${KERBEROS_REALM}/$KERBEROS_REALM/" -e "s/\${KADM_SERVER}/$KADM_SERVER/" -e "s/\${KDC_SERVER}/$KDC_SERVER/" /tmp/krb5.conf.tmpl > /etc/krb5.conf

WORKDIR /tmp

# Set environment variables
ENV JAVA_HOME /usr/lib/jvm/java
ENV KAFKA_KERBEROS_PARAMS "-Djavax.security.auth.useSubjectCredsOnly=false -Djava.security.auth.login.config=/usr/hdp/current/kafka-broker/config/kafka_client_jaas.conf"
ENV HADOOP_CLASSPATH /usr/hdp/current/hbase-client/lib/*:/usr/hdp/current/hbase-client/conf/

# Configure
## HDFS
RUN curl --user $AMBARI_USER:$AMBARI_PASSWORD -H "X-Requested-By: ambari" -X GET $AMBARI_HOST/api/v1/clusters/$CLUSTER_NAME/services/HDFS/components/HDFS_CLIENT?format=client_config_tar -o hdfs-config.tar.gz
RUN tar -xf hdfs-config.tar.gz
RUN cp core-site.xml /usr/hdp/current/hadoop-client/conf
RUN cp hdfs-site.xml /usr/hdp/current/hadoop-client/conf
COPY conf/topology_script.py /usr/hdp/current/hadoop-client/conf
COPY get_slaves.py /tmp/get_slaves.py
RUN python /tmp/get_slaves.py $AMBARI_USER $AMBARI_PASSWORD $AMBARI_HOST $CLUSTER_NAME


## YARN
RUN curl --user $AMBARI_USER:$AMBARI_PASSWORD -H "X-Requested-By: ambari" -X GET $AMBARI_HOST/api/v1/clusters/$CLUSTER_NAME/services/YARN/components/YARN_CLIENT?format=client_config_tar -o yarn-config.tar.gz
RUN tar -xf yarn-config.tar.gz
RUN cp capacity-scheduler.xml /usr/hdp/current/hadoop-client/conf
RUN cp yarn-site.xml /usr/hdp/current/hadoop-client/conf

## MR2
RUN curl --user $AMBARI_USER:$AMBARI_PASSWORD -H "X-Requested-By: ambari" -X GET $AMBARI_HOST/api/v1/clusters/$CLUSTER_NAME/services/MAPREDUCE2/components/MAPREDUCE2_CLIENT?format=client_config_tar -o mapred-config.tar.gz
RUN tar -xf mapred-config.tar.gz
RUN cp mapred-site.xml /usr/hdp/current/hadoop-client/conf

## SPARK2
RUN curl --user $AMBARI_USER:$AMBARI_PASSWORD -H "X-Requested-By: ambari" -X GET $AMBARI_HOST/api/v1/clusters/$CLUSTER_NAME/services/SPARK2/components/SPARK2_CLIENT?format=client_config_tar -o spark-config.tar.gz
RUN tar -xf spark-config.tar.gz
RUN cp spark-defaults.conf /usr/hdp/current/spark2-client/conf

## HIVE
RUN curl --user $AMBARI_USER:$AMBARI_PASSWORD -H "X-Requested-By: ambari" -X GET $AMBARI_HOST/api/v1/clusters/$CLUSTER_NAME/services/HIVE/components/HIVE_CLIENT?format=client_config_tar -o hive-config.tar.gz
RUN tar -xf hive-config.tar.gz
RUN cp hive-site.xml /usr/hdp/current/hive-client/conf

## TEZ
RUN curl --user $AMBARI_USER:$AMBARI_PASSWORD -H "X-Requested-By: ambari" -X GET $AMBARI_HOST/api/v1/clusters/$CLUSTER_NAME/services/TEZ/components/TEZ_CLIENT?format=client_config_tar -o tez-config.tar.gz
RUN tar -xf tez-config.tar.gz
RUN cp tez-site.xml /usr/hdp/current/tez-client/conf

## HBASE
RUN curl --user $AMBARI_USER:$AMBARI_PASSWORD -H "X-Requested-By: ambari" -X GET $AMBARI_HOST/api/v1/clusters/$CLUSTER_NAME/services/HBASE/components/HBASE_CLIENT?format=client_config_tar -o hbase-config.tar.gz
RUN tar -xf hbase-config.tar.gz
RUN cp hbase-site.xml /usr/hdp/current/hbase-client/conf
RUN cp hbase-policy.xml /usr/hdp/current/hbase-client/conf

## KAFKA
COPY conf/kafka_jaas.conf.tmpl /tmp/kafka_jaas.conf.tmpl
RUN sed -e "s/\${KERBEROS_REALM}/$KERBEROS_REALM/" -e "s/\${MASTER_HOST}/$MASTER_HOST/" /tmp/kafka_jaas.conf.tmpl > /usr/hdp/current/kafka-broker/config/kafka_jaas.conf

# Clean /tmp
RUN rm -rf /tmp/*

RUN chmod a+wrx /tmp

COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT /entrypoint.sh
