import sportsdataverse

df = sportsdataverse.mbb.load_mbb_pbp(seasons=range(2025,2026), return_as_pandas=True)
df['game_id'] = df['game_id'].astype(str)
df.to_parquet('/Users/andrewbartnof/Documents/projects/public/ncaa_rankings/clean_data/mbb_data.parquet')
