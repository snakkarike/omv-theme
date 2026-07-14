#!/usr/bin/env python3
import sys
import urllib.request
import re
import os
import shutil

def main():
    if len(sys.argv) < 2:
        return
        
    font_name = sys.argv[1].strip()
    active_css = "/var/www/openmediavault/assets/theme-font.css"
    fonts_dir = "/var/www/openmediavault/assets/fonts"
    
    if not font_name:
        # If no font is selected, we clear the local font css to avoid loading old fonts
        if os.path.exists(active_css):
            os.remove(active_css)
        return

    # Ensure fonts directory exists
    os.makedirs(fonts_dir, exist_ok=True)
    
    # Generate a cache filename for this font
    font_id = font_name.lower().replace(' ', '_')
    cached_css = os.path.join(fonts_dir, f"{font_id}.css")
    
    if os.path.exists(cached_css):
        # We already downloaded this font previously, just use the cached CSS!
        shutil.copy2(cached_css, active_css)
        return

    font_url = f"https://fonts.googleapis.com/css?family={font_name.replace(' ', '+')}:300,400,500,700&display=swap"
    
    # Spoof a modern browser to get smaller WOFF2 fonts
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36'
    }
    
    req = urllib.request.Request(font_url, headers=headers)
    try:
        response = urllib.request.urlopen(req)
        css_content = response.read().decode('utf-8')
    except Exception as e:
        print(f"Failed to fetch Google Fonts CSS: {e}")
        return

    # Find all font URLs in the CSS
    urls = re.findall(r"url\((https://[^)]+)\)", css_content)
    
    for url in urls:
        # Generate a unique local filename
        filename = url.split('/')[-1]
        local_path = os.path.join(fonts_dir, filename)
        
        # Download the font file if it doesn't exist
        if not os.path.exists(local_path):
            try:
                font_req = urllib.request.Request(url, headers=headers)
                font_data = urllib.request.urlopen(font_req).read()
                with open(local_path, 'wb') as f:
                    f.write(font_data)
            except Exception as e:
                print(f"Failed to download font file {url}: {e}")
                continue
                
        # The active CSS will live in assets/theme-font.css
        # So the relative path to the font file is fonts/filename
        css_content = css_content.replace(url, f"fonts/{filename}")

    # Save to the cache
    with open(cached_css, "w") as f:
        f.write(css_content)
        
    # Copy to the active CSS file
    shutil.copy2(cached_css, active_css)

if __name__ == "__main__":
    main()
