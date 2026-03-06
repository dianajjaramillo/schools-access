#
# Analysis for supplementary materials
#

rule align_90m_to_1km:
    input:
        traveltime_90m="model_90m/outputs/jrcwalking/{ISO3}/outputs/traveltime_4326__{ISO3}.tif",
        reference_1km="model_1km/outputs/monergirona/{ISO3}/outputs/traveltime_4326__{ISO3}.tif"
    output:
        aligned_90m="model_comp/derived/{ISO3}/traveltime_90m_warped_to_1km__{ISO3}.tif"
    shell:
        """
        gdalwarp -r bilinear \
            -te $(gdalinfo -json {input.reference_1km} | jq -r '.cornerCoordinates | [.lowerLeft[0], .lowerLeft[1], .upperRight[0], .upperRight[1]] | @sh') \
            -ts $(gdalinfo -json {input.reference_1km} | jq -r '.size | @sh') \
            -t_srs EPSG:4326 \
            -overwrite \
            {input.traveltime_90m} \
            {output.aligned_90m}
        """

rule subtract_traveltime_rasters:
    input:
        aligned_90m="model_comp/derived/{ISO3}/traveltime_90m_warped_to_1km__{ISO3}.tif",
        model_1km="model_1km/outputs/monergirona/{ISO3}/outputs/traveltime_4326__{ISO3}.tif"
    output:
        diff="model_comp/derived/{ISO3}/diff_traveltime__90mx1km__{ISO3}.tif"
    shell:
        """
        gdal_calc.py \
            -A {input.aligned_90m} \
            -B {input.model_1km} \
            --calc="A - B" \
            --outfile={output.diff} \
            --overwrite \
            --NoDataValue=-9999
        """

rule create_tmax180_mask:
    input:
        aligned_90m="model_comp/derived/{ISO3}/traveltime_90m_warped_to_1km__{ISO3}.tif",
        model_1km="model_1km/outputs/monergirona/{ISO3}/outputs/traveltime_4326__{ISO3}.tif"
    output:
        mask="model_comp/derived/{ISO3}/mask_tmax180__{ISO3}.tif"
    shell:
        """
        gdal_calc.py \
            -A {input.aligned_90m} \
            -B {input.model_1km} \
            --calc="logical_and(A>180, B>180)" \
            --outfile={output.mask} \
            --type=Byte \
            --NoDataValue=0 \
            --overwrite
        """


rule mask_diff_with_tmax180:
    input:
        diff="model_comp/derived/{ISO3}/diff_traveltime__90mx1km__{ISO3}.tif",
        mask="model_comp/derived/{ISO3}/mask_tmax180__{ISO3}.tif"
    output:
        masked_diff="model_comp/derived/{ISO3}/diff_traveltime_masked__90mx1km__{ISO3}.tif"
    shell:
        """
        gdal_calc.py \
            -A {input.diff} \
            -B {input.mask} \
            --calc="A*(1-B)" \
            --outfile={output.masked_diff} \
            --overwrite \
            --NoDataValue=-9999
        """


rule warp_pop_to_1km_grid:
    input:
        pop_90m="data/{ISO3}/pop_ghs__{ISO3}.tif",
        ref_raster="model_comp/derived/{ISO3}/diff_traveltime__90mx1km__{ISO3}.tif"
    output:
        pop_1km_aligned="model_comp/derived/{ISO3}/pop_1km_aligned__{ISO3}.tif"
    shell:
        """
        gdalwarp -r sum \
            -te $(gdalinfo -json {input.ref_raster} | jq -r '.cornerCoordinates | [.lowerLeft[0], .lowerLeft[1], .upperRight[0], .upperRight[1]] | @sh') \
            -ts $(gdalinfo -json {input.ref_raster} | jq -r '.size | @sh') \
            -t_srs EPSG:4326 \
            -overwrite \
            {input.pop_90m} \
            {output.pop_1km_aligned}
        """

