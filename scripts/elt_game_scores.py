#!/usr/bin/env python3
"""
Script:   extract_last_game_rows.py
Purpose:  Load a Parquet file, keep the last record for each `game_id`,
          and retain only the columns game_id, season, home_team_name, away_team_name, home_score, away_score 

Requirements:
    pip install pandas pyarrow   # pyarrow provides Parquet support
"""

import sys
from pathlib import Path

import pandas as pd


def load_parquet(file_path: Path) -> pd.DataFrame:
    """
    Load a Parquet file into a pandas DataFrame.

    Parameters
    ----------
    file_path : Path
        Path to the Parquet file.

    Returns
    -------
    pd.DataFrame
        DataFrame containing the file's contents.
    """
    try:
        df = pd.read_parquet(file_path)
        return df
    except Exception as e:
        sys.exit(f"Error loading Parquet file: {e}")


def select_last_per_group(df: pd.DataFrame, group_col: str) -> pd.DataFrame:
    """
    For each distinct value in `group_col`, keep the last row
    (according to the original order of the DataFrame).

    Parameters
    ----------
    df : pd.DataFrame
        Input DataFrame.
    group_col : str
        Column name to group by (e.g., 'game_id').

    Returns
    -------
    pd.DataFrame
        DataFrame containing the last row of each group.
    """
    # `groupby(..., sort=False)` preserves the original order.
    # `.tail(1)` picks the last row within each group.
    last_rows = (
        df.groupby(group_col, sort=False, as_index=False)
        .tail(1)
        .reset_index(drop=True)
    )
    return last_rows


def keep_selected_columns(df: pd.DataFrame) -> pd.DataFrame:
    """
    Retain only the specified columns.

    Parameters
    ----------
    df : pd.DataFrame
        Input DataFrame.

    Returns
    -------
    pd.DataFrame
        DataFrame with only the desired columns.
    """
    columns = ["game_id", "season", "game_date", "home_team_name", "away_team_name", "home_score", "away_score"]

    missing = set(columns) - set(df.columns)
    if missing:
        sys.exit(f"The following required columns are missing: {missing}")
    return df[columns]


def process_parquet(file_path: str) -> pd.DataFrame:
    """
    End‑to‑end processing pipeline.

    1. Load the Parquet file.
    2. Keep the last row for each `game_id`.
    3. Retain only a few columns

    Parameters
    ----------
    file_path : str
        Path to the Parquet file.

    Returns
    -------
    pd.DataFrame
        Final processed DataFrame.
    """
    path = Path(file_path)

    # Step 1 – load data
    df = load_parquet(path)

    # Step 2 – last row per game_id
    df_last = select_last_per_group(df, group_col="game_id")

    # Step 3 – keep only the required columns
    result = keep_selected_columns(df_last)

    return result


def main() -> None:
    """
    Command‑line entry point.
    """

    input_file = '/Users/andrewbartnof/Documents/projects/public/ncaa_rankings/clean_data/mbb_data.parquet'
    output_file = '/Users/andrewbartnof/Documents/projects/public/ncaa_rankings/clean_data/game_scores.parquet'

    final_df = process_parquet(file_path=input_file)
    final_df.to_parquet(output_file, index=False)
    print('Game scores written to disk. Sample data:')
    print(final_df.head())


if __name__ == "__main__":
    main()
