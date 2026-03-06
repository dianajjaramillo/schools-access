#
# Rules for generating maps
#
rule map_traveltime:
    input:
        tif="model_90m/outputs/{VERSION}/{ISO3}/outputs/traveltime_4326__{ISO3}.tif",
    output:
        png="figures/maps/{VERSION}/traveltime__{ISO3}.png",
    run:
        import rioxarray
        import matplotlib.pyplot as plt
        import matplotlib.colors as colors
        
        tt = rioxarray.open_rasterio(input.tif, masked = True)
        tt_crs = tt.rio.crs
        tt = tt.squeeze().drop_vars("spatial_ref").drop_vars("band")
        tt.name = "traveltime"

        fig, ax = plt.subplots(figsize=(10, 5))

        im = ax.imshow(tt,
                             cmap=plt.colormaps['inferno_r'].resampled(9),
                             norm=colors.BoundaryNorm([0, 15, 30, 60, 90, 120, 180, 240, 360], 9, extend='max'))

        fig.colorbar(im, ax=ax, label='Travel time to closest school (mins)')
        ax.set_axis_off()
        plt.savefig(output.png)


rule map_subnational:
    input:
        txt="config/countries_list.txt",
    output:
        gpkg="model_90m/outputs/{VERSION}/AFR/stats__AFR.gpkg"
    run:
        countries = open(input.txt, "r").read().split("\n")

        df_complete = []
        for iso in countries:
            path_iso = f"model_90m/outputs/{wildcards.VERSION}/{iso}/analysis/stats_gadm__{iso}.gpkg"
            df_iso = pandas.DataFrame(geopandas.read_file(path_iso))
            df_complete.append(df_iso)

        df_complete = pandas.concat(df_complete)
        gdf_complete = geopandas.GeoDataFrame(df_complete, geometry="geometry")
        gdf_complete.to_file(output.gpkg)


rule map_traveltime_AFR:
    input:
        tif="model_90m/outputs/{VERSION}/AFR/traveltime_4326__AFR.tif",
    output:
        png="model_90m/outputs/{VERSION}/AFR/traveltime__AFR.png",
    run:
        import rioxarray
        import matplotlib.pyplot as plt
        import matplotlib.colors as colors
        
        tt = rioxarray.open_rasterio(input.tif, masked = True)
        tt_crs = tt.rio.crs
        tt = tt.squeeze().drop_vars("spatial_ref").drop_vars("band")
        tt.name = "traveltime"

        fig, ax = plt.subplots(figsize=(10, 5))

        im = ax.imshow(tt,
                             cmap=plt.colormaps['inferno_r'].resampled(9),
                             norm=colors.BoundaryNorm([0, 15, 30, 60, 90, 120, 180, 240, 360], 9, extend='max'))

        fig.colorbar(im, ax=ax, label='Travel time to closest school (mins)')
        ax.set_axis_off()
        plt.savefig(output.png)
