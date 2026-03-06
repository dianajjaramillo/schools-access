#
# Merge all three schools databases
#


# rule schools_merged:
#     input:
#         jrc="data/{ISO3}/schools_jrc__{ISO3}.gpkg",
#         osm="data/{ISO3}/schools_osm__{ISO3}.gpkg",
#         giga="data/{ISO3}/schools_giga__{ISO3}.gpkg",
#     output:
#         nbuf="data/{ISO3}/schools_merged_nobuff__{ISO3}.gpkg",
#         ybuf="data/{ISO3}/schools_merged_wbuff50__{ISO3}.gpkg",
#     run:
#         import geopandas
#         import pandas 

#         # read schools data
#         jrc=geopandas.read_file(input.jrc)
#         osm=geopandas.read_file(input.osm)
#         giga=geopandas.read_file(input.giga)
        
#         jrc_simple = jrc["geometry"].to_frame()
#         osm_simple = osm["geometry"].to_frame()
#         giga_simple = giga["geometry"].to_frame()
        
#         schools = pandas.concat([jrc_simple, osm_simple, giga_simple])
#         schools = schools.drop_duplicates('geometry')
#         schools.to_file(output.nbuf)

                
#         # create a buffer around the points
#         buffer=schools.to_crs(3857)
#         buffer.geometry=buffer.buffer(50) # the radius of the buffer in meters
        
#         # if buffers overlap dissolve and replace with centroid
#         buffer_merged=buffer.dissolve().explode(index_parts=False)
#         buffer_merged.geometry=buffer_merged.centroid
#         buffer_merged=buffer_merged.to_crs(4326)
#         buffer_merged.to_file(output.ybuf)


rule schools_merged:
    input:
        jrc="data/{ISO3}/schools_jrc__{ISO3}.gpkg",
        giga="data/{ISO3}/schools_giga__{ISO3}.gpkg",
    output:
        nbuf="data/{ISO3}/schools_merged_nobuff_JG__{ISO3}.gpkg",
        ybuf="data/{ISO3}/schools_merged_wbuff50_JG__{ISO3}.gpkg",
    run:
        import geopandas
        import pandas 

        # read schools data
        jrc=geopandas.read_file(input.jrc)
        giga=geopandas.read_file(input.giga)
        
        jrc_simple = jrc["geometry"].to_frame()
        giga_simple = giga["geometry"].to_frame()
        
        schools = pandas.concat([jrc_simple, giga_simple])
        schools = schools.drop_duplicates('geometry')
        schools.to_file(output.nbuf)

                
        # create a buffer around the points
        buffer=schools.to_crs(3857)
        buffer.geometry=buffer.buffer(50) # the radius of the buffer in meters
        
        # if buffers overlap dissolve and replace with centroid
        buffer_merged=buffer.dissolve().explode(index_parts=False)
        buffer_merged.geometry=buffer_merged.centroid
        buffer_merged=buffer_merged.to_crs(4326)
        buffer_merged.to_file(output.ybuf)

        