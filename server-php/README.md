# AI server on your own hosting (cPanel / PHP)

1. cPanel → File Manager → open `public_html` → create folder `api`.
2. Upload `public_html/api/analyze.php` and `public_html/api/.htaccess` into `public_html/api`.
   (Turn on "Show Hidden Files" in File Manager settings to see `.htaccess`.)
3. Go one folder UP (your home folder, where you can see `public_html`). Upload `aicc-config.php` there.
4. Edit `aicc-config.php` there and paste your Gemini key. Save.
5. Test: open https://YOURDOMAIN/api/analyze.php in a browser. It should show {"error":"Use POST."}
