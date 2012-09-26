#!/bin/bash

# Ubuntu 11.04 Natty Narwal
# This is for setting up PostgreSQL and PostGIS

sudo apt-get update
sudo apt-get -y install postgresql postgresql-8.4-postgis

# Adjust PostgreSQL settings all to trust locally
echo "*********************************************"
echo "*****  Making PostgreSQL very trusting  *****"
echo "*********************************************"
sed -i s/"ident"/"trust"/ /etc/postgresql/8.4/main/pg_hba.conf
sed -i s/"md5"/"trust"/ /etc/postgresql/8.4/main/pg_hba.conf
sudo /etc/init.d/postgresql restart

# Create an OSM database
osm_db="osm" # default
read -p "Would you like to create a database for OpenStreetMap data? (y/n): " make_osm
if [ "$make_osm" == "y" ]
  then
  	read -p "Please give the database a name: " osm_db
    psql -U postgres -c "create database $osm_db;"
    psql -U postgres -d $osm_db -c "create language plpgsql;"
    psql -U postgres -d $osm_db -f /usr/share/postgresql/8.4/contrib/postgis-1.5/postgis.sql
    psql -U postgres -d $osm_db -f /usr/share/postgresql/8.4/contrib/postgis-1.5/spatial_ref_sys.sql
fi

# Install imposm or osm2pgsql or both
read -p "Install (1)imposm, (2)osm2pgsql, or (3)both: " import_prog
if [[ "$import_prog" == "1" || "$import_prog" == "3" ]]
  then
  	echo "Installing imposm..."
  	sudo apt-get -y install build-essential python-dev protobuf-compiler libprotobuf-dev \
  							libtokyocabinet-dev python-psycopg2 libgeos-c1
  	sudo apt-get -y install python-pip
  	sudo pip install imposm
fi
if [[ "$import_prog" == "2" || "$import_prog" == "3" ]]
  then
	sudo apt-get install osm2pgsql
fi

# How to import
echo "Setup complete. To import OSM data into your database, run:"
echo ""
echo "imposm -U postgres -d $osm_db -m /path/to/osm-bright/imposm-mapping.py \ "
echo "--read --write --optimize --deploy-production-tables <your_osm_data_file>"
echo ""
echo "or"
echo ""
echo "osm2pgsql -c -G -U postgres -d $osm_db <your_osm_data_file>"







