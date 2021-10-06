FROM adoptopenjdk/openjdk8

ENV SCHEMA_FILE=

ENV SRC_HOST=
ENV SRC_PORT=1433
ENV SRC_USER=
ENV SRC_PWD=
ENV SRC_DB=

ENV DST_HOST=
ENV DST_PORT=5432
ENV DST_USER=
ENV DST_PWD=
ENV DST_DB=

ENV MIGRATIONDIR=/opt/data_migration

RUN mkdir -p $MIGRATIONDIR

RUN apt-get update; apt-get install perl netcat -y; \
    apt-get install wget unzip postgresql-client -y

RUN wget --progress=dot:giga https://sourceforge.net/projects/pentaho/files/latest/download?source=files -O /tmp/kettle.zip; \
    unzip /tmp/kettle.zip -d /tmp/kettle; \
    mv /tmp/kettle/data-integration $MIGRATIONDIR; \
    chmod -R +x $MIGRATIONDIR/data-integration/*.sh

RUN wget https://sourceforge.net/projects/jtds/files/latest/download?source=files -O /tmp/jtds.zip; \
    unzip /tmp/jtds.zip -d /tmp/jtds; \
    cp /tmp/jtds/jtds-*.jar $MIGRATIONDIR/data-integration/lib/; \
    rm -Rf /tmp/jtds;rm -f /tmp/jtds.zip

RUN wget https://raw.githubusercontent.com/dalibo/sqlserver2pgsql/master/sqlserver2pgsql.pl -P $MIGRATIONDIR; \
    # need ssl=require attribute to connect to Azure SQL:
    sed -i 's#<attribute><code>EXTRA_OPTION_MSSQL.instance#<attribute><code>EXTRA_OPTION_MSSQL.ssl</code><attribute>require</attribute></attribute><attribute><code>EXTRA_OPTION_MSSQL.instance#g' $MIGRATIONDIR/sqlserver2pgsql.pl; \
    # using certs to connect to Cloud SQL for Postgres:
    sed -i "s#<attribute><code>EXTRA_OPTION_POSTGRESQL.reWriteBatchedInserts#<attribute><code>EXTRA_OPTION_POSTGRESQL.ssl</code><attribute>true</attribute></attribute>\n<attribute><code>EXTRA_OPTION_POSTGRESQL.sslmode</code><attribute>verify-ca</attribute></attribute>\n<attribute><code>EXTRA_OPTION_POSTGRESQL.sslcert</code><attribute>$MIGRATIONDIR/conf/client-cert.pem</attribute></attribute>\n<attribute><code>EXTRA_OPTION_POSTGRESQL.sslkey</code><attribute>$MIGRATIONDIR/conf/client-key.pk8</attribute></attribute>\n<attribute><code>EXTRA_OPTION_POSTGRESQL.sslrootcert</code><attribute>$MIGRATIONDIR/conf/server-ca.pem</attribute></attribute>\n<attribute><code>EXTRA_OPTION_POSTGRESQL.reWriteBatchedInserts#g" $MIGRATIONDIR/sqlserver2pgsql.pl; \
    chmod +x $MIGRATIONDIR/sqlserver2pgsql.pl

COPY ./scripts /scripts
RUN chmod +x /scripts/*.sh

WORKDIR $MIGRATIONDIR

# CMD ["sh", "/scripts/migrate.sh"]