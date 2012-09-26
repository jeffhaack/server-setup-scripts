#!/bin/bash

# Ubuntu 11.04 Natty Narwal
# This is for setting up an OSM database that stays in sync

# Setup Osmosis
wget http://bretth.dev.openstreetmap.org/osmosis-build/osmosis-latest.tgz
tar xvfz osmosis-latest.tgz
cd osmosis-*
chmod a+x bin/osmosis
bin/osmosis

# Configure PostgreSQL
sed -i s/"shared_buffers = 24MB"/"shared_buffers = 128MB"/ /etc/postgresql/8.4/main/postgresql.conf
sed -i s/"#checkpoint_segments = 3"/"checkpoint_segments = 20"/ /etc/postgresql/8.4/main/postgresql.conf
sed -i s/"#maintenance_work_mem = 16MB"/"maintenance_work_mem = 256MB"/ /etc/postgresql/8.4/main/postgresql.conf
sed -i s/"#autovacuum = on"/"autovacuum = off"/ /etc/postgresql/8.4/main/postgresql.conf
sudo sh -c "echo 'kernel.shmmax=268435456' > /etc/sysctl.d/60-shmmax.conf"
sudo service procps start
sudo /etc/init.d/postgresql restart