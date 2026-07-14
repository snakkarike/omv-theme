#!/usr/bin/env python3
import sys
import urllib.request
import re
import os
import shutil
import ssl
import json

def log(msg):
    # Log to a file so the user can debug if needed
    with open("/tmp/themekit_font_download.log", "a") as f:
        f.write(msg + "\n")

def main():
    if len(sys.argv) < 2:
        log("No arguments provided.")
        return
        
    # Strip any extra quotes that Salt might have passed
    font_name = sys.argv[1].strip(' "\'')
    active_css = "/var/www/openmediavault/assets/theme-font.css"
    fonts_dir = "/var/www/openmediavault/assets/fonts"
    PLUGIN_DIR = "/usr/share/openmediavault/scripts/themekit"
    
    if not font_name or font_name.lower() == "none":
        with open(active_css, "w") as f:
            f.write("")
        log("Font cleared.")
        return

    with open(f'{PLUGIN_DIR}/google-fonts.json', 'r') as f:
        fonts_db = json.load(f)
        
    font_data = None
    if isinstance(fonts_db, list):
        for font in fonts_db:
            if font.get('family') == font_name:
                font_data = font
                break
    else:
        font_data = fonts_db.get(font_name)

    if not font_data:
        log(f"Error: Font '{font_name}' not found in database.")
        return

    os.makedirs(fonts_dir, exist_ok=True)
    
    font_id = font_name.lower().replace(' ', '_')
    cached_css = os.path.join(fonts_dir, f"{font_id}.css")
    
    if os.path.exists(cached_css):
        shutil.copy2(cached_css, active_css)
        log(f"Used cached CSS for {font_name}.")
        return

    # Use a simpler query that works for all fonts without triggering 400 Bad Request for unsupported weights
    font_url = f"https://fonts.googleapis.com/css?family={font_name.replace(' ', '+')}&display=swap"
    log(f"Fetching CSS from: {font_url}")
    
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36'
    }
    
    req = urllib.request.Request(font_url, headers=headers)
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE

    try:
        response = urllib.request.urlopen(req, context=ctx)
        css_content = response.read().decode('utf-8')
    except Exception as e:
        log(f"Failed to fetch Google Fonts CSS: {e}")
        return

    # Regex to handle potential quotes in url()
    urls = re.findall(r"url\(['\"]?(https://[^)'\"]+)['\"]?\)", css_content)
    log(f"Found {len(urls)} font files to download.")
    
    for url in urls:
        filename = url.split('/')[-1]
        local_path = os.path.join(fonts_dir, filename)
        
        if not os.path.exists(local_path):
            try:
                font_req = urllib.request.Request(url, headers=headers)
                font_data = urllib.request.urlopen(font_req, context=ctx).read()
                with open(local_path, 'wb') as f:
                    f.write(font_data)
                log(f"Downloaded {filename}")
            except Exception as e:
                log(f"Failed to download font file {url}: {e}")
                continue
                
        # Handle original URL which might not have quotes in the raw CSS
        css_content = css_content.replace(url, f"fonts/{filename}")

    with open(cached_css, "w") as f:
        f.write(css_content)
        
    shutil.copy2(cached_css, active_css)
    log(f"Successfully activated font {font_name}")

if __name__ == "__main__":
    main()
