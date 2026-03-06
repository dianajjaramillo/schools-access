#
# Rules for generating plots
#
rule plot_histogram:
    input:
        csv="model_90m/outputs/{VERSION}/{ISO3}/analysis/ttpop_nat__{ISO3}.csv"
    output:
        png="figures/plots/{VERSION}/histogram__{ISO3}.png",
    run:
        import matplotlib.pyplot as plt
        import matplotlib.colors as colors
        
        df = pandas.read_csv(input.csv, index_col=0)
        fig, ax = plt.subplots()
        plt.hist(
            data=df,
            x = "traveltime",
            weights="pop",
            bins=range(0,int(df["traveltime"].max())+5,5),
            cumulative = False,
            log = False)
        ax.set_xlim([0, 180])
        ax.set_xlabel("Travel time (minutes)")
        ax.set_ylabel("Population")
        plt.savefig(output.png)

