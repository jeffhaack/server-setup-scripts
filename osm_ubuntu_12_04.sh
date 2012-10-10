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

echo "Installing PostgreSQL 9.1 and PostGIS extensions..."
sudo apt-get -y install python-software-properties
sudo add-apt-repository -y ppa:pitti/postgresql
sudo apt-get update
sudo apt-get -y install postgresql-9.1 postgresql-9.1-postgis postgresql-contrib-9.1 libpq-dev
# Adjust PostgreSQL settings all to trust locally
# And adjust settings for import
echo "*********************************************"
echo "*****  Making PostgreSQL very trusting  *****"
echo "*********************************************"
sed -i s/"ident"/"trust"/ /etc/postgresql/9.1/main/pg_hba.conf
sed -i s/"md5"/"trust"/ /etc/postgresql/9.1/main/pg_hba.conf
sed -i s/"peer"/"trust"/ /etc/postgresql/9.1/main/pg_hba.conf
sed -i s/"shared_buffers = 24MB"/"shared_buffers = 128MB"/ /etc/postgresql/9.1/main/postgresql.conf
sed -i s/"#checkpoint_segments = 3"/"checkpoint_segments = 20"/ /etc/postgresql/9.1/main/postgresql.conf
sed -i s/"#maintenance_work_mem = 16MB"/"maintenance_work_mem = 256MB"/ /etc/postgresql/9.1/main/postgresql.conf
sed -i s/"#autovacuum = on"/"autovacuum = off"/ /etc/postgresql/9.1/main/postgresql.conf
sudo sh -c "echo 'kernel.shmmax=268435456' > /etc/sysctl.d/60-shmmax.conf"
sudo service procps start
sudo /etc/init.d/postgresql restart


# Install Apache
echo "Installing Apache2..."
sudo apt-get -y install apache2

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
	sudo add-apt-repository -y ppa:kakrueger/openstreetmap
	sudo apt-get update
	sudo apt-get -y install osm2pgsql
else
	echo "Osm2pgsql already installed..."
fi

# Install Mapnik
if [ ! -d $MAPNIK_PYTHON_DIR ]; then
	echo "Installing Mapnik..."
	sudo apt-get -y install libmapnik2-2.0 libmapnik2-dev mapnik-utils python-mapnik2
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
#    psql -U postgres -d $DB_NAME -c "create language plpgsql;"
    psql -U postgres -d $DB_NAME -f /usr/share/postgresql/9.1/contrib/postgis-1.5/postgis.sql
    psql -U postgres -d $DB_NAME -f /usr/share/postgresql/9.1/contrib/postgis-1.5/spatial_ref_sys.sql
    #psql -U postgres -d $DB_NAME -f /usr/share/postgresql/9.1/contrib/_int.sql # need this for the diff updating ???
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
		cd $DATA
		wget http://svn.openstreetmap.org/applications/utils/export/osm2pgsql/default.style
		mv default.style $OSM2PGSQL_STYLESHEET
		echo "node,way   $LANGUAGE      text         linear" >> $OSM2PGSQL_STYLESHEET
		##############################
		osm2pgsql --slim -U postgres -d $DB_NAME -S $OSM2PGSQL_STYLESHEET --cache-strategy sparse --cache 10 $DATA/$OSM_FILE
	fi
else
	echo "Not importing file into database..."
fi


######
# This installs the osm mapnik tools, basically gets the big shapefiles we needs and gives a fallback stylsheet
#cd $SRC
#sudo apt-get -y install subversion unzip
#svn co http://svn.openstreetmap.org/applications/rendering/mapnik
#cd mapnik
#./get-coastlines.sh
#./generate_xml.py --dbname osm --user postgres --accept-none
#./generate_image.py
#cp image.png /var/www
#####

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
	osm2pgsql -a -s -b "$MIN_LON,$MIN_LAT,$MAX_LON,$MAX_LAT" -U postgres -d $DB_NAME -e 15 -o $DATA/expire.list -S $OSM2PGSQL_STYLESHEET --cache-strategy sparse --cache 10 $DATA/changes.osc.gz
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
osm2pgsql -a -s -b \"\$MIN_LON,\$MIN_LAT,\$MAX_LON,\$MAX_LAT\" -U postgres -d \$DB_NAME -e 15 -o \$DATA/expire.list -S $OSM2PGSQL_STYLESHEET --cache-strategy sparse --cache 10 \$DATA/changes.osc.gz" > $DATA/update_osm_db.sh

	chmod +x $DATA/update_osm_db.sh
	#write out current crontab
	crontab -l > mycron
	#echo new cron into cron file
	echo "$CRON_TIME $DATA/update_osm_db.sh" >> mycron
	#install new cron file
	crontab mycron
	rm mycron
fi

# Get shapefile data
sudo apt-get -y install unzip
cd $DATA
mkdir shp
cd shp
wget http://mapbox-geodata.s3.amazonaws.com/natural-earth-1.3.0/physical/10m-land.zip
wget http://tilemill-data.s3.amazonaws.com/osm/coastline-good.zip
wget http://tilemill-data.s3.amazonaws.com/osm/shoreline_300.zip
unzip 10m-land.zip
unzip coastline-good.zip
unzip shoreline_300.zip

# Setup Mapnik for OSM basics
cd mapnik
chmod +x generate_image.py
chmod +x generate_tiles.py
./generate_image.py
cp image.png /var/www
IP=$(curl ifconfig.me)
echo "Go to http://$IP/image.png to see."


# see http://switch2osm.org/serving-tiles/building-a-tile-server-from-packages/
sudo apt-get install libapache2-mod-tile
touch /var/lib/mod_tile/planet-import-complete # the timestamp on this will tell mod_tile when to re-render tiles (shouldn't be useful for me though, cause i need an expiry list)

# Edit /etc/apache2/sites-available/tileserver_site
IP=$(curl ifconfig.me)
sed -i s/"a.tile.openstreetmap.org b.tile.openstreetmap.org c.tile.openstreetmap.org d.tile.openstreetmap.org"/"$IP"/ /etc/apache2/sites-available/tileserver_site

# Now edit the renderd daemon settings
rm /etc/renderd.conf
touch /etc/renderd.conf
echo "[renderd]
stats_file=/var/run/renderd/renderd.stats
socketname=/var/run/renderd/renderd.sock
num_threads=4
tile_dir=/var/lib/mod_tile ; DOES NOT WORK YET

[mapnik]
plugins_dir=/usr/lib/mapnik/2.0/input
font_dir=/usr/share/fonts/truetype/ttf-dejavu
font_dir_recurse=false

[default]
URI=/osm/
XML=/root/src/mapnik/osm.xml
DESCRIPTION=This is the standard osm mapnik style
;ATTRIBUTION=&copy;<a href=\"http://www.openstreetmap.org/\">OpenStreetMap</a> and <a href=\"http://wiki.openstreetmap.org/w\
iki/Contributors\">contributors</a>, <a href=\"http://creativecommons.org/licenses/by-sa/2.0/\">CC-BY-SA</a>
;HOST=$IP
;SERVER_ALIAS=$IP
;HTCPHOST=proxy.openstreetmap.org" > /etc/renderd.conf

# And restart up the daemon and restart Apache
sudo /etc/init.d/renderd restart
sudo /etc/init.d/apache2 restart

$BIN/mod_tile/renderd
/etc/init.d/apache2 restart

# Add our sample map.html to /var/ww
cd $SETUP
cp mapnik/map.html /var/www/map.html
sed -i s/"TILE_LOCATION"/"$IP\/osm"/ /var/www/map.html
echo "Go to http://$IP/map.html to see."

################################################################################################