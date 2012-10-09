#!/bin/bash

########################################################################
# Copyright (C) 2012 Jeff Haack
# 
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This script will take a freshly setup Ubuntu 11.04 machine and set it
# up with an OpenStreetMap database that is continually updated.  It
# also sets up Mapnik to render tiles and images.
########################################################################

########## USER OPTIONS - DON'T CHANGE UNLESS YOU KNOW WHAT YOU'RE DOING ###########
EXPORT_FILE="http://download.geofabrik.de/openstreetmap/asia/gaza.osm.bz2" 	# The file you want to download and import
OSM_FILE="gaza.osm.bz2"
LANGUAGE="name:ka" # add a name tag into the database (your stylesheet still must utilize this)
# We need the bounding box of this area
MIN_LON="34.125" 	# left
MIN_LAT="31.16" 	# bottom
MAX_LON="34.648" 	# right
MAX_LAT="31.708" 	# top
DB_NAME="osm" 		# The name you want your database to have (you can change this)
DB_USER=postgres 	# The database user for the DB - (don't change this)
CRON_TIME="0,5,10,15,20,25,30,35,40,45,50,55 * * * *" 	# How often should the database be updated?

# Directories
HOME=~
SETUP=$HOME/server-setup-scripts
SRC=$HOME/src
DATA=$HOME/data
BIN=$HOME/bin
DIFF_WORKDIR=$DATA/.diffs
OSM2PGSQL_STYLESHEET=$DATA/multilingual.style

# Program Locations - we will install these programs if they don't already exist
POSTGRESQL=/etc/init.d/postgresql
APACHE=/etc/init.d/apache2
OSMOSIS=/bin/osmosis
OSM2PGSQL=/usr/bin/osm2pgsql
MAPNIK_PYTHON_DIR=/var/lib/python-support/python2.7/mapnik/

if [[ "$1" == "-y" ]] ; then
	SKIP_PROMPTING="yes"
fi

cd $HOME
# Update apt-get (can use a switch to turn off updating during testing)
if [[ "$1" == "--no-update" || "$1" == "-nu" || "$1" == "-y" ]] ; then
	echo "Not updating apt-get..."
else
	echo "Updating apt-get..."
	sudo apt-get update
fi

# Make directories
if [ ! -d $SRC ]; then
	echo "Making directory $SRC"
	mkdir $SRC
else
	echo "Directory $SRC exists"
fi
if [ ! -d $DATA ]; then
	echo "Making directory $DATA"
	mkdir $DATA
else
	echo "Directory $DATA exists"
fi
if [ ! -d $BIN ]; then
	echo "Making directory $BIN"
	mkdir $BIN
else
	echo "Directory $BIN exists"
fi

# Install PostGIS
if [ ! -x $POSTGRESQL ]; then
	echo "Installing PostgreSQL 8.4 and PostGIS extensions..."
	sudo apt-get -y install postgresql postgresql-8.4-postgis postgresql-contrib-8.4
	# Adjust PostgreSQL settings all to trust locally
	# And adjust settings for import
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
else
	echo "PostgreSQL 8.4 and PostGIS extensions already installed..."
fi

# Install Apache
if [ ! -x $APACHE ]; then
	echo "Installing Apache2..."
	sudo apt-get -y install apache2
else
	echo "Apache already installed..."
fi

# Setup Osmosis
if [ ! -x $OSMOSIS ]; then
	echo "Installing Osmosis..."
	cd $SRC
	sudo apt-get -y install openjdk-6-jdk
	wget http://bretth.dev.openstreetmap.org/osmosis-build/osmosis-latest.tgz
	tar xvfz osmosis-latest.tgz
	cd osmosis-*
	chmod a+x bin/osmosis
	ln -s $SRC/osmosis-*/bin/osmosis /bin/osmosis
	cd $HOME
else
	echo "Osmosis already installed..."
fi

# Install osm2pgsql
if [ ! -x $OSM2PGSQL ]; then
	echo "Installing Osm2pgsql..."
	sudo apt-get -y install osm2pgsql
else
	echo "Osm2pgsql already installed..."
fi