rule mask_diff_with_pop:
    input:
        diff_raster="model_comp/derived/{ISO3}/diff_traveltime__90mx1km__{ISO3}.tif",
        pop_raster="model_comp/derived/{ISO3}/pop_1km_aligned__{ISO3}.tif"
    output:
        masked_diff="model_comp/derived/{ISO3}/diff_masked_by_pop__{ISO3}.tif"
    shell:
        """
        gdal_calc.py \
            -A {input.diff_raster} \
            -B {input.pop_raster} \
            --calc="where(B>0, A, -9999)" \
            --NoDataValue=-9999 \
            --outfile={output.masked_diff} \
            --overwrite
        """

with open("config/countries_list.txt") as f:
    ISO3_CODES = [line.strip() for line in f if line.strip()]


rule merge_all_pops:
    input:
        expand("model_comp/derived/{ISO3}/pop_1km_aligned__{ISO3}.tif", ISO3=ISO3_CODES)
    output:
        merged="model_comp/derived/AFR/pop_1km_aligned__AFR.tif"
    shell:
        """
        gdal_merge.py -n -9999 -a_nodata -9999 -o {output.merged} {input}
        """

rule merge_all_tmax_mask:
    input:
        expand("model_comp/derived/{ISO3}/mask_tmax180__{ISO3}.tif", ISO3=ISO3_CODES)
    output:
        merged="model_comp/derived/AFR/mask_tmax180__AFR.tif"
    shell:
        """
        gdal_merge.py -n -9999 -a_nodata -9999 -o {output.merged} {input}
        """

rule merge_all_diffs:
    input:
        expand("model_comp/derived/{ISO3}/diff_traveltime__90mx1km__{ISO3}.tif", ISO3=ISO3_CODES)
    output:
        merged="model_comp/derived/AFR/diff_traveltime__90mx1km__AFR.tif"
    shell:
        """
        gdal_merge.py -n -9999 -a_nodata -9999 -o {output.merged} {input}
        """


rule compare_model_cdfs:
    input:
        csv_90m = "model_90m/outputs/jrcwalking/{ISO3}/analysis/ttpop_nat__{ISO3}.csv",
        csv_1km = "model_1km/outputs/monergirona/{ISO3}/analysis/ttpop_nat__{ISO3}.csv"
    output:
        fig = "model_comp/cdf_compare/{ISO3}/cdf_comparison__{ISO3}.png",
        metrics = "model_comp/cdf_compare/{ISO3}/cdf_metrics__{ISO3}.json"
    params:
        iso3 = "{ISO3}"
    shell:
        """
        python rules/comp_models/plot_compare.py {params.iso3} {input.csv_90m} {input.csv_1km} {output.fig} {output.metrics}
        """

rule compare_model_cdfs_afr:
    input:
        csv_90m = "figures/tables/model_90m/jrcwalking/df_complete.csv",
        csv_1km = "figures/tables/model_1km/monergirona/df_complete.csv"
    output:
        fig = "figures/model_comp/cdf_comparison__AFR.png",
        metrics = "figures/model_comp/cdf_metrics__AFR.json"
    params:
        iso3 = "AFR"
    shell:
        """
        python rules/comp_models/plot_compare.py {params.iso3} {input.csv_90m} {input.csv_1km} {output.fig} {output.metrics}
        """

rule compare_model_cdfs_all:
    input:
        expand("model_comp/cdf_compare/{ISO3}/cdf_metrics__{ISO3}.json", ISO3=ISO3_CODES)

rule compute_metrics:
    input:
        diff_raster="model_comp/derived/{ISO3}/diff_traveltime__90mx1km__{ISO3}.tif",
        pop_raster="model_comp/derived/{ISO3}/pop_1km_aligned__{ISO3}.tif"
    output:
        json="model_comp/pop_metrics/{ISO3}/pop_metrics__{ISO3}.json"
    shell:
        """
        python rules/comp_models/compute_metrics.py {input.diff_raster} {input.pop_raster} {output.json}
        """

rule compare_cdfs_all:
    input:
        expand("model_comp/cdf_compare/{ISO3}/cdf_comparison__{ISO3}.png", ISO3=ISO3_CODES),
        expand("model_comp/cdf_compare/{ISO3}/cdf_metrics__{ISO3}.json", ISO3=ISO3_CODES)

rule compare_metrics_all:
    input:
        expand("model_comp/pop_metrics/{ISO3}/pop_metrics__{ISO3}.json", ISO3=ISO3_CODES)