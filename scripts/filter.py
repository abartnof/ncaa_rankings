"""
NCAA Basketball Game Results Processor.

This module provides a structural approach to cleaning and filtering NCAA
basketball game data stored in Parquet format. It performs date formatting,
date-based filtering, tie removal, and team-specific game count validation.
"""

import pandas as pd


def load_data(file_path):
    """
    Loads a Parquet file into a pandas DataFrame.

    Args:
        file_path (str): The path to the input .parquet file.

    Returns:
        pd.DataFrame: The loaded dataset.
    """
    return pd.read_parquet(file_path)


def format_dates(df, column_name):
    """
    Ensures the specified column is in datetime format.

    Args:
        df (pd.DataFrame): The dataframe to process.
        column_name (str): The name of the date column.

    Returns:
        pd.DataFrame: The dataframe with converted date objects.
    """
    df[column_name] = pd.to_datetime(df[column_name])
    return df


def filter_by_date(df, date_str):
    """
    Filters rows to include only games before the specified date.

    Args:
        df (pd.DataFrame): The dataframe to filter.
        date_str (str): The cutoff date in 'YYYY-MM-DD' format.

    Returns:
        pd.DataFrame: Rows where game_date is strictly before the cutoff.
    """
    return df[df['game_date'] < pd.to_datetime(date_str)]


def remove_ties(df):
    """
    Filters out rows where home_score equals away_score.

    Args:
        df (pd.DataFrame): The dataframe to filter.

    Returns:
        pd.DataFrame: Rows where home_score != away_score.
    """
    return df[df['home_score'] != df['away_score']]


def filter_by_minimum_games(df, min_games=5):
    """
    Ensures home teams and away teams meet specific game count thresholds.

    Test 1: Home team must have played >= min_games as the 'home' team.
    Test 2: Away team must have played >= min_games as the 'away' team.

    Args:
        df (pd.DataFrame): The dataframe to filter.
        min_games (int): The minimum required games.

    Returns:
        pd.DataFrame: Filtered dataframe meeting both distinct criteria.
    """
    # Count occurrences for home and away roles
    home_counts = df['home_team_name'].value_counts()
    away_counts = df['away_team_name'].value_counts()

    # Identify teams meeting the thresholds
    qualified_home_teams = home_counts[home_counts >= min_games].index
    qualified_away_teams = away_counts[away_counts >= min_games].index

    # Final logic: Home team must be in qualified_home AND away team in qualified_away
    mask = (df['home_team_name'].isin(qualified_home_teams) &
            df['away_team_name'].isin(qualified_away_teams))
    return df[mask]


def save_to_parquet(df, output_path):
    """
    Writes the DataFrame to a Parquet file.

    Args:
        df (pd.DataFrame): The dataframe to save.
        output_path (str): The destination file path.
    """
    df.to_parquet(output_path, index=False)


def display_filter_stats(original_count, final_count):
    """
    Calculates and prints the number of rows removed during processing.

    Args:
        original_count (int): Row count before filtering.
        final_count (int): Row count after filtering.
    """
    removed = original_count - final_count
    percent = (removed / original_count) * 100 if original_count > 0 else 0

    print("\n" + "="*30)
    print("      FILTER STATISTICS")
    print("="*30)
    print(f"Initial rows:      {original_count}")
    print(f"Final rows:        {final_count}")
    print(f"Rows filtered out: {removed} ({percent:.2f}%)")
    print("="*30 + "\n")


def main():
    """
    Orchestrates the data loading, filtering, and saving process.
    """
    # Configuration
    input_file = "/Users/andrewbartnof/Documents/projects/public/ncaa_rankings/clean_data/game_scores.parquet"
    output_file = "/Users/andrewbartnof/Documents/projects/public/ncaa_rankings/clean_data/filtered_game_scores.parquet"
    cutoff_date = "2025-11-02"

    try:
        # Load and initial snapshot
        df = load_data(input_file)
        initial_row_count = len(df)

        # Processing Pipeline
        df = format_dates(df, 'game_date')
        df = filter_by_date(df, cutoff_date)
        df = remove_ties(df)
        df = filter_by_minimum_games(df, min_games=5)

        # Final count and Save
        final_row_count = len(df)
        save_to_parquet(df, output_file)

        # Reporting
        print(f"Success! Processed data saved to {output_file}")
        display_filter_stats(initial_row_count, final_row_count)

    except FileNotFoundError:
        print(f"Critical Error: The file '{input_file}' was not found.")
    except KeyError as e:
        print(f"Data Schema Error: Missing expected column {e}")
    except Exception as e:
        print(f"An unexpected error occurred: {e}")


if __name__ == "__main__":
    main()