# Install Mapnik
if [ ! -d $MAPNIK_PYTHON_DIR ]; then
	echo "Installing Mapnik..."
	sudo apt-get -y install libmapnik0.7 libmapnik-dev mapnik-utils python-mapnik
else
	echo "Mapnik already installed..."
fi

# Create an OSM database
if [[ ! "$1" == "-y" ]] ; then
	read -p "Would you like to create a database named $DB_NAME for OpenStreetMap data? (y/n): " make_osm
else
	make_osm="y"
fi
if [[ "$make_osm" == [Yy] ]]; then
    psql -U postgres -c "create database $DB_NAME;"
    psql -U postgres -d $DB_NAME -c "create language plpgsql;"
    psql -U postgres -d $DB_NAME -f /usr/share/postgresql/8.4/contrib/postgis-1.5/postgis.sql
    psql -U postgres -d $DB_NAME -f /usr/share/postgresql/8.4/contrib/postgis-1.5/spatial_ref_sys.sql
    psql -U postgres -d $DB_NAME -f /usr/share/postgresql/8.4/contrib/_int.sql # need this for the diff updating
fi

# Get data
if [[ ! "$1" == "-y" ]] ; then
	read -p "Would you like to download data from Geofabrik? (y/n): " get_data
else
	get_data="y"
fi
if [[ "$get_data" == [Yy] ]]; then
	echo "Downloading $EXPORT_FILE..."
	wget $EXPORT_FILE -O $DATA/$OSM_FILE
fi

# Import data
if [[ "$make_osm" == [Yy] && "$get_data" == [Yy] ]]; then
	if [[ ! "$1" == "-y" ]] ; then
		read -p "Import the data file into your database? (y/n): " import_data
	else
		import_data="y"
	fi
	if [[ "$import_data" == [Yy] ]]; then
		##############################
		### Making it multilingual ###
		cp /usr/share/osm2pgsql/default.style $OSM2PGSQL_STYLESHEET
		echo "node,way   $LANGUAGE      text         linear" >> $OSM2PGSQL_STYLESHEET
		##############################

		osm2pgsql --slim -U postgres -d $DB_NAME -S $OSM2PGSQL_STYLESHEET -C 2048 $DATA/$OSM_FILE
	fi
else
	echo "Not importing file into database..."
	#read -p "Import the data file into your database? (y/n): " import_data
	#if [[ "$import_data" == [Yy] ]]; then
	#	read -p "What is the database name? (default: $DB_NAME): " DB_NAME
	#	read -p "What is the file name? (default: $DATA/$COUNTRY.osm.bz2): " FILE_NAME
	#	cd $DATA
	#	osm2pgsql --slim -U postgres -d $DB_NAME -C 2048 $FILE_NAME
	#fi
fi

# Setup Minutely Mapnik updates
if [[ ! "$1" == "-y" ]] ; then
	read -p "Would you like to import minutely mapnik diffs: (y/n) " update_diffs
else
	update_diffs="y"
fi
if [[ "$update_diffs" == [Yy] ]]; then
	echo "Diff information will be stored in $DIFF_WORKDIR"
	echo "Using the file $DATA/$OSM_FILE"
	echo "Using the bounding box $MIN_LON,$MIN_LAT,$MAX_LON,$MAX_LAT"
	YEAR=$(date -r $DATA/$OSM_FILE +%Y)
	MONTH=$(date -r $DATA/$OSM_FILE +%m)
	DAY=$(date -r $DATA/$OSM_FILE +%d)
	HOUR=$(date -r $DATA/$OSM_FILE +%k)
	MINUTE=$(date -r $DATA/$OSM_FILE +%M)
	SECOND=$(date -r $DATA/$OSM_FILE +%S)
	echo "We're going to load recent changes first..."
	if [ ! -d $DIFF_WORKDIR ]; then
		mkdir $DIFF_WORKDIR
	fi
	osmosis --read-replication-interval-init workingDirectory=$DIFF_WORKDIR
	wget "http://toolserver.org/~mazder/replicate-sequences/?Y=$YEAR&m=$MONTH&d=$DAY&H=$HOUR&i=$MINUTE&s=$SECOND&stream=minute#" -O $DIFF_WORKDIR/state.txt
	sed -i s/"minute-replicate"/"replication\/minute"/ $DIFF_WORKDIR/configuration.txt
	osmosis -q --rri workingDirectory=$DIFF_WORKDIR --simc --write-xml-change $DATA/changes.osc.gz
	osm2pgsql -a -s -b "$MIN_LON,$MIN_LAT,$MAX_LON,$MAX_LAT" -U postgres -d $DB_NAME -e 15 -o $DATA/expire.list -S $OSM2PGSQL_STYLESHEET $DATA/changes.osc.gz
