#
# Download schools database from Giga Maps using API key
# https://data.jrc.ec.europa.eu/dataset/c8eeea35-7233-48e3-81f3-ab6f7ea8d3bc
#

rule schools_download_giga: 
    output:
        gpkg="data/{ISO3}/schools_giga__{ISO3}.gpkg",
    run:
        import json
        import geopandas
        import pandas
        import requests

        import os
        from dotenv import load_dotenv

        load_dotenv()
        key = os.getenv("GIGA_API_KEY")
        
        url = (
            "https://uni-ooi-giga-maps-service.azurewebsites.net/api/v1/"
            f"schools_location/country/{wildcards.ISO3}"
        )
        headers = {'accept': 'application/json'}
        headers['Authorization'] =  'Bearer '+ key

        r = requests.get(url, headers=headers)

        print (r)

        def write_empty(path):
            empty = geopandas.GeoDataFrame(
                pandas.DataFrame({"geometry": []}),
                geometry="geometry",
                crs="EPSG:4326"
            )
            empty.to_file(path, driver="GPKG")  

        if r.status_code == 404:
            print("Giga is empty")
            write_empty(output.gpkg)


        if r.status_code == 200:
            schools = pandas.DataFrame(r.json())
            if len(schools) == 0 :
                print("Giga is empty")
                write_empty(output.gpkg)

            else:
                print("PC is not empty")
                schools_df = pandas.json_normalize(schools['data'])

                schools_gdf = geopandas.GeoDataFrame(schools_df,
                    crs="EPSG:4326",
                    geometry = geopandas.points_from_xy(schools_df.longitude, schools_df.latitude))

                schools_gdf.to_file(output.gpkg)
