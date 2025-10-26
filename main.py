import requests
import os
import re
from urllib.parse import urlparse, unquote

def download_audio_files(url_list_file, output_directory="downloaded_audio"):
    """
    Downloads audio files from a list of URLs, handling duplicates based on filename.

    Args:
        url_list_file (str): Path to the text file containing one URL per line.
        output_directory (str): The directory to save the downloaded files.
    """
    if not os.path.exists(output_directory):
        os.makedirs(output_directory)
        print(f"Created output directory: {output_directory}")

    downloaded_filenames = set()
    errors = []

    # Get already downloaded files to prevent re-downloading if script is run again
    for existing_file in os.listdir(output_directory):
        if existing_file.endswith(".mp3"):
            downloaded_filenames.add(existing_file)

    print(f"Found {len(downloaded_filenames)} existing files in '{output_directory}'.")

    try:
        with open(url_list_file, 'r', encoding='utf-8') as f:
            urls = [line.strip() for line in f if line.strip()] # Read and clean URLs
    except FileNotFoundError:
        print(f"Error: URL list file '{url_list_file}' not found.")
        return

    print(f"Processing {len(urls)} URLs from '{url_list_file}'...")

    for i, url in enumerate(urls):
        print(f"\n[{i+1}/{len(urls)}] Processing URL: {url}")

        # Extract base filename from the URL (before query parameters)
        path = urlparse(url).path
        # Use unquote to decode URL-encoded characters like %20 to space
        filename_with_extension = unquote(os.path.basename(path))

        # Clean up filename for special characters (optional, but good practice)
        # Allows alphanumeric, spaces, hyphens, underscores, and dots for extension
        filename = re.sub(r'[^\w\s\-\.]', '', filename_with_extension).strip()

        if not filename.lower().endswith(".mp3"):
            print(f"Skipping (not an MP3 or couldn't parse filename): {url}")
            continue

        if filename in downloaded_filenames:
            print(f"Skipping (duplicate, '{filename}' already downloaded or in list).")
            continue

        output_path = os.path.join(output_directory, filename)

        try:
            print(f"Attempting to download '{filename}'...")
            response = requests.get(url, stream=True, timeout=30) # Add a timeout
            response.raise_for_status() # Raise an exception for HTTP errors (4xx or 5xx)

            # Check if content-type is audio/mpeg
            content_type = response.headers.get('Content-Type', '')
            if 'audio/mpeg' not in content_type and 'binary/octet-stream' not in content_type:
                 print(f"Warning: Unexpected Content-Type '{content_type}' for {filename}. Might not be an MP3.")


            with open(output_path, 'wb') as mp3_file:
                for chunk in response.iter_content(chunk_size=8192):
                    if chunk: # filter out keep-alive new chunks
                        mp3_file.write(chunk)

            downloaded_filenames.add(filename) # Mark as downloaded
            print(f"Successfully downloaded: {filename}")

        except requests.exceptions.HTTPError as e:
            if e.response.status_code == 403:
                print(f"Error 403 Forbidden: URL may be expired or invalid for {filename}.")
                errors.append(f"403 Forbidden: {url} -> {e}")
            else:
                print(f"HTTP Error {e.response.status_code} for {filename}: {e}")
                errors.append(f"HTTP Error {e.response.status_code}: {url} -> {e}")
        except requests.exceptions.ConnectionError as e:
            print(f"Connection Error for {filename}: {e}")
            errors.append(f"Connection Error: {url} -> {e}")
        except requests.exceptions.Timeout as e:
            print(f"Timeout Error for {filename}: {e}")
            errors.append(f"Timeout Error: {url} -> {e}")
        except requests.exceptions.RequestException as e:
            print(f"An unexpected request error occurred for {filename}: {e}")
            errors.append(f"Request Error: {url} -> {e}")
        except Exception as e:
            print(f"An unexpected error occurred while processing {filename}: {e}")
            errors.append(f"General Error: {url} -> {e}")

    print("\n--- Download Summary ---")
    print(f"Total URLs processed: {len(urls)}")
    print(f"Successfully processed unique files: {len(downloaded_filenames) - (len(os.listdir(output_directory)) - len(downloaded_filenames))}") # Account for existing
    print(f"Files already existed/skipped: {len(urls) - (len(errors) + (len(downloaded_filenames) - (len(os.listdir(output_directory)) - len(downloaded_filenames))))}")
    if errors:
        print(f"Errors encountered: {len(errors)}")
        for error in errors:
            print(f"  - {error}")
    else:
        print("No errors reported.")

# --- How to use the script ---
if __name__ == "__main__":
    # 1. Save your list of URLs into a text file, e.g., 'audio_urls.txt'
    #    Make sure each URL is on a new line.

    url_file_name = "audio_urls.txt"
    download_folder = "brain_fm_audio"

    # Run the downloader
    download_audio_files(url_file_name, download_folder)

    print("\nScript finished.")
    print(f"Check the '{download_folder}' directory for your downloaded files.")
    print("If you encounter '403 Forbidden' errors, your URLs might have expired.")