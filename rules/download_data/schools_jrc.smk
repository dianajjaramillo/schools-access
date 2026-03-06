#
# Download schools database from JRC
# https://data.jrc.ec.europa.eu/dataset/c8eeea35-7233-48e3-81f3-ab6f7ea8d3bc
#

rule schools_download_jrc:
    output:
        gpkg="incoming_data/jrc_schools/05_Educational_Centers_AGGREGATION_EPSG4326_2024_06_17_CEAT.gpkg",
    shell:
        """
        mkdir -p incoming_data/jrc_schools/
        cd incoming_data/jrc_schools/

        wget https://jeodpp.jrc.ec.europa.eu/ftp/jrc-opendata/GIS-RE/SEADB_Africa/05_Educational_Centers_AGGREGATION_EPSG4326_2024_06_17_CEAT.gpkg
        """

rule schools_prep_jrc:
    input:
        gpkg="incoming_data/jrc_schools/05_Educational_Centers_AGGREGATION_EPSG4326_2024_06_17_CEAT.gpkg",
    output:
        gpkg="data/{ISO3}/schools_jrc__{ISO3}.gpkg",
    run:
        # Read in global gile
        df=geopandas.read_file(input.gpkg)
        
        # Filter country    
        df_iso=df[df["iso3code"]==wildcards.ISO3]

        if df_iso.empty:
            print(f"[Warning] No schools found for ISO code '{wildcards.ISO3}'.")

        df_iso.reset_index(drop=True, inplace=True)
        df_iso.loc[:,'node_id'] = 'node_' + df_iso.index.astype(str)
        df_iso = df_iso.rename(columns={"student_per_school": "capacity"})

        columns = ['node_id', 'id', 'category', 'iso3code', 'capacity', 'geometry']
        df_iso = df_iso[columns]

        df_iso.to_file(output.gpkg, layer="points")



