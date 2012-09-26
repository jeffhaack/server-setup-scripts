#!/bin/bash

# Ubuntu 11.04 Natty Narwal
# This is for setting up PostgreSQL and PostGIS

# Install PostGIS
sudo apt-get update
sudo apt-get -y install postgresql postgresql-8.4-postgis

# Adjust PostgreSQL settings all to trust locally
echo "*********************************************"
echo "*****  Making PostgreSQL very trusting  *****"
echo "*********************************************"
sed -i s/"ident"/"trust"/ /etc/postgresql/8.4/main/pg_hba.conf
sed -i s/"md5"/"trust"/ /etc/postgresql/8.4/main/pg_hba.conf
sed -i s/"shared_buffers = 24MB"/"shared_buffers = 128MB"/ /etc/postgresql/8.4/main/postgresql.conf
sed -i s/"#checkpoint_segments = 3"/"checkpoint_segments = 20"/ /etc/postgresql/8.4/main/postgresql.conf
sed -i s/"#maintenance_work_mem = 16MB"/"maintenance_work_mem = 256MB"/ /etc/postgresql/8.4/main/postgresql.conf
sed -i s/"#autovacuum = on"/"autovacuum = off"/ /etc/postgresql/8.4/main/postgresql.conf
sudo sh -c "echo 'kernel.shmmax=268435456' > /etc/sysctl.d/60-shmmax.conf"
sudo service procps start
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

# Install osm2pgsql
sudo apt-get install osm2pgsql

# Get data
echo "Downloading data from http://download.geofabrik.de/osm/"
read -p "What continent? (default: asia): " continent
read -p "What country? (default: gaza): " country
echo "Getting http://download.geofabrik.de/osm/$continent/$country.osm.bz2..."
wget http://download.geofabrik.de/osm/$continent/$country.osm.bz2
#wget http://download.geofabrik.de/osm/asia/gaza.osm.bz2

# Import data
osm2pgsql --slim -U postgres -d $osm_db -C 2048 $country.osm.bz2

# Setup Osmosis
wget http://bretth.dev.openstreetmap.org/osmosis-build/osmosis-latest.tgz
tar xvfz osmosis-latest.tgz
cd osmosis-*
chmod a+x bin/osmosis
bin/osmosis

# Setup Minutely Mapnik updates
export WORKDIR_OSM=$HOME/.osmosis
mkdir $WORKDIR_OSM
osmosis --read-replication-interval-init workingDirectory=$WORKDIR_OSM
wget http://toolserver.org/~mazder/replicate-sequences/?2012-09-14T04:08:00Z -O $WORKDIR_OSM/state.txt
# sed to change the server
osm2pgsql --append [my customized arguments] changes.osc.gz
#osmosis -q --rri --bc --simc --bc --write-xml-change "-" | osm2pgsql -s -a -b "97.33,5.6,105.66,20.47" -U osm -d osm -e 15 -o expire.list -

# Install Mapnik
sudo add-apt-repository ppa:mapnik/boost
sudo apt-get update
sudo apt-get -y install libboost-dev libboost-filesystem-dev libboost-program-options-dev libboost-python-dev libboost-regex-dev libboost-system-dev libboost-thread-dev 
sudo apt-get install -y g++ cpp \
						libicu-dev \
						libboost-filesystem-dev \
						libboost-program-options-dev \
						libboost-python-dev libboost-regex-dev \
						libboost-system-dev libboost-thread-dev \
						python-dev libxml2 libxml2-dev \
						libfreetype6 libfreetype6-dev \
						libjpeg-dev \
						libltdl7 libltdl-dev \
						libpng-dev \
						libproj-dev libgeotiff1.2 \
						libtiff-dev \
						libcairo2 libcairo2-dev python-cairo python-cairo-dev \
						libcairomm-1.0-1 libcairomm-1.0-dev \
						ttf-unifont ttf-dejavu ttf-dejavu-core ttf-dejavu-extra \
						git build-essential python-nose clang \
						libgdal1-dev python-gdal \
						libsqlite3-dev
mkdir src
git clone git://github.com/mapnik/mapnik.git src/mapnik
cd src/mapnik
./configure && make && sudo make install




