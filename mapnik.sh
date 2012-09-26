#!/bin/bash

# Ubuntu 11.04 Natty Narwal
# This is for setting up an OSM database that stays in sync

# Some dependencies
sudo apt-get -y install g++ cpp \
						libboost1.40-dev libboost-filesystem1.40-dev \
						libboost-iostreams1.40-dev libboost-program-options1.40-dev \
						libboost-python1.40-dev libboost-regex1.40-dev \ 
						libboost-thread1.40-dev \
						libxml2 libxml2-dev \
						libfreetype6 libfreetype6-dev \
						libjpeg62 libjpeg62-dev \
						libltdl7 libltdl-dev \
						libpng12-0 libpng12-dev \
						libgeotiff-dev libtiff4 libtiff4-dev libtiffxx0c2 \ 
						libcairo2 libcairo2-dev python-cairo python-cairo-dev \ 
						libcairomm-1.0-1 libcairomm-1.0-dev \
						ttf-dejavu ttf-dejavu-core ttf-dejavu-extra \ 
						subversion build-essential python-nose
sudo apt-get -y install libsigc++-dev libsigc++0c2 libsigx-2.0-2 libsigx-2.0-dev
sudo apt-get -y install libgdal1-dev python-gdal \
						libsqlite3-dev
sudo apt-get -y install build-essential libxml2-dev libgeos-dev libpq-dev libbz2-dev proj

# Make some directories
cd ~
mkdir src bin data



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


