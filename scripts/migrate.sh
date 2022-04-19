Page up
#!/bin/bash
  
set -e

echo !!! Creating Kettle job && \
./sqlserver2pgsql.pl -b before.sql -a after.sql -u unsure.sql -k kettlejobs -stringtype_unspecified -f conf/$SCHEMA_FILE \
  -sh $SRC_HOST -sp $SRC_PORT -su $SRC_USER -sw $SRC_PWD -sd $SRC_DB \
  -ph $DST_HOST -pp $DST_PORT -pu $DST_USER -pw $DST_PWD -pd $DST_DB

echo !!! Executing before.sql && \
# restricting access to key file as per psql requirements:
chmod 0600 conf/client-key.pem && \
PGPASSWORD=$DST_PWD psql -h $DST_HOST -p $DST_PORT -U $DST_USER -d $DST_DB {{#if (eval targetSslCerts '==' true)}}-v sslmode=verify-ca -v sslrootcert=conf/server-ca.pem -v sslcert=conf/client-cert.pem -v sslkey=conf/client-key.pem{{/if}} -f before.sql

# {{#if (eval postgresOnGcp '==' true)}}
# removing SQL code that was causing issue in GCP due to lack of superuser permissions (https://github.com/dalibo/sqlserver2pgsql/issues/124):
sed -i 's/DROP CAST IF EXISTS &#x28;varchar as date&#x29;//g' kettlejobs/migration.kjb
sed -i 's/CREATE CAST &#x28;varchar as date&#x29; with inout as implicit;//g' kettlejobs/migration.kjb
sed -i 's/DROP CAST &#x28;varchar as date&#x29;//g' kettlejobs/migration.kjb
# {{/if}}

echo !!! Running Kettle job && \
data-integration/kitchen.sh -file=kettlejobs/migration.kjb -level=rowlevel

echo !!! Executing after.sql && \
PGPASSWORD=$DST_PWD psql -h $DST_HOST -p $DST_PORT -U $DST_USER -d $DST_DB {{#if (eval targetSslCerts '==' true)}}-v sslmode=verify-ca -v sslrootcert=conf/server-ca.pem -v sslcert=conf/client-cert.pem -v sslkey=conf/client-key.pem{{/if}} -f after.sql