# Overview

This project helps create a docker container that can migrate data from Azure SQL to Cloud SQL for Postgres using the open-source [sqlserver2pgsql](https://github.com/dalibo/sqlserver2pgsql).

There's a `Dockerfile` in the project's root dir and this file is configured to  
1. Download the `sqlserver2pgsql.pl` perl script from its git repo
2. Update `sqlserver2pgsql.pl` to add support for Azure SQL (include the ssl=required option in the db connection) and for connecting to Postgres using certs
3. Download and unzip Pentaho, an open-source data integration platform used by sqlserver2pgsql
4. Download jTDS, an open-source JDBC driver for connecting to SQL Server. 
5. Copy the `scripts/migrate.sh` script to the container to be used for running the actual data migration


# Step 1 - Build container
Run below command in the project's root folder:

```
docker build -t sqlserver2psql .
```

# Step 2 - Export DB schema from Azure SQL
1. Under SQL Server Management Studio, Right click on the database you want to export
2. Select Generate Scripts...
3. Click "Next" on the welcome screen (if it hasn't already been deactivated)
4. Select your database
5. In the list of things you can export, just change "Script Indexes" from False to True, then "Next"
6. Select Tables then "Next"
7. Select the tables you want to export (or select all), then "Next"
8. Script to file, choose a filename, then "Next"
9. Select unicode encoding (who knows…, maybe someone has put accents in objects names, or in comments)
10. Finish

Save the schema file (ie: `schema.sql`) under folder `<project root dir>/conf` (create the folder, if necessary).

# Step 3 - Get certs for Postgres

Follow steps at https://cloud.google.com/sql/docs/postgres/configure-ssl-instance to download certs. You may need to download the client key cert from the GCP Secret Manager.

Once the certs are downloaded, copy them to folder `<project root dir>/conf`.

Make sure the cert files are saved with these names: `server-ca.pem`, `client-cert.pem` and `client-key.pem`.


# Step 4 - Run container in docker
To do the migration using docker run below command:

```
docker run --name sqlserver2psql --rm -e SRC_HOST=<Azure SQL instance>.database.windows.net -e SRC_USER=<SQL Server username> -e SRC_PWD=<SQL Server password> -e SRC_DB=<SQL Server db name> -e DST_HOST=<Postgres host> -e DST_PORT=5432 -e DST_USER=<Postgres username> -e DST_PWD=<Postgres password> -e DST_DB=<Postgres db name> -e SCHEMA_FILE=<name of of db export file in conf folder, ie: schema.sql>  --mount type=bind,source="$(pwd)"/conf,target=/opt/data_migration/conf sqlserver2psql /scripts/migrate.sh
```

Above command includes a mount from the local `<project root dir>/conf` folder to the `/opt/data_migration/conf` folder within the container. This `conf` folder should include the schema export file and the cert files needed for Postgres.

The `scripts/migrate.sh` command will do the data migration using these steps:
1. Run the `sqlserver2pgsql.pl` perl script to generate postgres scripts to be run before and after the migration, and also the files needed to be run the migration in Pentaho's Kettle tool as a job
2. Run the generated 'before' script (to create db schema)
3. Update the Kettle job file to fix an issue with Cloud SQL for Postgres (removing the `CREATE CAST` SQL command)
4. Run the Kettle job
5. Run the generated 'after' script (to add primary keys, foreign keys, constraints, etc.)