fi

# Setup Cron Job
# We'll create a script to update the database and then add it to the crontab
if [[ ! "$1" == "-y" ]] ; then
	read -p "Would you like to add diff updating to cron? (y/n): " update_cron
else
	update_cron="y"
fi
if [[ "$update_cron" == [Yy] ]]; then
	touch $DATA/update_osm_db.sh
	echo "#!/bin/bash
# This script will update the $DB_NAME database with OpenStreetMap Data...
# We need the bounding box of this area
MIN_LON=34.125 	# left
MIN_LAT=31.16 	# bottom
MAX_LON=34.648 	# right
MAX_LAT=31.708 	# top

DB_NAME=osm
DB_USER=postgres

# Directories
HOME=~
SRC=\$HOME/src
DATA=\$HOME/data
DIFF_WORKDIR=\$DATA/.diffs

#YEAR=\$(date -r \$DATA/changes.osc.gz +%Y)
#MONTH=\$(date -r \$DATA/changes.osc.gz +%m)
#DAY=\$(date -r \$DATA/changes.osc.gz +%d)
#HOUR=\$(date -r \$DATA/changes.osc.gz +%k)
#MINUTE=\$(date -r \$DATA/changes.osc.gz +%M)
#SECOND=\$(date -r \$DATA/changes.osc.gz +%S)

#rm -rf \$DIFF_WORKDIR/*
rm \$DATA/expire.list
rm \$DATA/changes.osc.gz.prev
cp \$DATA/changes.osc.gz \$DATA/changes.osc.gz.prev
rm \$DATA/changes.osc.gz

#osmosis --read-replication-interval-init workingDirectory=\$DIFF_WORKDIR
#wget \"http://toolserver.org/~mazder/replicate-sequences/?Y=\$YEAR&m=\$MONTH&d=\$DAY&H=\$HOUR&i=\$MINUTE&s=\$SECOND&stream=minute#\" -O \$DIFF_WORKDIR/state.txt
#sed -i s/\"minute-replicate\"/\"replication\/minute\"/ \$DIFF_WORKDIR/configuration.txt
osmosis -q --rri workingDirectory=\$DIFF_WORKDIR --simc --write-xml-change \$DATA/changes.osc.gz
osm2pgsql -a -s -b \"\$MIN_LON,\$MIN_LAT,\$MAX_LON,\$MAX_LAT\" -U postgres -d \$DB_NAME -e 15 -o \$DATA/expire.list -S $OSM2PGSQL_STYLESHEET \$DATA/changes.osc.gz" > $DATA/update_osm_db.sh

	chmod +x $DATA/update_osm_db.sh
	#write out current crontab
	crontab -l > mycron
	#echo new cron into cron file
	echo "$CRON_TIME $DATA/update_osm_db.sh" >> mycron
	#install new cron file
	crontab mycron
	rm mycron
fi

# Set up the mapnik stylesheet
sudo apt-get -y install unzip
cd $DATA
mkdir shp
wget http://mapbox-geodata.s3.amazonaws.com/natural-earth-1.3.0/physical/10m-land.zip
wget http://tilemill-data.s3.amazonaws.com/osm/coastline-good.zip
wget http://tilemill-data.s3.amazonaws.com/osm/shoreline_300.zip
unzip 10m-land.zip
unzip coastline-good.zip
unzip shoreline_300.zip


