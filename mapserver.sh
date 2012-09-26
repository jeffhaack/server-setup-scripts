#!/bin/bash

# Ubuntu 11.04 Natty Narwal
# This is for setting up MapServer WMS with OSM DB

sudo apt-get -y install apache2
sudo apt-get -y install python-software-properties
sudo add-apt-repository ppa:ubuntugis/ubuntugis-unstable
sudo apt-get update
sudo apt-get -y install cgi-mapserver mapserver-bin

read -p "Would you like to create a mapfile for an osm2pgsql imported database? (y/n): " make_mapfile
if [ "$make_mapfile" == "y" ]
  then
  	db_name="osm"
  	read -p "What is the database name?: (default: osm) " db_name
  	db_user="postgres"
  	read -p "What is the database user?: (default: postgres) " db_user
  	db_password=""
  	read -p "What is the database user?: (default: none) " db_password
  	touch osm_map.map
	echo -e "
MAP
  NAME 'My-OSM-Map'
  # Map image size
  SIZE 700 700
  UNITS meters

  EXTENT 3756680.934870 3642952.056250 3899342.315130 3723789.193750
  PROJECTION
    'proj=longlat'
    'datum=WGS84'
    'no_defs'
  END

  # Background color for the map canvas -- change as desired
  IMAGECOLOR 255 255 255
  IMAGEQUALITY 95
  IMAGETYPE png

  OUTPUTFORMAT
    NAME png
    DRIVER 'GD/PNG'
    MIMETYPE 'image/png'
    IMAGEMODE RGBA
    EXTENSION 'png'
  END

  WEB
    IMAGEPATH '/tmp/'
    IMAGEURL '/tmp/'

    # WMS server settings
    METADATA
      'ows_title'           'My-Test-Map'
      'ows_onlineresource'  'http://198.61.205.151/cgi-bin/mapserv?MAP=/var/www/test.map'
      'ows_srs'             'EPSG:4326'
    END

    TEMPLATE 'fooOnlyForWMSGetFeatureInfo'
  END

  LAYER
    NAME 'planet_osm_line'
    TYPE LINE
    DUMP true
    TEMPLATE fooOnlyForWMSGetFeatureInfo
    UNITS METERS
    EXTENT 3756680.934870 3642952.056250 3899342.315130 3723789.193750
    CONNECTIONTYPE postgis
    CONNECTION 'dbname=$db_name user=$db_user password=$db_password sslmode=disable'
    DATA 'way FROM planet_osm_line USING UNIQUE osm_id USING srid=900913'
    METADATA
      'ows_title' 'planet_osm_line'
    END
    STATUS OFF
    TRANSPARENCY 100
    PROJECTION
      'proj=longlat'
      'datum=WGS84'
      'no_defs'
    END
    CLASS
       NAME 'planet_osm_line' 
       STYLE
         WIDTH 0.91 
         COLOR 46 195 130
       END
    END
  END
END

" >> osm_map.map


echo "***********************************************************"
echo "Access your WMS in QGIS or JOSM at:"
echo "http://<YOUR_SERVER_IP>/cgi-bin/mapserv?MAP=/root/osm_map.map"
echo "You may need to make adjustments to the mapfile, particularly"
echo "the extent."
echo "***********************************************************"
fi