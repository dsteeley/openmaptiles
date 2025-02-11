#!/usr/bin/bash
set -eux

# We run this script to build two sets of mbtiles. The first is contours, the second is open street maps.


docker compose down --remove-orphans

# Check if we have a big pbf already
if [ ! -f data/scotland_out.osm.pbf ]; then
    # Get contours
if [ ! -f data/scotland_contours.osm.pbf ]; then
    # TODO add this all in makefile format and have the container take the polyfile as an argument
    docker compose run --rm generate-osm-contours
    docker compose run --rm osmium "osmium merge /import/*.pbf -o /import/scotland_contours.osm.pbf --overwrite && rm /import/lon*.pbf"
fi
if [ ! -f data/scotland.osm.pbf ]; then
    make download area=scotland
fi
    # Combine pbfs
    # docker compose run --rm osmium "osmium sort /import/scotland.osm.pbf /import/scotland_contours.osm.pbf -o /import/scotland_out.osm.pbf -s multipass --overwrite --output-header=sorting=Type_then_ID"
    # osmium merge data/scotland_sorted.osm.pbf data/scotland_contours_sorted.osm.pbf -o data/all.osm.pbf
    # mv data/all.osm.pbf data/scotland_out.osm.pbf
fi
make clean                  # clean / remove existing build files
make                        # generate build files
make start-db               # start up the database container.
make import-data            # Import external data from OpenStreetMapData, Natural Earth and OpenStreetMap Lake Labels.
make import-osm area=scotland # import data into postgres ~16min
make import-wikidata        # import Wikidata
make import-sql             # create / import sql functions
make generate-bbox-file area=scotland # compute data bbox -- not needed for the whole planet or for downloaded area by `make download`
make generate-tiles-pg      # generate tiles
mv data/tiles.mbtiles data/scotland.mbtiles

# Now contours
make clean
make import-osm area=scotland_contours # import data into postgres ~16min
make import-sql
make generate-tiles-pg      # generate tiles
mv data/tiles.mbtiles data/scotland_contours.mbtiles
# Now we can run the server
make start-tileserver
