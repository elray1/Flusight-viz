This is the repo for the Flusight forecast visualization currently hosted at http://www.evanlray.com/Flusight-viz. The visualization is based on the https://github.com/reichlab/predtimechart component. Publishing is via github pages.

# updating the predtimechart version

To use a different version of the _predtimechart_ component, edit the version numbers of `predtimechart.css` and `predtimechart.js` that index.html uses. 

# updating forecast and truth JSON files

Updating forecast and truth JSON files is handled by GitHub Actions and the `update_forecasts_weekly.yml` and `update_truth_daily.yml` workflows located in `.github/workflows`. To update the JSON files locally, run the underlying R scripts:

```bash
cd <this dir>
Rscript install_dependencies.R
Rscript preprocess_data/preprocess_truth.R
Rscript preprocess_data/preprocess_forecasts.R
```