# Set up mod_tile and renderd
# First retrieve and install the stuff
cd $BIN
sudo apt-get -y install subversion autoconf make
sudo apt-get -y install libagg-dev apache2-prefork-dev
svn co http://svn.openstreetmap.org/applications/utils/mod_tile
cd mod_tile
./autogen.sh
sed -i s/"#define MAPNIK_PLUGINS \"\/usr\/local\/lib64\/mapnik\/input\""/"#define MAPNIK_PLUGINS \"\/usr\/lib64\/mapnik\/0.7\/input\/\""/ render_config.h
sed -i s/"\/usr\/local\/lib64\/mapnik\/fonts"/"\/usr\/share\/fonts"/ render_config.h
sed -i s/"#define FONT_RECURSE 0"/"#define FONT_RECURSE 3"/ render_config.h
./configure
make
make install
make install-mod_tile
ldconfig

# Edit the apache module settings in mod_tile.conf
cp mod_tile.conf /etc/apache2/conf.d
sed -i s/"<VirtualHost *:80>"/"<VirtualHost *>"/ /etc/apache2/conf.d/mod_tile.conf
sed -i s/"modules\/mod_tile.so"/"\/usr\/lib\/apache2\/modules\/mod_tile.so"/ /etc/apache2/conf.d/mod_tile.conf
IP=$(curl ifconfig.me)
sed -i s/"a.tile.openstreetmap.org b.tile.openstreetmap.org c.tile.openstreetmap.org d.tile.openstreetmap.org"/"$IP"/ /etc/apache2/conf.d/mod_tile.conf
sed -i s/"\/var\/www\/html"/"\/var\/www"/ /etc/apache2/conf.d/mod_tile.conf
sed -i s/"\/var\/run\/renderd\/renderd.sock"/"\/tmp\/osm-renderd"/ /etc/apache2/conf.d/mod_tile.conf

# Now edit the renderd daemon settings
touch /etc/renderd.conf
echo "[renderd]
;socketname=/var/run/renderd/renderd.sock
num_threads=4
tile_dir=/var/lib/mod_tile ; DOES NOT WORK YET
stats_file=/root/bin/renderd.stats

[mapnik]
plugins_dir=/usr/lib64/mapnik/0.7/input
font_dir=/usr/share/fonts
font_dir_recurse=3

[default]
URI=/my_tiles/
XML=/root/server-setup-scripts/mapnik/osm.xml
HOST=198.101.248.107
;HTCPHOST=proxy.openstreetmap.org" > /etc/renderd.conf

# And start up the daemon and restart Apache
$BIN/mod_tile/renderd
/etc/init.d/apache2 restart

# Add our sample map.html to /var/ww
cd $SETUP
cp map.html /var/www/map.html
sed -i s/"TILE_LOCATION"/"$IP\/my_tiles"/ /var/www/map.html
echo "Go to http://$IP/map.html to see."

################################################################################################




### AWESOME!! ###
# Next Steps #
#
# Setup mod_tile and renderd
# Make an OSM stylesheet that works
# Make an OpenLayers example that works with the tiles available at http://this_host/index.html


# Setup Mapnik for OSM basics
chmod +x mapnik/generate_image.py
chmod +x mapnik/generate_tiles.py
mapnik/generate_image.py




Just before bed let me write out my goals for these scripts:
I don't care really how they are ordered but they should accomplish:
- install postgis
- create osm database
- install osm2pgsql
- install osmosis
- import data into database

- setup minutely mapnik updates to database using diffs and a bounding box
- install mapnik
- install mapnik tools (if necessary? - test without)
- install mod_tile and renderd

- go back and add in multilingualism into rendering

- install mapserver wms
- install sds
later:
- install osm routing engine


# Get the planet
wget http://planet.openstreetmap.org/planet/planet-latest.osm.bz2

# Extract the Caucasus
bzcat planet-latest.osm.bz2 | osmosis\
  --read-xml enableDateParsing=no file=-\
  --bounding-box top=43.92 left=39.04 bottom=37.76 right=51.46 --write-xml file=-\
  | bzip2 > caucasus.osm.bz2

# Extract via polygon
osmosis --read-xml file="planet-latest.osm" --bounding-polygon file="country.poly" --write-xml file="australia.osm"


